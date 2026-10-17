import SwiftUI
import NTFSOficialMotor

/// Sem ícone no Dock (o Info.plist também tem LSUIElement).
final class DelegadoDoApp: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        // App de barra de menus não pode entrar no encerramento automático do macOS: em segundo plano o sistema o
        // escondia (log: "WouldBeTerminatedByTAL=1", visible = false, janelas e alertas sumiam) e poderia fechá-lo,
        // levando junto o ícone da barra. Visto em 17/10/2026.
        ProcessInfo.processInfo.disableAutomaticTermination(Config.motivoSemEncerramento)
        ProcessInfo.processInfo.disableSuddenTermination()
    }
}

struct NTFSOficialApp: App {
    @NSApplicationDelegateAdaptor(DelegadoDoApp.self) private var delegado
    @StateObject private var estado = EstadoApp()
    @ObservedObject private var idioma = Idioma.shared

    var body: some Scene {
        MenuBarExtra {
            MenuView(estado: estado)
        } label: {
            IconeBarra(aviso: estado.algumSoLeituraComMotivo)
        }
        .menuBarExtraStyle(.menu)

        Window(Texto.t(.janelaTitulo), id: Config.idJanelaDiscos) {
            DiscosView(estado: estado)
        }
        .windowResizability(.contentSize)

        Settings {
            PreferenciasView(estado: estado)
        }
    }
}

/// Entrada: `--listar` imprime os discos NTFS no terminal e sai; sem argumento abre o app.
@main
enum Entrada {
    static func main() {
        if CommandLine.arguments.contains(Config.argumentoListar) {
            MainActor.assumeIsolated { Listagem.executar() }
        } else {
            NTFSOficialApp.main()
        }
    }
}
