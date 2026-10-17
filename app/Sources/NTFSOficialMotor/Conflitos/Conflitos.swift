import Foundation

public enum OutroDriver: String, CaseIterable, Sendable {
    case tuxera
    case paragon
    case ntfs3gMacFUSE
}

/// Detecta outros drivers NTFS instalados. A raiz é parâmetro para testar com uma pasta temporária.
public enum Conflitos {
    public static func detectar(raiz: String = "/") -> [OutroDriver] {
        let fm = FileManager.default
        func existe(_ relativo: String) -> Bool {
            fm.fileExists(atPath: (raiz as NSString).appendingPathComponent(relativo))
        }
        var achados: [OutroDriver] = []
        if existe("Library/Filesystems/tuxera_ntfs.fs") { achados.append(.tuxera) }
        if existe("Library/Filesystems/ufsd_NTFS.fs") || existe("Library/Extensions/ufsd_NTFS.kext") {
            achados.append(.paragon)
        }
        if existe("Library/Filesystems/macfuse.fs"),
           existe("opt/homebrew/bin/ntfs-3g") || existe("usr/local/bin/ntfs-3g") {
            achados.append(.ntfs3gMacFUSE)
        }
        return achados
    }
}
