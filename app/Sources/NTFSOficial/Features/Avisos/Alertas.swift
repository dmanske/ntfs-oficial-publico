import AppKit

/// Alertas nativos (NSAlert): servem tanto para a janela quanto para o menu, que não tem janela própria.
@MainActor
enum Alertas {
    /// Alerta informativo, com área de detalhes opcional (saída das ferramentas).
    static func informar(titulo: String, texto: String, detalhes: String? = nil, aviso: Bool = false) {
        let alerta = NSAlert()
        alerta.messageText = titulo
        alerta.informativeText = texto
        alerta.alertStyle = aviso ? .warning : .informational
        alerta.addButton(withTitle: Texto.t(.ok))
        if let detalhes, !detalhes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let visor = NSTextView(frame: NSRect(x: 0, y: 0, width: 440, height: 150))
            visor.isEditable = false
            visor.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
            visor.string = String(detalhes.suffix(Config.maxCaracteresDetalhe))
            let rolagem = NSScrollView(frame: visor.frame)
            rolagem.documentView = visor
            rolagem.hasVerticalScroller = true
            rolagem.borderType = .bezelBorder
            alerta.accessoryView = rolagem
        }
        trazerParaFrente()
        alerta.runModal()
    }

    /// Pergunta com botão de confirmação (opcionalmente vermelho). true = confirmou.
    static func confirmar(titulo: String, texto: String, botao: String, destrutivo: Bool) -> Bool {
        let alerta = NSAlert()
        alerta.messageText = titulo
        alerta.informativeText = texto
        alerta.alertStyle = .warning
        let b = alerta.addButton(withTitle: botao)
        b.hasDestructiveAction = destrutivo
        alerta.addButton(withTitle: Texto.t(.cancelar))
        trazerParaFrente()
        return alerta.runModal() == .alertFirstButtonReturn
    }

    /// Depois da janela de senha do macOS o app ficava oculto (visto em 17/10/2026: `visible = false` 1 s depois da
    /// senha), e o alerta aparecia escondido. Mostra o app de novo antes de qualquer alerta.
    private static func trazerParaFrente() {
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
