import SwiftUI
import NTFSOficialMotor

/// Conteúdo do menu da barra (estilo .menu).
struct MenuView: View {
    @ObservedObject var estado: EstadoApp
    @ObservedObject private var idioma = Idioma.shared
    @Environment(\.openWindow) private var abrirJanela

    var body: some View {
        Text(Texto.t(.menuTitulo))
        Divider()
        if estado.discos.isEmpty {
            Text(Texto.t(.menuNenhum))
        }
        ForEach(estado.discos) { disco in
            itensDoDisco(disco)
            Divider()
        }
        Button(Texto.t(.menuGerenciador)) {
            abrirJanela(id: Config.idJanelaDiscos)
            NSApp.activate(ignoringOtherApps: true)
        }
        SettingsLink { Text(Texto.t(.menuPreferencias)) }
            .keyboardShortcut(",")
            .simultaneousGesture(TapGesture().onEnded { NSApp.activate(ignoringOtherApps: true) })
        Button(Texto.t(.menuSair)) { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    @ViewBuilder
    private func itensDoDisco(_ d: Disco) -> some View {
        if !d.montado {
            Text("\(d.nome) \(Texto.t(.menuNaoMontado))")
            Button(Texto.t(.menuMontar)) { estado.montar(d) }
        } else if d.soLeitura {
            Text(d.nome)
            Text(Formatacao.soLeituraComMotivo(d))
            Button(Texto.t(.menuAbrirFinder)) { estado.abrirNoFinder(d) }
            Button(Texto.t(.menuEjetar)) { estado.ejetar(d) }
        } else {
            Text(d.nome)
            if let livre = Formatacao.livreDeTotal(d) { Text(livre) }
            Button(Texto.t(.menuAbrirFinder)) { estado.abrirNoFinder(d) }
            Button(Texto.t(.menuEjetar)) { estado.ejetar(d) }
        }
    }
}
