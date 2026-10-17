import Foundation
import DiskArbitration

/// Erro de uma ação do DiskArbitration, com o texto que o "dissenter" devolveu.
public struct ErroDeDisco: Error, LocalizedError, Equatable {
    public let texto: String
    public let codigo: Int32?
    /// kDAReturnBusy (0xF8DA0002): arquivo aberto no volume. Dá para oferecer "forçar".
    public var ocupado: Bool { codigo == ErroDeDisco.codigoOcupado }
    public static let codigoOcupado = Int32(bitPattern: 0xF8DA0002)

    public init(texto: String, codigo: Int32? = nil) {
        self.texto = texto
        self.codigo = codigo
    }

    init(dissenter: DADissenter) {
        let status = DADissenterGetStatus(dissenter)
        let texto = DADissenterGetStatusString(dissenter) as String?
        self.init(texto: texto ?? String(format: "erro 0x%08X", UInt32(bitPattern: status)), codigo: status)
    }

    public var errorDescription: String? { texto }
}
