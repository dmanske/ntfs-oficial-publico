import Foundation

public struct ResultadoVerificacao: Sendable {
    public var estado: EstadoVolume
    public var saida: String
    public var remontou: Bool
    /// Código do `ntfsfix -n` (0 = estrutura em ordem). nil = não apareceu na saída.
    public var estrutura: Int?
    /// Código do `ntfsrecover -n` (0 = o reparo consegue reaplicar o journal). Só existe com probe 14/15.
    public var replay: Int?
    public var estruturaComProblema: Bool { estrutura.map { $0 != 0 } ?? false }
}

public struct ResultadoReparo: Sendable {
    public var sucesso: Bool
    public var saida: String
    public var remontou: Bool
    /// Windows hibernado: nada foi alterado (o ntfsfix zeraria o journal e o disco seria corrompido ao acordar).
    public var hibernado: Bool = false
    /// Código do `ntfsrecover`. Se não for 0, o `ntfsfix` NÃO roda (ele zera o journal e jogaria as transações fora).
    public var replay: Int? = nil
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

    /// O ntfsrecover com limite de tempo: com um journal estranho ele pode ficar em laço infinito (visto com uma
    /// imagem de teste) e a janela de senha ficaria esperando para sempre. `alarm` + `exec` mata ele em 60 s.
    nonisolated static func comandoRecuperar(dev: String, simular: Bool) -> String {
        Administrador.montarComando(["/usr/bin/perl", "-e", "alarm 60; exec @ARGV", CaminhosDriver.ntfsrecover]
            + (simular ? ["-n"] : []) + [dev])
    }

    /// Roda o probe e guarda a saída em `$o` e o código em `$p`; a saída distingue o 14 de hibernação do 14 de
    /// cache do Windows (mensagem "hibernated"). Imprime `probe=<código>`.
    nonisolated static func comandoProbe(dev: String) -> String {
        "o=$(" + Administrador.montarComando([CaminhosDriver.probe, "--readwrite", dev]) + " 2>&1); p=$?; "
            + "echo \"$o\"; echo \"probe=$p\"; "
    }

    /// Verificar: probe + `ntfsrecover -n` + `ntfsfix -n`. Nada é gravado. O `ntfsrecover -n` só roda quando o
    /// probe diz 14/15 e não é hibernação: num journal limpo/apagado (normal depois de formatar) ele sai com 1.
    nonisolated public static func comandoVerificar(bsd: String) -> String {
        let dev = "/dev/" + bsd
        return comandoProbe(dev: dev)
            + "if [ \"$p\" = 14 -o \"$p\" = 15 ] && ! echo \"$o\" | grep -qi hibernated; then "
            + comandoRecuperar(dev: dev, simular: true) + "; echo \"recover=$?\"; fi; "
            + Administrador.montarComando([CaminhosDriver.ntfsfix, "-n", dev]) + "; echo \"ntfsfix=$?\""
    }

    /// Reparar: `ntfsrecover` (reaplica o journal do Windows) e depois `ntfsfix` (SEM -d: ele marca o volume para
    /// o chkdsk do Windows; limpar esse indicador esconderia o problema). Recusa hibernação (imprime
    /// `hibernado=1`) e não roda o `ntfsfix` se o replay falhar (`recover=<código>` != 0), porque o `ntfsfix`
    /// zera o journal e jogaria fora as transações que o Windows confirmou.
    nonisolated public static func comandoReparar(bsd: String) -> String {
        let dev = "/dev/" + bsd
        return comandoProbe(dev: dev)
            + "if [ \"$p\" = 14 ] && echo \"$o\" | grep -qi hibernated; then echo \"hibernado=1\"; else "
            + "r=0; if [ \"$p\" = 14 -o \"$p\" = 15 ]; then "
            + comandoRecuperar(dev: dev, simular: false) + "; r=$?; echo \"recover=$r\"; fi; "
            // ntfsfix só se o ntfsfix -n achar erro (sai 1): num volume em ordem ele só deixaria a marca de
            // "sujo" e o Windows rodaria o chkdsk à toa (como o -a "only if needed" do ntfsck do Tuxera)
            + "if [ \"$r\" = 0 ]; then " + Administrador.montarComando([CaminhosDriver.ntfsfix, "-n", dev])
            + " >/dev/null 2>&1; n=$?; echo \"ntfsfix_n=$n\"; if [ \"$n\" != 0 ]; then "
            + Administrador.montarComando([CaminhosDriver.ntfsfix, dev]) + "; echo \"ntfsfix=$?\"; fi; fi; "
            + "fi"
    }

    /// Reparo ok: o `ntfsfix` rodou e deu 0, ou nem precisou rodar porque o `ntfsfix -n` não achou erro.
    nonisolated public static func reparoDeuCerto(saida: String) -> Bool {
        if let fix = InterpretacaoProbe.codigo(na: saida, marcador: "ntfsfix") { return fix == 0 }
        return InterpretacaoProbe.codigo(na: saida, marcador: "ntfsfix_n") == 0
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
        let estado = codigo.map { InterpretacaoProbe.estado(codigo: $0, saida: saida) } ?? .erro(codigo: -1)
        let remontou = estavaMontado ? await remontar(disco.bsdName) : false
        return ResultadoVerificacao(estado: estado, saida: saida, remontou: remontou,
                                    estrutura: InterpretacaoProbe.codigo(na: saida, marcador: "ntfsfix"),
                                    replay: InterpretacaoProbe.codigo(na: saida, marcador: "recover"))
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
        let ok = Self.reparoDeuCerto(saida: saida)
        let remontou = estavaMontado ? await remontar(disco.bsdName) : false
        return ResultadoReparo(sucesso: ok, saida: saida, remontou: remontou,
                               hibernado: InterpretacaoProbe.codigo(na: saida, marcador: "hibernado") == 1,
                               replay: InterpretacaoProbe.codigo(na: saida, marcador: "recover"))
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
