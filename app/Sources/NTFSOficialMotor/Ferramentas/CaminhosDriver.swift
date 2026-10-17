import Foundation

/// Caminhos fixos do driver já instalado (o app não mexe nele: só chama as ferramentas).
public enum CaminhosDriver {
    public static let pacote = "/Library/Filesystems/ntfsoficial.fs"
    public static let support = pacote + "/Contents/Resources/Support"
    public static let ntfsfix = support + "/ntfsfix"
    public static let probe = support + "/ntfs-3g.probe"
    public static let mkntfs = support + "/mkntfs"
    public static let ntfslabel = support + "/ntfslabel"
    /// Preferências do driver (as mesmas que o ntfsoficial.util lê).
    public static let preferencias = "/Library/Preferences/com.danielmanske.ntfsoficial.plist"
    /// Onde o despachante de montagem guarda o motivo do "só leitura" (<disco>.motivo).
    public static let pastaMotivos = "/private/var/tmp/ntfsoficial"
}
