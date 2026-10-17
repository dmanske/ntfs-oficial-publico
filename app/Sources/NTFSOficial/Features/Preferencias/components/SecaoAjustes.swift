import Foundation

/// Seções da janela de Ajustes. As que têm `noMenu` aparecem na lateral; clicar rola até o cartão.
enum SecaoAjustes: String, CaseIterable, Identifiable {
    case geral, montagem, desempenho, avancado, sobre

    var id: String { rawValue }
    var noMenu: Bool { self != .montagem }

    var icone: String {
        switch self {
        case .geral: return "gearshape"
        case .montagem: return "externaldrive"
        case .desempenho: return "gauge.with.dots.needle.33percent"
        case .avancado: return "slider.horizontal.3"
        case .sobre: return "info.circle"
        }
    }

    var titulo: Chave {
        switch self {
        case .geral: return .ajGeral
        case .montagem: return .ajMontagem
        case .desempenho: return .ajDesempenho
        case .avancado: return .ajAvancado
        case .sobre: return .ajSobre
        }
    }
}
