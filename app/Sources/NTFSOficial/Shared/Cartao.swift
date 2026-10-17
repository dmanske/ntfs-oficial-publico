import SwiftUI

/// Visual de "cartão" (Gerenciador e Ajustes): fundo de controle do sistema + borda fina.
/// Só usa cores do sistema, então funciona nos modos claro e escuro.
private struct EstiloCartao: ViewModifier {
    func body(content: Content) -> some View {
        let forma = RoundedRectangle(cornerRadius: Config.raioCartao, style: .continuous)
        content
            .background(Color(nsColor: .controlBackgroundColor), in: forma)
            .clipShape(forma)
            .overlay(forma.strokeBorder(Color.primary.opacity(0.12), lineWidth: 1))
    }
}

extension View {
    func cartao() -> some View { modifier(EstiloCartao()) }
}

/// Símbolo colorido da marca (Contents/Resources). Sem o arquivo (ex.: `swift run`), cai para um SF Symbol.
struct SimboloMarca: View {
    let tamanho: CGFloat

    var body: some View {
        if let imagem = NSImage(named: Config.recursoSimbolo) {
            Image(nsImage: imagem).resizable().scaledToFit().frame(width: tamanho, height: tamanho)
        } else {
            Image(systemName: Config.iconeNormal).resizable().scaledToFit()
                .foregroundStyle(Color.accentColor).frame(width: tamanho, height: tamanho)
        }
    }
}
