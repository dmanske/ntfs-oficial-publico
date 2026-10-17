import Foundation
import Combine
import DiskArbitration

/// Observa o DiskArbitration e publica a lista de volumes NTFS (montados ou não).
@MainActor
public final class MonitorDeDiscos: ObservableObject {
    @Published public private(set) var discos: [Disco] = []

    let sessao: DASession
    private var discosDA: [String: DADisk] = [:]
    private var recargaPendente = false
    private var iniciado = false
    private let pastaMotivos: String

    public init(pastaMotivos: String = CaminhosDriver.pastaMotivos) {
        self.pastaMotivos = pastaMotivos
        self.sessao = DASessionCreate(kCFAllocatorDefault)!
    }

    deinit {
        // Sem isto o DiskArbitration chamaria o callback com o ponteiro de um monitor que já não existe.
        DASessionUnscheduleFromRunLoop(sessao, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
    }

    /// Registra os callbacks (agendados na run loop principal). Os discos já presentes chegam como "appeared".
    public func iniciar() {
        guard !iniciado else { return }
        iniciado = true
        let contexto = Unmanaged.passUnretained(self).toOpaque()
        DARegisterDiskAppearedCallback(sessao, nil, { disco, ctx in
            guard let ctx else { return }
            let monitor = Unmanaged<MonitorDeDiscos>.fromOpaque(ctx).takeUnretainedValue()
            MainActor.assumeIsolated { monitor.apareceu(disco) }
        }, contexto)
        DARegisterDiskDisappearedCallback(sessao, nil, { disco, ctx in
            guard let ctx else { return }
            let monitor = Unmanaged<MonitorDeDiscos>.fromOpaque(ctx).takeUnretainedValue()
            MainActor.assumeIsolated { monitor.sumiu(disco) }
        }, contexto)
        DARegisterDiskDescriptionChangedCallback(sessao, nil, nil, { disco, _, ctx in
            guard let ctx else { return }
            let monitor = Unmanaged<MonitorDeDiscos>.fromOpaque(ctx).takeUnretainedValue()
            MainActor.assumeIsolated { monitor.apareceu(disco) }
        }, contexto)
        DASessionScheduleWithRunLoop(sessao, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
    }

    private func apareceu(_ disco: DADisk) {
        guard let c = DADiskGetBSDName(disco) else { return }
        discosDA[String(cString: c)] = disco
        agendarRecarga()
    }

    private func sumiu(_ disco: DADisk) {
        guard let c = DADiskGetBSDName(disco) else { return }
        discosDA[String(cString: c)] = nil
        agendarRecarga()
    }

    /// Junta vários eventos seguidos (um disco novo gera dezenas) numa recarga só.
    private func agendarRecarga() {
        guard !recargaPendente else { return }
        recargaPendente = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            MainActor.assumeIsolated {
                self?.recargaPendente = false
                self?.recarregar()
            }
        }
    }

    /// Relê tudo (também usado em intervalo, para atualizar o espaço livre).
    public func recarregar() {
        var novos: [Disco] = []
        for (_, disco) in discosDA {
            guard let d = DADiskCopyDescription(disco) as? [String: Any] else { continue }
            var inteiro: [String: Any]?
            if let w = DADiskCopyWholeDisk(disco) {
                inteiro = DADiskCopyDescription(w) as? [String: Any]
            }
            if let novo = Disco(descricao: d, inteiro: inteiro, pastaMotivos: pastaMotivos) { novos.append(novo) }
        }
        novos.sort { ($0.nome.lowercased(), $0.bsdName) < ($1.nome.lowercased(), $1.bsdName) }
        if novos != discos { discos = novos }
    }

    func discoDA(_ bsd: String) throws -> DADisk {
        guard let d = DADiskCreateFromBSDName(kCFAllocatorDefault, sessao, bsd) else {
            throw ErroDeDisco(texto: "Disco \(bsd) não encontrado.")
        }
        return d
    }
}

// MARK: - Ações (montar, desmontar, ejetar)

/// Caixa que leva a continuação até o callback em C.
private final class CaixaRetorno {
    let continuacao: CheckedContinuation<Void, Error>
    init(_ c: CheckedContinuation<Void, Error>) { continuacao = c }
}

private let retornoDA: @convention(c) (DADisk, DADissenter?, UnsafeMutableRawPointer?) -> Void = { _, dissenter, ctx in
    guard let ctx else { return }
    let caixa = Unmanaged<CaixaRetorno>.fromOpaque(ctx).takeRetainedValue()
    if let dissenter {
        caixa.continuacao.resume(throwing: ErroDeDisco(dissenter: dissenter))
    } else {
        caixa.continuacao.resume()
    }
}

extension MonitorDeDiscos {
    public func montar(_ bsd: String) async throws {
        let disco = try discoDA(bsd)
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
            let ctx = Unmanaged.passRetained(CaixaRetorno(c)).toOpaque()
            DADiskMount(disco, nil, DADiskMountOptions(kDADiskMountOptionDefault), retornoDA, ctx)
        }
        recarregar()
    }

    public func desmontar(_ bsd: String, forcar: Bool = false) async throws {
        try await desmontar(disco: try discoDA(bsd), opcoes: forcar ? kDADiskUnmountOptionForce : kDADiskUnmountOptionDefault)
        recarregar()
    }

    /// Desmonta o disco inteiro (todas as partições) e ejeta.
    public func ejetar(_ bsd: String, forcar: Bool = false) async throws {
        let disco = try discoDA(bsd)
        guard let inteiro = DADiskCopyWholeDisk(disco) else {
            throw ErroDeDisco(texto: "Não achei o disco inteiro de \(bsd).")
        }
        let opcoes = kDADiskUnmountOptionWhole | (forcar ? kDADiskUnmountOptionForce : 0)
        try await desmontar(disco: inteiro, opcoes: opcoes)
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
            let ctx = Unmanaged.passRetained(CaixaRetorno(c)).toOpaque()
            DADiskEject(inteiro, DADiskEjectOptions(kDADiskEjectOptionDefault), retornoDA, ctx)
        }
        recarregar()
    }

    private func desmontar(disco: DADisk, opcoes: Int) async throws {
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
            let ctx = Unmanaged.passRetained(CaixaRetorno(c)).toOpaque()
            DADiskUnmount(disco, DADiskUnmountOptions(opcoes), retornoDA, ctx)
        }
    }
}
