import SwiftUI
import NTFSOficialMotor

/// Cartão "Armazenamento": barra de uso (se montado) e as colunas Capacidade / Conexão / Acesso.
struct CartaoArmazenamento: View {
    let disco: Disco
    @ObservedObject private var idioma = Idioma.shared

    var body: some View {
        VStack(spacing: 0) {
            if disco.montado {
                uso
                Divider()
            }
            HStack(alignment: .center, spacing: 0) {
                coluna("cylinder", .colCapacidade, Formatacao.bytes(disco.tamanhoTotal))
                separador
                coluna("cable.connector", .colConexao, disco.protocolo ?? "—")
                separador
                if disco.montado {
                    coluna("arrow.left.arrow.right", .colAcesso, disco.soLeitura ? Texto.t(.seloSoLeitura) : Texto.t(.seloGravacao))
                } else {
                    coluna("internaldrive", .campoTipoParticao, disco.tipoDeParticao ?? "—")
                }
            }
            .padding(.vertical, 16).padding(.horizontal, 8)
        }
        .cartao()
    }

    private var uso: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(Texto.t(.armazenamento)).font(.title3.weight(.semibold))
                Spacer()
                if let p = Formatacao.porcentagemUsada(disco) {
                    Text(Texto.t(.pctUsado, Int((p * 100).rounded()))).foregroundStyle(.secondary)
                }
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.2))
                    Capsule().fill(Color.accentColor)
                        .frame(width: g.size.width * (Formatacao.porcentagemUsada(disco) ?? 0))
                }
            }
            .frame(height: 10)
            HStack {
                Text(Texto.t(.usados, Formatacao.bytes(disco.usado)))
                Spacer()
                Text(Texto.t(.livres, Formatacao.bytes(disco.livre)))
            }
            .font(.callout).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20).padding(.vertical, 16)
    }

    private var separador: some View {
        Divider().frame(height: 40)
    }

    private func coluna(_ icone: String, _ rotulo: Chave, _ valor: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icone).font(.title2).foregroundStyle(.secondary).frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(Texto.t(rotulo)).font(.callout).foregroundStyle(.secondary)
                Text(valor).font(.title3.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
    }
}
