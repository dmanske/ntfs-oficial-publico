import SwiftUI
import ServiceManagement
import NTFSOficialMotor

/// Ajustes: lateral com as seções (clicar rola até o cartão) e, embaixo, o rodapé fixo com Cancelar / Aplicar.
/// As do driver são gravadas no plist com uma senha só (Aplicar); idioma e abrir no login valem na hora.
struct PreferenciasView: View {
    @ObservedObject var estado: EstadoApp
    @ObservedObject private var idioma = Idioma.shared
    @State private var rascunho = PreferenciasDriver.ler()
    @State private var abrirNoLogin = SMAppService.mainApp.status == .enabled
    @State private var aplicando = false
    @State private var secaoAtual = SecaoAjustes.geral
    @State private var avancadoAberto = true

    private var mudou: Bool { rascunho != estado.preferencias }

    var body: some View {
        ScrollViewReader { rolagem in
            HStack(spacing: 0) {
                lateral(rolagem)
                    .frame(width: Config.larguraLateralAjustes)
                Divider()
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            titulo.id(Self.topo)
                            cartaoGeral.id(SecaoAjustes.geral)
                            cartaoMontagem.id(SecaoAjustes.montagem)
                            cartaoDesempenho.id(SecaoAjustes.desempenho)
                            cartaoAvancado.id(SecaoAjustes.avancado)
                            cartaoSobre.id(SecaoAjustes.sobre)
                        }
                        .padding(.horizontal, 24).padding(.top, 18).padding(.bottom, 12)
                    }
                    rodape
                }
            }
            // O macOS mantém a tela dos Ajustes viva entre aberturas (o onAppear não roda de novo): ao fechar a
            // janela, volta ao topo e descarta o que não foi aplicado. Sem isto ela reabria rolada no meio.
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { aviso in
                guard let janela = aviso.object as? NSWindow,
                      janela.identifier?.rawValue.contains(Config.idJanelaAjustesSistema) == true else { return }
                secaoAtual = .geral
                rolagem.scrollTo(Self.topo, anchor: .top)
                rascunho = estado.preferencias
            }
        }
        .frame(width: Config.larguraAjustes, height: Config.alturaAjustes)
        .onAppear {
            rascunho = PreferenciasDriver.ler()
            estado.preferencias = rascunho
            abrirNoLogin = SMAppService.mainApp.status == .enabled
        }
    }

    /// Âncora do título; "Geral" rola até aqui para o título não ficar cortado.
    private static let topo = "topo"

    // MARK: - Lateral

    private func lateral(_ rolagem: ScrollViewProxy) -> some View {
        VStack(spacing: 6) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable().scaledToFit()
                .frame(width: Config.tamanhoIconeAjustes, height: Config.tamanhoIconeAjustes)
                .padding(.top, 28)
            Text(Config.nomeApp).font(.title2.bold()).padding(.bottom, 18)
            ForEach(SecaoAjustes.allCases.filter(\.noMenu)) { secao in
                let atual = secao == secaoAtual
                Button {
                    secaoAtual = secao
                    withAnimation {
                        if secao == .geral { rolagem.scrollTo(Self.topo, anchor: .top) } else { rolagem.scrollTo(secao, anchor: .top) }
                    }
                } label: {
                    Label(Texto.t(secao.titulo), systemImage: secao.icone)
                        .foregroundStyle(atual ? Color.accentColor : Color.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12).padding(.vertical, 9)
                        .background(atual ? Color.accentColor.opacity(0.15) : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(maxHeight: .infinity)
        .background(Color.primary.opacity(0.04))
    }

    // MARK: - Conteúdo

    private var titulo: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(Texto.t(.ajTitulo)).font(.system(size: 34, weight: .bold))
            Text(Texto.t(.ajSubtitulo)).font(.title3).foregroundStyle(.secondary)
        }
    }

    private var cartaoGeral: some View {
        CartaoAjuste(icone: SecaoAjustes.geral.icone, titulo: Texto.t(.ajGeral), subtitulo: Texto.t(.ajGeralSub)) {
            LinhaAjuste(Texto.t(.prefIdioma), descricao: Texto.t(.ajIdiomaDesc)) {
                Picker("", selection: $idioma.codigo) {
                    Text("Português (Brasil)").tag(Idioma.ptBR)
                    Text("English").tag(Idioma.en)
                }
                .labelsHidden().fixedSize()
            }
            Divider().padding(.leading, 16)
            LinhaAjuste(Texto.t(.prefLogin), descricao: Texto.t(.ajLoginDesc)) {
                Toggle("", isOn: Binding(get: { abrirNoLogin }, set: mudarLogin))
                    .labelsHidden().toggleStyle(.switch)
            }
        }
    }

    private var cartaoMontagem: some View {
        CartaoAjuste(icone: SecaoAjustes.montagem.icone, titulo: Texto.t(.ajMontagem), subtitulo: Texto.t(.ajMontagemSub)) {
            LinhaAjuste(Texto.t(.prefMontarGravacao), descricao: Texto.t(.ajMontarDesc)) {
                Toggle("", isOn: Binding(get: { rascunho.disableDriver == 0 }, set: { rascunho.disableDriver = $0 ? 0 : 1 }))
                    .labelsHidden().toggleStyle(.switch)
            }
            Divider().padding(.leading, 16)
            interruptor(.prefSFM, desc: .prefSFMDesc, valor: $rascunho.enableSFMConversions)
            Divider().padding(.leading, 16)
            LinhaAjuste(Texto.t(.prefXattr), descricao: Texto.t(.ajXattrDesc)) {
                Picker("", selection: $rascunho.xattrMode) {
                    Text(Texto.t(.xattrTudo)).tag(2)
                    Text(Texto.t(.xattrEssencial)).tag(1)
                    Text(Texto.t(.xattrNenhum)).tag(0)
                }
                .labelsHidden().fixedSize()
            }
        }
    }

    private var cartaoDesempenho: some View {
        CartaoAjuste(icone: SecaoAjustes.desempenho.icone, titulo: Texto.t(.ajDesempenho), subtitulo: Texto.t(.ajDesempenhoSub)) {
            interruptor(.prefModoRapido, desc: .prefModoRapidoDesc, valor: $rascunho.enableRawDevices)
            Divider().padding(.leading, 16)
            interruptor(.prefCache, desc: .prefCacheDesc, valor: $rascunho.enableCaching)
        }
    }

    private var cartaoAvancado: some View {
        CartaoAjuste(icone: "wrench", titulo: Texto.t(.ajAvancado), subtitulo: Texto.t(.ajAvancadoSub),
                     recolhivel: $avancadoAberto) {
            interruptor(.prefReparo, desc: .prefReparoDesc, valor: $rascunho.enableAutomaticRecovery)
        }
    }

    private var cartaoSobre: some View {
        CartaoAjuste(icone: SecaoAjustes.sobre.icone, titulo: Texto.t(.ajSobre), subtitulo: Texto.t(.ajSobreDescricao)) {
            HStack(spacing: 14) {
                SimboloMarca(tamanho: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(Config.nomeApp).font(.headline)
                    Text(Texto.t(.prefVersao, Config.versao)).font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(16)
        }
    }

    private func interruptor(_ titulo: Chave, desc: Chave, valor: Binding<Int>) -> some View {
        LinhaAjuste(Texto.t(titulo), descricao: Texto.t(desc)) {
            Toggle("", isOn: Binding(get: { valor.wrappedValue == 1 }, set: { valor.wrappedValue = $0 ? 1 : 0 }))
                .labelsHidden().toggleStyle(.switch)
        }
    }

    // MARK: - Rodapé fixo

    private var rodape: some View {
        HStack(spacing: 12) {
            Label(Texto.t(.ajAvisoProximo), systemImage: "info.circle")
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            Button(Texto.t(.cancelar)) { rascunho = estado.preferencias }
                .disabled(!mudou || aplicando)
                .controlSize(.large)
            Button(Texto.t(.prefAplicar), action: aplicar)
                .buttonStyle(.borderedProminent)
                .disabled(!mudou || aplicando)
                .controlSize(.large)
        }
        .padding(.horizontal, 24).padding(.vertical, 12)
        .background(.bar)
    }

    // MARK: - Ações (mesma lógica de antes)

    private func aplicar() {
        aplicando = true
        do {
            try rascunho.gravar()
            estado.preferencias = rascunho
            Alertas.informar(titulo: Texto.t(.prefAplicadoOk), texto: Texto.t(.prefRodape))
        } catch ErroAdministrador.cancelado {
            Alertas.informar(titulo: Texto.t(.prefAplicar), texto: Texto.t(.senhaCancelada))
        } catch {
            Alertas.informar(titulo: Texto.t(.prefAplicar), texto: Texto.t(.falhouGenerico, error.localizedDescription), aviso: true)
        }
        aplicando = false
    }

    private func mudarLogin(_ ligar: Bool) {
        do {
            if ligar { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            Alertas.informar(titulo: Texto.t(.prefLogin), texto: Texto.t(.prefLoginErro, error.localizedDescription), aviso: true)
        }
        abrirNoLogin = SMAppService.mainApp.status == .enabled
    }
}
