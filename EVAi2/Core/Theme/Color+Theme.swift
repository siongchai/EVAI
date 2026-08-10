import SwiftUI

extension Color {
    static let primaryBlue = Color(hex: 0x007AFF)
    static let electricCyan = Color(hex: 0x00D4FF)
    static let aiPurple = Color(hex: 0x8B5CF6)
    static let darkNavy = Color(hex: 0x081226)
    static let secondaryGray = Color(hex: 0x8A8F98)

    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}

enum EVAiGradients {
    static let brand = LinearGradient(
        colors: [.primaryBlue, .electricCyan, .aiPurple],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let button = LinearGradient(
        colors: [.primaryBlue, .aiPurple],
        startPoint: .leading,
        endPoint: .trailing
    )
}

struct ThemeColors {
    let background: Color
    let secondaryBackground: Color
    let cardBackground: Color
    let cardBorder: Color
    let primaryText: Color
    let secondaryText: Color
    let accent: Color
    let shadow: Color
    let tabBarBackground: Color
    let insightBackground: Color
    let insightBorder: Color
    let chartGrid: Color
    let destructive: Color

    static func palette(for scheme: ColorScheme) -> ThemeColors {
        switch scheme {
        case .dark:
            ThemeColors(
                background: .darkNavy,
                secondaryBackground: Color(hex: 0x0F1A33),
                cardBackground: Color.white.opacity(0.08),
                cardBorder: Color.white.opacity(0.18),
                primaryText: .white,
                secondaryText: .secondaryGray,
                accent: .primaryBlue,
                shadow: Color.black.opacity(0.35),
                tabBarBackground: Color(hex: 0x0A1528).opacity(0.92),
                insightBackground: Color.primaryBlue.opacity(0.18),
                insightBorder: Color.primaryBlue.opacity(0.35),
                chartGrid: Color.white.opacity(0.08),
                destructive: Color(hex: 0xFF453A)
            )
        default:
            ThemeColors(
                background: Color(hex: 0xF2F4F8),
                secondaryBackground: .white,
                cardBackground: Color.white.opacity(0.72),
                cardBorder: Color.white.opacity(0.85),
                primaryText: .darkNavy,
                secondaryText: .secondaryGray,
                accent: .primaryBlue,
                shadow: Color.black.opacity(0.08),
                tabBarBackground: Color.white.opacity(0.88),
                insightBackground: Color.primaryBlue.opacity(0.10),
                insightBorder: Color.primaryBlue.opacity(0.22),
                chartGrid: Color.black.opacity(0.06),
                destructive: Color(hex: 0xFF3B30)
            )
        }
    }
}

private struct ThemeColorsKey: EnvironmentKey {
    static let defaultValue = ThemeColors.palette(for: .light)
}

extension EnvironmentValues {
    var themeColors: ThemeColors {
        get { self[ThemeColorsKey.self] }
        set { self[ThemeColorsKey.self] = newValue }
    }
}

struct ThemeColorsModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var themeManager: ThemeManager

    func body(content: Content) -> some View {
        let resolved = themeManager.resolvedScheme(for: colorScheme)
        content
            .environment(\.themeColors, ThemeColors.palette(for: resolved))
            .preferredColorScheme(themeManager.preferredColorScheme)
    }
}

extension View {
    func applyTheme(_ themeManager: ThemeManager) -> some View {
        modifier(ThemeColorsModifier(themeManager: themeManager))
    }
}
