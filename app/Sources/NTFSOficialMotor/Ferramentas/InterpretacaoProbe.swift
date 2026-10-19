import Foundation

public enum EstadoVolume: Equatable, Sendable {
    case limpo
    case hibernado
    /// Probe 14 sem hiberfil.sys: $LogFile versão 2.0, metadados no cache do Windows (Inicialização rápida ou
    /// disco arrancado do Windows 8+). O ntfsrecover recusa sem -k (que perde dados), então fica só leitura.
    case cacheWindows
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

    /// Igual a `estado(codigo:)`, mas separa os dois significados do 14 pela mensagem do probe: "Windows is
    /// hibernated" / "Hibernated non-system partition" (hiberfil.sys) ou "Metadata kept in Windows cache".
    public static func estado(codigo: Int, saida: String) -> EstadoVolume {
        if codigo == 14, !saida.lowercased().contains("hibernated") { return .cacheWindows }
        return estado(codigo: codigo)
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
