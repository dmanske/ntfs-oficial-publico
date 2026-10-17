import SwiftUI
import NTFSOficialMotor

/// Cartão "Manutenção": verificar, reparar e o menu "Outras ações" (montar/desmontar e formatar).
/// Todas as ações chamam o que já existe em `AcoesDeDisco.swift`.
struct CartaoManutencao: View {
    @ObservedObject var estado: EstadoApp
    @ObservedObject private var idioma = Idioma.shared
    let disco: Disco
    let ocupado: Bool
    let formatar: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: "wrench").font(.title).foregroundStyle(.secondary).frame(width: 36)
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Texto.t(.manTitulo)).font(.headline)
                    Text(Texto.t(.manSub)).font(.callout).foregroundStyle(.secondary)
                }
                HStack(spacing: 10) {
                    Button { estado.verificar(disco) } label: {
                        Label(Texto.t(.botVerificar), systemImage: "magnifyingglass")
                    }
                    Button { estado.reparar(disco) } label: {
                        Label(Texto.t(.botReparar), systemImage: "wrench")
                    }
                }
                .controlSize(.large)
            }
            Spacer()
            Divider().frame(height: 56)
            Menu {
                if disco.montado {
                    Button(Texto.t(.botDesmontar)) { estado.desmontar(disco) }
                } else {
                    Button(Texto.t(.botMontar)) { estado.montar(disco) }
                }
                Button(Texto.t(.botFormatar), role: .destructive, action: formatar)
            } label: {
                Label(Texto.t(.manOutras), systemImage: "ellipsis")
            }
            .fixedSize()
        }
        .padding(16)
        .disabled(ocupado)
        .cartao()
    }
}
