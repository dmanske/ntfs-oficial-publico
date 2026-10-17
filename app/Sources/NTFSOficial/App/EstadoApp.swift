import SwiftUI
import Combine
import NTFSOficialMotor

/// Estado único do app: a lista de discos, as operações em andamento e as preferências do driver.
/// Criado na abertura do app (os avisos e a atualização não dependem de alguma janela estar aberta).
@MainActor
final class EstadoApp: ObservableObject {
    let monitor = MonitorDeDiscos()
    let operacoes: OperacoesDeDisco
    @Published var preferencias = PreferenciasDriver.ler()
    @Published var operacaoEmAndamento: String?

    private var assinaturas = Set<AnyCancellable>()
    private var avisouConflitos = false
    private var temporizador: Timer?

    var discos: [Disco] { monitor.discos }
    var algumSoLeituraComMotivo: Bool { discos.contains { $0.soLeitura && $0.motivoSoLeitura != nil } }

    init() {
        operacoes = OperacoesDeDisco(monitor: monitor)
        monitor.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &assinaturas)
        Idioma.shared.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &assinaturas)
        // Quando a lista muda, confere de novo os drivers conflitantes (o alerta sai uma vez por sessão).
        monitor.$discos.dropFirst().sink { [weak self] _ in
            DispatchQueue.main.async { self?.verificarConflitos() }
        }.store(in: &assinaturas)
        monitor.iniciar()
        temporizador = Timer.scheduledTimer(withTimeInterval: Config.intervaloAtualizacao, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.monitor.recarregar()
                self?.preferencias = PreferenciasDriver.ler()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Config.atrasoAvisoConflitos) { [weak self] in
            self?.verificarConflitos()
        }
    }

    // MARK: - Avisos

    func verificarConflitos() {
        guard !avisouConflitos else { return }
        let outros = Conflitos.detectar()
        guard !outros.isEmpty else { return }
        avisouConflitos = true
        let lista = outros.map(Formatacao.nome).joined(separator: ", ")
        Alertas.informar(titulo: Texto.t(.avisoDriverTitulo), texto: Texto.t(.avisoDriverTexto, lista), aviso: true)
    }
}
