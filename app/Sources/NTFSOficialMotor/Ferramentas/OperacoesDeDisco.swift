import Foundation

public struct ResultadoVerificacao: Sendable {
    public var estado: EstadoVolume
    public var saida: String
    public var remontou: Bool
}

public struct ResultadoReparo: Sendable {
    public var sucesso: Bool
    public var saida: String
    public var remontou: Bool
}

public struct ResultadoFormatacao: Sendable {
    public var saida: String
    public var remontou: Bool
}

public enum ErroOperacao: Error, LocalizedError {
    case nomeInvalido(ProblemaNome)
    case falhou(String)
    public var errorDescription: String? {
        switch self {
        case .nomeInvalido(let p): return "Nome inválido: \(p)"
        case .falhou(let t): return t
        }
    }
}

/// Verificar, reparar e formatar: desmonta, roda as ferramentas (como administrador quando precisa) e remonta.
@MainActor
public final class OperacoesDeDisco {
    private let monitor: MonitorDeDiscos
    public init(monitor: MonitorDeDiscos) { self.monitor = monitor }

    // MARK: - Comandos (funções puras, testáveis sem executar nada)

    nonisolated public static func comandoVerificar(bsd: String) -> String {
        let dev = "/dev/" + bsd
        return Administrador.montarComando([CaminhosDriver.probe, "--readwrite", dev])
            + "; echo \"probe=$?\"; "
            + Administrador.montarComando([CaminhosDriver.ntfsfix, "-n", dev])
            + "; echo \"ntfsfix=$?\""
    }

    nonisolated public static func comandoReparar(bsd: String) -> String {
        let dev = "/dev/" + bsd
        return Administrador.montarComando([CaminhosDriver.ntfsfix, dev]) + "; echo \"ntfsfix=$?\"; "
            + Administrador.montarComando([CaminhosDriver.ntfsfix, "-d", dev]) + "; echo \"ntfsfix_d=$?\""
    }

    nonisolated public static func comandoFormatarNTFS(bsd: String, nome: String) -> String {
        Administrador.montarComando([CaminhosDriver.mkntfs, "-Q", "-F", "-L", nome, "/dev/" + bsd])
            + "; echo \"mkntfs=$?\""
    }

    /// Para exFAT e FAT32 (sem administrador).
    nonisolated public static func argumentosDiskutil(formato: FormatoVolume, nome: String, bsd: String) -> [String]? {
        switch formato {
        case .ntfs: return nil
        case .exfat: return ["eraseVolume", "ExFAT", nome, bsd]
        case .fat32: return ["eraseVolume", "MS-DOS FAT32", nome, bsd]
        }
    }

    // MARK: - Operações

    /// Trava de segurança antes de qualquer comando de administrador: o identificador tem que ser de disco
    /// (`disk6` ou `disk6s2`). Evita apagar/reparar algo errado se a lista de discos vier com lixo.
    nonisolated public static func identificadorValido(_ bsd: String) -> Bool {
        bsd.range(of: #"^disk[0-9]+(s[0-9]+)*$"#, options: .regularExpression) != nil
    }

    private func conferir(_ disco: Disco) throws {
        guard Self.identificadorValido(disco.bsdName) else {
            throw ErroDeDisco(texto: "Identificador de disco inválido: \(disco.bsdName)")
        }
    }

    public func verificar(_ disco: Disco) async throws -> ResultadoVerificacao {
        try conferir(disco)
        let estavaMontado = disco.montado
        if estavaMontado { try await monitor.desmontar(disco.bsdName) }
        let saida: String
        do {
            saida = try Administrador.executar(Self.comandoVerificar(bsd: disco.bsdName))
        } catch {
            if estavaMontado { try? await monitor.montar(disco.bsdName) }
            throw error
        }
        let codigo = InterpretacaoProbe.codigo(na: saida, marcador: "probe")
        let estado = codigo.map(InterpretacaoProbe.estado(codigo:)) ?? .erro(codigo: -1)
        let remontou = estavaMontado ? await remontar(disco.bsdName) : false
        return ResultadoVerificacao(estado: estado, saida: saida, remontou: remontou)
    }

    public func reparar(_ disco: Disco) async throws -> ResultadoReparo {
        try conferir(disco)
        let estavaMontado = disco.montado
        if estavaMontado { try await monitor.desmontar(disco.bsdName) }
        let saida: String
        do {
            saida = try Administrador.executar(Self.comandoReparar(bsd: disco.bsdName))
        } catch {
            if estavaMontado { try? await monitor.montar(disco.bsdName) }
            throw error
        }
        let ok = InterpretacaoProbe.codigo(na: saida, marcador: "ntfsfix") == 0
        let remontou = estavaMontado ? await remontar(disco.bsdName) : false
        return ResultadoReparo(sucesso: ok, saida: saida, remontou: remontou)
    }

    public func formatar(_ disco: Disco, nome: String, formato: FormatoVolume) async throws -> ResultadoFormatacao {
        try conferir(disco)
        if let problema = ValidacaoNome.validar(nome, formato: formato) { throw ErroOperacao.nomeInvalido(problema) }
        let bsd = disco.bsdName
        var saida = ""
        if let args = Self.argumentosDiskutil(formato: formato, nome: nome, bsd: bsd) {
            // O diskutil desmonta e remonta sozinho (inclusive volume FUSE).
            saida = try await Self.rodar("/usr/sbin/diskutil", args)
        } else {
            if disco.montado { try await monitor.desmontar(bsd) }
            saida = try Administrador.executar(Self.comandoFormatarNTFS(bsd: bsd, nome: nome))
            if InterpretacaoProbe.codigo(na: saida, marcador: "mkntfs") != 0 {
                throw ErroOperacao.falhou(saida)
            }
        }
        let remontou = await remontar(bsd)
        return ResultadoFormatacao(saida: saida, remontou: remontou)
    }

    private func remontar(_ bsd: String) async -> Bool {
        do { try await monitor.montar(bsd); return true } catch { return false }
    }

    /// Roda um programa sem administrador e devolve a saída (junta stdout e stderr); status != 0 vira erro.
    nonisolated static func rodar(_ programa: String, _ argumentos: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuacao in
            DispatchQueue.global().async {
                let p = Process()
                p.executableURL = URL(fileURLWithPath: programa)
                p.arguments = argumentos
                let cano = Pipe()
                p.standardOutput = cano
                p.standardError = cano
                do {
                    try p.run()
                    let dados = cano.fileHandleForReading.readDataToEndOfFile()
                    p.waitUntilExit()
                    let texto = String(decoding: dados, as: UTF8.self)
                    if p.terminationStatus == 0 { continuacao.resume(returning: texto) }
                    else { continuacao.resume(throwing: ErroOperacao.falhou(texto)) }
                } catch {
                    continuacao.resume(throwing: error)
                }
            }
        }
    }
}
