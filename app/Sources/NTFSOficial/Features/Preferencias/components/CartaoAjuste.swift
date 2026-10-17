import SwiftUI

/// Cartão de uma seção dos Ajustes: cabeçalho (ícone, título, subtítulo) e as linhas embaixo.
/// Com `recolhivel`, o cabeçalho vira um botão com chevron que abre/fecha as linhas.
struct CartaoAjuste<Conteudo: View>: View {
    let icone: String
    let titulo: String
    let subtitulo: String
    let recolhivel: Binding<Bool>?
    let conteudo: Conteudo

    init(icone: String, titulo: String, subtitulo: String, recolhivel: Binding<Bool>? = nil,
         @ViewBuilder conteudo: () -> Conteudo) {
        self.icone = icone
        self.titulo = titulo
        self.subtitulo = subtitulo
        self.recolhivel = recolhivel
        self.conteudo = conteudo()
    }

    private var aberto: Bool { recolhivel?.wrappedValue ?? true }

    var body: some View {
        VStack(spacing: 0) {
            cabecalho
            if aberto {
                Divider()
                conteudo
            }
        }
        .cartao()
    }

    @ViewBuilder
    private var cabecalho: some View {
        if let recolhivel {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { recolhivel.wrappedValue.toggle() }
            } label: { conteudoDoCabecalho(chevron: true) }
            .buttonStyle(.plain)
        } else {
            conteudoDoCabecalho(chevron: false)
        }
    }

    private func conteudoDoCabecalho(chevron: Bool) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icone).font(.title2).foregroundStyle(.secondary).frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(titulo).font(.headline)
                Text(subtitulo).font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            if chevron {
                Image(systemName: "chevron.down").rotationEffect(.degrees(aberto ? 0 : -90))
                    .font(.callout.weight(.semibold)).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Color.primary.opacity(0.04))
        .contentShape(Rectangle())
    }
}

/// Uma linha de ajuste: título e descrição cinza à esquerda, o controle à direita.
struct LinhaAjuste<Controle: View>: View {
    let titulo: String
    let descricao: String
    let controle: Controle

    init(_ titulo: String, descricao: String, @ViewBuilder controle: () -> Controle) {
        self.titulo = titulo
        self.descricao = descricao
        self.controle = controle()
    }

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(titulo)
                Text(descricao).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            controle
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }
}
