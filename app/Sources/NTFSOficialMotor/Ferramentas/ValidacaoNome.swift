import Foundation

public enum FormatoVolume: String, CaseIterable, Sendable {
    case ntfs, exfat, fat32
}

public enum ProblemaNome: Equatable, Sendable {
    case vazio
    case muitoLongo(maximo: Int)
    case caractereInvalido(Character)
    case precisaMaiusculaASCII
}

/// Validação do nome do volume (função pura). Regras do Tuxera Disk Manager (REA):
/// NTFS até 128 caracteres; FAT/exFAT até 11 e sem " * / : < > ? \ |.
public enum ValidacaoNome {
    public static let proibidosFAT: Set<Character> = ["\"", "*", "/", ":", "<", ">", "?", "\\", "|"]

    public static func maximo(_ formato: FormatoVolume) -> Int {
        formato == .ntfs ? 128 : 11
    }

    /// nil = nome válido.
    public static func validar(_ nome: String, formato: FormatoVolume) -> ProblemaNome? {
        if nome.isEmpty { return .vazio }
        if nome.count > maximo(formato) { return .muitoLongo(maximo: maximo(formato)) }
        guard formato != .ntfs else { return nil }
        if let ruim = nome.first(where: { proibidosFAT.contains($0) }) { return .caractereInvalido(ruim) }
        if formato == .fat32 {
            for c in nome {
                guard let ascii = c.asciiValue, ascii >= 0x20, ascii < 0x7F else { return .precisaMaiusculaASCII }
                if c.isLowercase { return .precisaMaiusculaASCII }
            }
        }
        return nil
    }
}
