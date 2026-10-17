import Foundation
import NTFSOficialMotor

/// Textos derivados de um `Disco` (tamanhos, motivo, linha de estado).
enum Formatacao {
    static func bytes(_ n: UInt64?) -> String {
        guard let n else { return "—" }
        return ByteCountFormatter.string(fromByteCount: Int64(n), countStyle: .decimal)
    }

    static func livreDeTotal(_ d: Disco) -> String? {
        guard d.livre != nil, d.tamanhoTotal != nil else { return nil }
        return Texto.t(.menuLivres, bytes(d.livre), bytes(d.tamanhoTotal))
    }

    static func motivo(_ m: MotivoSoLeitura?) -> String? {
        switch m {
        case .hibernado: return Texto.t(.motivoHibernado)
        case .sujo: return Texto.t(.motivoSujo)
        case .outroDriver: return Texto.t(.motivoOutroDriver)
        case nil: return nil
        }
    }

    /// "só leitura — Windows hibernado" ou só "só leitura".
    static func soLeituraComMotivo(_ d: Disco) -> String {
        if let m = motivo(d.motivoSoLeitura) { return Texto.t(.menuSoLeitura, m) }
        return Texto.t(.listaSoLeitura)
    }

    static func estadoCurto(_ d: Disco) -> String {
        if !d.montado { return Texto.t(.listaNaoMontado) }
        return d.soLeitura ? Texto.t(.listaSoLeitura) : Texto.t(.listaGravacao)
    }

    /// Subtítulo da lista lateral: "NTFS · 960 GB", mais o estado quando não está em gravação normal.
    static func subtituloLista(_ d: Disco) -> String {
        var partes = ["NTFS", bytes(d.tamanhoTotal)]
        if !d.montado { partes.append(Texto.t(.listaNaoMontado)) }
        else if d.soLeitura { partes.append(Texto.t(.listaSoLeitura)) }
        return partes.joined(separator: " · ")
    }

    /// Nome do sistema de arquivos como aparece nos detalhes.
    static func sistema(_ d: Disco) -> String {
        d.usaNTFSOficial ? Texto.t(.sistemaOficial) : d.tipoDeSistema == "ntfs" ? Texto.t(.sistemaApple) : "NTFS"
    }

    /// Porcentagem usada (0–100) ou nil se não houver como calcular.
    static func porcentagemUsada(_ d: Disco) -> Double? {
        guard let usado = d.usado, let total = d.tamanhoTotal, total > 0 else { return nil }
        return min(1, Double(usado) / Double(total))
    }

    static func problema(_ p: ProblemaNome) -> String {
        switch p {
        case .vazio: return Texto.t(.problemaVazio)
        case .muitoLongo(let max): return Texto.t(.problemaLongo, max)
        case .caractereInvalido(let c): return Texto.t(.problemaCaractere, String(c))
        case .precisaMaiusculaASCII: return Texto.t(.problemaMaiuscula)
        }
    }

    static func nome(_ o: OutroDriver) -> String {
        switch o {
        case .tuxera: return Texto.t(.drvTuxera)
        case .paragon: return Texto.t(.drvParagon)
        case .ntfs3gMacFUSE: return Texto.t(.drvMacFuse)
        }
    }
}
