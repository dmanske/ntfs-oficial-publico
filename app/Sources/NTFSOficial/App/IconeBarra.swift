import SwiftUI

/// Ícone da barra de menus: o símbolo da marca como imagem template (o macOS pinta conforme o tema).
/// Com aviso, o mesmo símbolo ganha um círculo com "!" no canto inferior direito (ainda template).
/// Sem a imagem no pacote (ex.: `swift run`), usa o SF Symbol de antes.
struct IconeBarra: View {
    let aviso: Bool

    var body: some View {
        if let imagem = Self.imagem(aviso: aviso) {
            Image(nsImage: imagem)
        } else {
            Image(systemName: aviso ? Config.iconeAviso : Config.iconeNormal)
        }
    }

    static func imagem(aviso: Bool) -> NSImage? {
        guard let base = NSImage(named: Config.recursoBarra) else { return nil }
        let tamanho = NSSize(width: Config.ladoIconeBarra, height: Config.ladoIconeBarra)
        guard aviso else {
            let normal = (base.copy() as? NSImage) ?? base
            normal.size = tamanho
            normal.isTemplate = true
            return normal
        }
        let comAviso = NSImage(size: tamanho, flipped: false) { area in
            base.draw(in: area)
            let raio: CGFloat = 4.5
            let circulo = NSRect(x: area.maxX - 2 * raio - 0.5, y: 0.5, width: 2 * raio, height: 2 * raio)
            let contexto = NSGraphicsContext.current
            // Abre um vazio em volta da marca para ela não "colar" no símbolo.
            contexto?.compositingOperation = .destinationOut
            NSColor.black.setFill()
            NSBezierPath(ovalIn: circulo.insetBy(dx: -1.3, dy: -1.3)).fill()
            contexto?.compositingOperation = .sourceOver
            NSBezierPath(ovalIn: circulo).fill()
            // O "!" é recortado do círculo.
            contexto?.compositingOperation = .destinationOut
            let atributos: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 7.5, weight: .heavy), .foregroundColor: NSColor.black]
            let exclamacao = NSAttributedString(string: "!", attributes: atributos)
            let medida = exclamacao.size()
            exclamacao.draw(at: NSPoint(x: circulo.midX - medida.width / 2, y: circulo.midY - medida.height / 2))
            contexto?.compositingOperation = .sourceOver
            return true
        }
        comAviso.isTemplate = true
        return comAviso
    }
}
