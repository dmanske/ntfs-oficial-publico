import SwiftUI
import NTFSOficialMotor

/// Lateral do Gerenciador: marca no topo, lista de dispositivos e rodapé com Ajustes e a versão.
struct ListaDeDiscosView: View {
    @ObservedObject var estado: EstadoApp
    @ObservedObject private var idioma = Idioma.shared
    @Binding var selecao: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                SimboloMarca(tamanho: Config.tamanhoSimboloLateral)
                Text(Config.nomeApp).font(.title2.bold())
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 18)

            Text(Texto.t(.lateralDispositivos))
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                .padding(.horizontal, 16).padding(.bottom, 4)

            List(selection: $selecao) {
                ForEach(estado.discos) { d in
                    HStack(spacing: 10) {
                        Image(systemName: d.interno ? "internaldrive" : "externaldrive")
                            .font(.title2)
                            .frame(width: 30)
                            .foregroundStyle(d.soLeitura ? .orange : .accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(d.nome).fontWeight(.medium).lineLimit(1)
                            Text(Formatacao.subtituloLista(d))
                                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                    .padding(.vertical, 3)
                    .tag(d.id)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            Divider().padding(.horizontal, 16)
            SettingsLink {
                Label(Texto.t(.lateralAjustes), systemImage: "gearshape")
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 18).padding(.top, 12)
            .simultaneousGesture(TapGesture().onEnded { NSApp.activate(ignoringOtherApps: true) })
            Text(Texto.t(.lateralVersao, Config.versao))
                .font(.caption).foregroundStyle(.secondary)
                .padding(.horizontal, 18).padding(.top, 8).padding(.bottom, 14)
        }
        .frame(maxHeight: .infinity)
        .background(Color.primary.opacity(0.04))
    }
}
