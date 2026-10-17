import SwiftUI
import NTFSOficialMotor

/// Janela "Gerenciador de discos": lateral com a lista à esquerda, detalhes à direita.
struct DiscosView: View {
    @ObservedObject var estado: EstadoApp
    @ObservedObject private var idioma = Idioma.shared
    @State private var selecionado: String?
    @State private var discoParaFormatar: Disco?

    private var disco: Disco? {
        estado.discos.first { $0.id == selecionado } ?? estado.discos.first
    }

    var body: some View {
        HStack(spacing: 0) {
            ListaDeDiscosView(estado: estado, selecao: Binding(get: { disco?.id }, set: { selecionado = $0 }))
                .frame(width: Config.larguraLista)
            Divider()
            Group {
                if let disco {
                    DetalheDoDiscoView(estado: estado, disco: disco) { discoParaFormatar = disco }
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: Config.iconeNormal).font(.system(size: 40)).foregroundStyle(.tertiary)
                        Text(Texto.t(.semDiscos)).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(width: Config.larguraJanela, height: Config.alturaJanela)
        .navigationTitle(Texto.t(.janelaTitulo))
        .overlay(alignment: .bottom) {
            if let op = estado.operacaoEmAndamento {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(op)
                }
                .padding(10)
                .background(.regularMaterial, in: Capsule())
                .padding(.bottom, 14)
            }
        }
        .sheet(item: $discoParaFormatar) { d in
            FormatarView(disco: d) { nome, formato in
                estado.formatar(d, nome: nome, formato: formato)
            }
        }
    }
}
