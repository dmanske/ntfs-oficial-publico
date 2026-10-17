import Foundation
import DiskArbitration

public enum MotivoSoLeitura: String, Equatable, Sendable {
    case hibernado
    case sujo
    /// Montado só para leitura pelo NTFS da Apple (o NTFS Oficial não montou).
    case outroDriver
}

/// Um volume NTFS (montado ou não) como o macOS enxerga.
public struct Disco: Identifiable, Equatable, Sendable {
    public var id: String { bsdName }
    public var bsdName: String                 // ex.: disk6s2
    public var nome: String
    public var pontoDeMontagem: String?
    public var tamanhoTotal: UInt64?           // do volume (montado) ou da partição (não montado)
    public var livre: UInt64?
    public var tipoDeSistema: String?          // "ntfsoficial" ou "ntfs" (o da Apple)
    public var soLeitura: Bool
    public var motivoSoLeitura: MotivoSoLeitura?
    public var ejetavel: Bool
    public var removivel: Bool
    public var interno: Bool
    public var discoInteiro: String?           // ex.: disk6
    public var tamanhoDiscoInteiro: UInt64?
    public var modelo: String?
    public var protocolo: String?
    public var tipoDeParticao: String?         // DAMediaContent

    public var montado: Bool { pontoDeMontagem != nil }
    public var usaNTFSOficial: Bool { tipoDeSistema == "ntfsoficial" }
    public var usado: UInt64? {
        guard let t = tamanhoTotal, let l = livre, t >= l else { return nil }
        return t - l
    }
    public var caminhoDispositivo: String { "/dev/" + bsdName }

    // MARK: - Classificação (função pura, testável)

    /// Regra: montado com tipo ntfsoficial/ntfs entra; não montado só entra se o conteúdo for "Windows_NTFS"
    /// (o GUID EBD0A0A2… também é de exFAT/FAT, então sozinho não basta).
    public static func ehNTFS(tipoDeSistema: String?, conteudo: String?, montado: Bool) -> Bool {
        let tipo = tipoDeSistema?.lowercased()
        if tipo == "ntfsoficial" || tipo == "ntfs" { return true }
        if !montado, tipo == nil, conteudo == "Windows_NTFS" { return true }
        return false
    }

    /// Lê `<pasta>/<bsd>.motivo` ("hibernado" ou "sujo"). Sem arquivo (ou conteúdo estranho) = nil.
    public static func lerMotivo(bsdName: String, pasta: String = CaminhosDriver.pastaMotivos) -> MotivoSoLeitura? {
        let caminho = (pasta as NSString).appendingPathComponent(bsdName + ".motivo")
        guard let texto = try? String(contentsOfFile: caminho, encoding: .utf8) else { return nil }
        switch texto.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "hibernado": return .hibernado
        case "sujo": return .sujo
        default: return nil
        }
    }

    /// Monta o `Disco` a partir da descrição do DiskArbitration (e a do disco inteiro). nil = não é NTFS.
    public init?(descricao d: [String: Any], inteiro: [String: Any]?, pastaMotivos: String = CaminhosDriver.pastaMotivos) {
        func chave(_ k: CFString) -> String { k as String }
        guard let bsd = d[chave(kDADiskDescriptionMediaBSDNameKey)] as? String else { return nil }
        let tipo = d[chave(kDADiskDescriptionVolumeKindKey)] as? String
        let conteudo = d[chave(kDADiskDescriptionMediaContentKey)] as? String
        let url = d[chave(kDADiskDescriptionVolumePathKey)] as? URL
        let montado = url != nil
        guard Disco.ehNTFS(tipoDeSistema: tipo, conteudo: conteudo, montado: montado) else { return nil }

        bsdName = bsd
        tipoDeSistema = tipo?.lowercased()
        tipoDeParticao = conteudo
        pontoDeMontagem = url?.path
        let nomeVolume = d[chave(kDADiskDescriptionVolumeNameKey)] as? String
        nome = nomeVolume ?? (montado ? url!.lastPathComponent : bsd)
        ejetavel = d[chave(kDADiskDescriptionMediaEjectableKey)] as? Bool ?? false
        removivel = d[chave(kDADiskDescriptionMediaRemovableKey)] as? Bool ?? false
        interno = d[chave(kDADiskDescriptionDeviceInternalKey)] as? Bool ?? false
        modelo = (d[chave(kDADiskDescriptionDeviceModelKey)] as? String)?.trimmingCharacters(in: .whitespaces)
        protocolo = d[chave(kDADiskDescriptionDeviceProtocolKey)] as? String
        let tamanhoMidia = (d[chave(kDADiskDescriptionMediaSizeKey)] as? NSNumber)?.uint64Value
        tamanhoTotal = tamanhoMidia
        livre = nil
        soLeitura = false
        if let inteiro {
            discoInteiro = inteiro[chave(kDADiskDescriptionMediaBSDNameKey)] as? String
            tamanhoDiscoInteiro = (inteiro[chave(kDADiskDescriptionMediaSizeKey)] as? NSNumber)?.uint64Value
            if modelo == nil { modelo = (inteiro[chave(kDADiskDescriptionDeviceModelKey)] as? String)?.trimmingCharacters(in: .whitespaces) }
            if protocolo == nil { protocolo = inteiro[chave(kDADiskDescriptionDeviceProtocolKey)] as? String }
        } else {
            discoInteiro = nil
            tamanhoDiscoInteiro = nil
        }
        motivoSoLeitura = nil

        if let ponto = pontoDeMontagem {
            var s = statfs()
            if statfs(ponto, &s) == 0 {
                tamanhoTotal = UInt64(s.f_blocks) * UInt64(s.f_bsize)
                livre = UInt64(s.f_bavail) * UInt64(s.f_bsize)
                soLeitura = (s.f_flags & UInt32(MNT_RDONLY)) != 0
            }
            if soLeitura {
                if let m = Disco.lerMotivo(bsdName: bsd, pasta: pastaMotivos) {
                    motivoSoLeitura = m
                } else if tipoDeSistema == "ntfs" {
                    motivoSoLeitura = .outroDriver
                }
            }
        }
    }
}
