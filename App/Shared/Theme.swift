import SwiftUI
import UIKit

/// Sistema de design (derivado dos ecrãs do Stitch "Minimalist iOS Finance App").
/// Todas as cores têm variante para modo escuro.
enum Theme {
    static func dynamic(_ light: String, _ dark: String) -> Color {
        Color(UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    static let background = dynamic("#F9F9F7", "#101111")
    static let card = dynamic("#FFFFFF", "#1C1D1E")
    static let cardMuted = dynamic("#F4F4F2", "#242526")
    static let tile = dynamic("#EEEEEC", "#2C2D2F")
    static let outline = dynamic("#E2E3E1", "#2E2F31")
    static let track = dynamic("#E8E8E6", "#333436")

    static let primary = dynamic("#3B3BF5", "#6E6EFF")
    static let primaryDeep = dynamic("#1A0BE0", "#A5A5FF")
    static let primarySoft = dynamic("#E1E0FF", "#26264F")

    static let textPrimary = dynamic("#1A1C1B", "#F1F1EF")
    static let textSecondary = dynamic("#5F5E5E", "#A8A7A7")

    static let positive = dynamic("#13803A", "#5DD27A")
    static let positiveSoft = dynamic("#D7F5DF", "#16351F")
    static let warning = dynamic("#C26A00", "#F5A524")
    static let warningSoft = dynamic("#FFDCC3", "#45290F")
    static let danger = dynamic("#BA1A1A", "#FF6B6B")
    static let dangerSoft = dynamic("#FFDAD6", "#4A1A1A")

    /// Chip selecionado (preto em modo claro, quase branco em modo escuro).
    static let ink = dynamic("#1A1C1B", "#F1F1EF")
    static let onInk = dynamic("#FFFFFF", "#1A1C1B")

    static let cardRadius: CGFloat = 24
    static let fieldRadius: CGFloat = 16
    static let margin: CGFloat = 20
}

extension UIColor {
    convenience init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        let v = UInt64(s, radix: 16) ?? 0x8E8E93
        self.init(red: CGFloat((v >> 16) & 0xFF) / 255,
                  green: CGFloat((v >> 8) & 0xFF) / 255,
                  blue: CGFloat(v & 0xFF) / 255,
                  alpha: 1)
    }
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case automatic, light, dark
    var id: String { rawValue }
    var label: String {
        switch self {
        case .automatic: return "Automático"
        case .light: return "Claro"
        case .dark: return "Escuro"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .automatic: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
