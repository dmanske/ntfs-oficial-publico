import SwiftUI
import NTFSOficialMotor

/// Cartão recolhível (fechado por padrão) com os dados técnicos do disco.
struct DetalhesTecnicos: View {
    let disco: Disco
    let modoRapido: Bool
    @ObservedObject private var idioma = Idioma.shared
    @State private var aberto = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { aberto.toggle() }
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "chevron.right").rotationEffect(.degrees(aberto ? 90 : 0))
                        .font(.callout.weight(.semibold)).foregroundStyle(.secondary).frame(width: 14)
                    Image(systemName: "doc.text").font(.title2).foregroundStyle(.secondary).frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Texto.t(.detTecnicosTitulo)).font(.headline)
                        Text(Texto.t(.detTecnicosSub)).font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if aberto {
                Divider()
                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                    linha(.campoSistema, Formatacao.sistema(disco))
                    linha(.campoIdentificador, disco.bsdName)
                    linha(.campoPontoMontagem, disco.pontoDeMontagem ?? "—")
                    if disco.usaNTFSOficial {
                        linha(.campoModoAcesso, modoRapido ? Texto.t(.modoRapido) : Texto.t(.modoPadrao))
                    }
                    linha(.campoTipoParticao, disco.tipoDeParticao ?? "—")
                    linha(.campoEjetavel, disco.ejetavel ? Texto.t(.sim) : Texto.t(.nao))
                    linha(.campoDiscoInteiro, discoInteiro)
                    linha(.campoModelo, disco.modelo ?? "—")
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .cartao()
    }

    private var discoInteiro: String {
        guard let inteiro = disco.discoInteiro else { return "—" }
        return "\(inteiro) (\(Formatacao.bytes(disco.tamanhoDiscoInteiro)))"
    }

    private func linha(_ chave: Chave, _ valor: String) -> some View {
        GridRow {
            Text(Texto.t(chave)).foregroundStyle(.secondary)
            Text(valor).textSelection(.enabled)
        }
    }
}
