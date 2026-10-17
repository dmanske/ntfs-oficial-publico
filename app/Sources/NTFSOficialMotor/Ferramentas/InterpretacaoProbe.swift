import Foundation

public enum EstadoVolume: Equatable, Sendable {
    case limpo
    case hibernado
    case sujo
    case erro(codigo: Int)
}

/// Interpretação das saídas do `ntfs-3g.probe` e do script de verificação (funções puras).
public enum InterpretacaoProbe {
    /// Códigos do `ntfs-3g.probe --readwrite`: 0 limpo, 14 hibernado, 15 desmontado sujo; o resto é erro.
    public static func estado(codigo: Int) -> EstadoVolume {
        switch codigo {
        case 0: return .limpo
        case 14: return .hibernado
        case 15: return .sujo
        default: return .erro(codigo: codigo)
        }
    }

    /// Acha `<marcador>=<número>` numa saída com várias linhas.
    public static func codigo(na saida: String, marcador: String) -> Int? {
        for linha in saida.split(whereSeparator: \.isNewline) {
            let l = linha.trimmingCharacters(in: .whitespaces)
            if l.hasPrefix(marcador + "="), let n = Int(l.dropFirst(marcador.count + 1)) { return n }
        }
        return nil
    }
}
