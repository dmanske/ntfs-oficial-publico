import SwiftUI
import NTFSOficialMotor

/// Folha de confirmação do Formatar. O botão vermelho só habilita com a caixa marcada e o nome válido.
struct FormatarView: View {
    let disco: Disco
    let confirmar: (String, FormatoVolume) -> Void
    @ObservedObject private var idioma = Idioma.shared
    @Environment(\.dismiss) private var fechar
    @State private var nome: String
    @State private var formato: FormatoVolume = .ntfs
    @State private var entendo = false

    init(disco: Disco, confirmar: @escaping (String, FormatoVolume) -> Void) {
        self.disco = disco
        self.confirmar = confirmar
        _nome = State(initialValue: disco.nome)
    }

    private var problema: ProblemaNome? { ValidacaoNome.validar(nome, formato: formato) }

    private var dica: String {
        switch formato {
        case .ntfs: return Texto.t(.dicaNTFS)
        case .exfat: return Texto.t(.dicaExFAT)
        case .fat32: return Texto.t(.dicaFAT32)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(Texto.t(.formatarTitulo, disco.nome)).font(.title2.bold())
            Text(Texto.t(.formatarTexto))
            Form {
                TextField(Texto.t(.formatarNome), text: $nome)
                Picker(Texto.t(.formatarFormato), selection: $formato) {
                    Text(Texto.t(.fmtNTFS)).tag(FormatoVolume.ntfs)
                    Text(Texto.t(.fmtExFAT)).tag(FormatoVolume.exfat)
                    Text(Texto.t(.fmtFAT32)).tag(FormatoVolume.fat32)
                }
            }
            Text(problema.map(Formatacao.problema) ?? dica)
                .font(.caption)
                .foregroundStyle(problema == nil ? Color.secondary : Color.red)
            Toggle(Texto.t(.formatarEntendo, disco.nome), isOn: $entendo)
            HStack {
                Spacer()
                Button(Texto.t(.cancelar)) { fechar() }.keyboardShortcut(.cancelAction)
                Button(Texto.t(.formatarApagar)) {
                    confirmar(nome, formato)
                    fechar()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(!entendo || problema != nil)
            }
        }
        .padding(24)
        .frame(width: 440)
    }
}
