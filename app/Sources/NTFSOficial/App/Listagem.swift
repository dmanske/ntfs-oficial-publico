import Foundation
import NTFSOficialMotor

/// Diagnóstico: `NTFSOficial --listar`. Sem janelas, só o Motor.
@MainActor
enum Listagem {
    static func executar() {
        let monitor = MonitorDeDiscos()
        monitor.iniciar()
        // Deixa a run loop entregar os discos já presentes.
        RunLoop.main.run(until: Date().addingTimeInterval(Config.esperaListarSegundos))
        monitor.recarregar()
        if monitor.discos.isEmpty { print("Nenhum disco NTFS encontrado.") }
        for d in monitor.discos {
            let modo = !d.montado ? "não montado" : d.soLeitura ? "SÓ LEITURA" : "gravação"
            let motivo = d.motivoSoLeitura.map { " motivo=\($0.rawValue)" } ?? ""
            let espaco = d.livre != nil ? "\(Formatacao.bytes(d.livre)) livres de \(Formatacao.bytes(d.tamanhoTotal))" : "tamanho \(Formatacao.bytes(d.tamanhoTotal))"
            print("\(d.nome) | \(d.bsdName) | sistema=\(d.tipoDeSistema ?? "?") | montado em \(d.pontoDeMontagem ?? "-") | \(espaco) | \(modo)\(motivo)")
            print("    modelo=\(d.modelo ?? "-") protocolo=\(d.protocolo ?? "-") partição=\(d.tipoDeParticao ?? "-") disco inteiro=\(d.discoInteiro ?? "-") ejetável=\(d.ejetavel) removível=\(d.removivel) interno=\(d.interno)")
        }
        let conflitos = Conflitos.detectar()
        print("Drivers conflitantes: \(conflitos.isEmpty ? "nenhum" : conflitos.map(\.rawValue).joined(separator: ", "))")
        let p = PreferenciasDriver.ler()
        print("Preferências: DisableDriver=\(p.disableDriver) Raw=\(p.enableRawDevices) Cache=\(p.enableCaching) Recovery=\(p.enableAutomaticRecovery) SFM=\(p.enableSFMConversions) Xattr=\(p.xattrMode)")
        exit(0)
    }
}
