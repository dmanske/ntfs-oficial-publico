import SwiftUI
import UniformTypeIdentifiers
import NTFSOficialMotor

/// Detalhe do disco selecionado: topo (nome, selo, ícone, botões) e os cartões.
struct DetalheDoDiscoView: View {
    @ObservedObject var estado: EstadoApp
    @ObservedObject private var idioma = Idioma.shared
    let disco: Disco
    let formatar: () -> Void

    private var ocupado: Bool { estado.operacaoEmAndamento != nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                topo
                CartaoArmazenamento(disco: disco)
                DetalhesTecnicos(disco: disco, modoRapido: estado.preferencias.enableRawDevices == 1)
                CartaoManutencao(estado: estado, disco: disco, ocupado: ocupado, formatar: formatar)
            }
            .padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 56)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    // MARK: - Topo

    private var topo: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(disco.nome).font(.system(size: 34, weight: .bold)).lineLimit(1)
                    Text(subtitulo).font(.title3).foregroundStyle(.secondary)
                }
                Spacer()
                Image(nsImage: icone).resizable().scaledToFit()
                    .frame(width: Config.tamanhoIconeVolume, height: Config.tamanhoIconeVolume)
            }
            HStack {
                selo
                Spacer()
                botoes
            }
            if disco.montado, disco.soLeitura, let explicacao = Formatacao.explicacao(disco.motivoSoLeitura) {
                Text(explicacao).font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// "USB · NTFS (NTFS Oficial)": protocolo · sistema de arquivos.
    private var subtitulo: String {
        [disco.protocolo, Formatacao.sistema(disco)].compactMap { $0 }.joined(separator: " · ")
    }

    /// Ícone real do volume montado; sem montar, o ícone genérico de disco externo.
    private var icone: NSImage {
        if let ponto = disco.pontoDeMontagem { return NSWorkspace.shared.icon(forFile: ponto) }
        if let generico = NSImage(contentsOfFile: Config.caminhoIconeDiscoExterno) { return generico }
        return NSWorkspace.shared.icon(for: .volume)
    }

    @ViewBuilder
    private var selo: some View {
        if disco.montado {
            let somenteLeitura = disco.soLeitura
            let texto = somenteLeitura
                ? (Formatacao.motivo(disco.motivoSoLeitura).map { Texto.t(.seloSoLeituraMotivo, $0) } ?? Texto.t(.seloSoLeitura))
                : Texto.t(.seloGravacao)
            Label(texto, systemImage: somenteLeitura ? "lock.fill" : "checkmark.circle.fill")
                .font(.callout.weight(.medium))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .foregroundStyle(somenteLeitura ? Color.orange : Color.green)
                .background((somenteLeitura ? Color.orange : Color.green).opacity(0.15), in: Capsule())
        } else {
            Label(Texto.t(.detNaoMontado), systemImage: "eject.circle")
                .font(.callout.weight(.medium))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .foregroundStyle(.secondary)
                .background(Color.secondary.opacity(0.15), in: Capsule())
        }
    }

    private var botoes: some View {
        HStack(spacing: 10) {
            if disco.montado {
                Button { estado.abrirNoFinder(disco) } label: {
                    Label(Texto.t(.menuAbrirFinder), systemImage: "folder")
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button { estado.montar(disco) } label: {
                    Label(Texto.t(.botMontar), systemImage: "arrow.down.circle")
                }
                .buttonStyle(.borderedProminent)
                .disabled(ocupado)
            }
            Button { estado.ejetar(disco) } label: {
                Label(Texto.t(.botEjetar), systemImage: "eject.fill")
            }
            .disabled(ocupado)
        }
        .controlSize(.large)
    }
}
