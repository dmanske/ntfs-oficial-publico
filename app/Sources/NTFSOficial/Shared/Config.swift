import Foundation

/// Valores ajustáveis do app, num lugar só.
enum Config {
    static let versao = "0.1.1"
    /// Motivo registrado no macOS ao desligar o encerramento automático (app de barra de menus).
    static let motivoSemEncerramento = "NTFS Oficial fica na barra de menus"
    static let identificador = "com.danielmanske.ntfsoficial.app"
    /// Nome de marca: não se traduz.
    static let nomeApp = "NTFS Oficial"

    // Recursos em Contents/Resources (copiados por scripts/montar-app.sh); rodando por `swift run` não existem
    static let recursoBarra = "BarraTemplate"
    static let recursoSimbolo = "simbolo-colorido"
    /// Ícone genérico de disco externo do sistema (para disco não montado); se faltar, usa o de volume.
    static let caminhoIconeDiscoExterno = "/System/Library/Extensions/IOStorageFamily.kext/Contents/Resources/External.icns"
    static let ladoIconeBarra: CGFloat = 18

    // Janela do Gerenciador de discos
    static let idJanelaDiscos = "discos"
    static let larguraJanela: CGFloat = 1000
    static let alturaJanela: CGFloat = 700
    static let larguraLista: CGFloat = 250
    static let tamanhoSimboloLateral: CGFloat = 34
    static let tamanhoIconeVolume: CGFloat = 64

    // Janela de Ajustes
    static let larguraAjustes: CGFloat = 900
    static let alturaAjustes: CGFloat = 700
    static let larguraLateralAjustes: CGFloat = 230
    static let tamanhoIconeAjustes: CGFloat = 96
    /// Parte do identificador que o SwiftUI dá à janela de Ajustes ("com_apple_SwiftUI_Settings_window").
    static let idJanelaAjustesSistema = "Settings"

    // Cartões (Gerenciador e Ajustes)
    static let raioCartao: CGFloat = 12

    // Atualização da lista (espaço livre muda sem avisar o DiskArbitration)
    static let intervaloAtualizacao: TimeInterval = 15
    /// Espera depois de abrir o app antes de checar drivers conflitantes.
    static let atrasoAvisoConflitos: TimeInterval = 1.0
    /// Quanto da saída das ferramentas aparece no alerta.
    static let maxCaracteresDetalhe = 4000

    // UserDefaults
    static let chaveIdioma = "idioma"

    // Ícones do menu (SF Symbols)
    // (usados quando a imagem de identidade não está no pacote)
    static let iconeNormal = "externaldrive"
    static let iconeAviso = "externaldrive.badge.exclamationmark"

    // Diagnóstico de linha de comando
    static let argumentoListar = "--listar"
    static let esperaListarSegundos: TimeInterval = 1.5
}
