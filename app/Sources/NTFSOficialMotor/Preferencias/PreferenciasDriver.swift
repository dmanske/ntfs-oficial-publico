import Foundation

/// Preferências do driver, no plist que o `ntfsoficial.util` lê. Sem o arquivo valem os padrões.
public struct PreferenciasDriver: Equatable, Sendable {
    public var disableDriver = 0
    public var enableRawDevices = 1
    public var enableCaching = 1
    public var enableNormalization = 1
    public var enableAutomaticRecovery = 0
    /// 2 = tudo (etiquetas e metadados do Mac), 1 = só o essencial, 0 = nenhum.
    public var xattrMode = 2

    public init() {}

    /// Lê o plist (nome da chave -> inteiro). Valores ausentes ou de tipo errado ficam no padrão.
    public static func ler(caminho: String = CaminhosDriver.preferencias) -> PreferenciasDriver {
        var p = PreferenciasDriver()
        guard let dic = NSDictionary(contentsOfFile: caminho) as? [String: Any] else { return p }
        func inteiro(_ chave: String, _ padrao: Int) -> Int {
            (dic[chave] as? NSNumber)?.intValue ?? padrao
        }
        p.disableDriver = inteiro("DisableDriver", p.disableDriver)
        p.enableRawDevices = inteiro("EnableRawDevices", p.enableRawDevices)
        p.enableCaching = inteiro("EnableCaching", p.enableCaching)
        p.enableNormalization = inteiro("EnableNormalization", p.enableNormalization)
        p.enableAutomaticRecovery = inteiro("EnableAutomaticRecovery", p.enableAutomaticRecovery)
        p.xattrMode = inteiro("XattrMode", p.xattrMode)
        return p
    }

    var pares: [(String, Int)] {
        [("DisableDriver", disableDriver), ("EnableRawDevices", enableRawDevices),
         ("EnableCaching", enableCaching), ("EnableNormalization", enableNormalization),
         ("EnableAutomaticRecovery", enableAutomaticRecovery), ("XattrMode", xattrMode)]
    }

    /// Um comando só (uma senha só): `defaults write <plist> <Chave> -int <v> && …`.
    public func comandoGravar(caminho: String = CaminhosDriver.preferencias) -> String {
        pares.map { chave, valor in
            Administrador.montarComando(["/usr/bin/defaults", "write", caminho, chave, "-int", String(valor)])
        }.joined(separator: " && ")
    }

    @MainActor
    public func gravar(caminho: String = CaminhosDriver.preferencias) throws {
        _ = try Administrador.executar(comandoGravar(caminho: caminho))
    }
}
