import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

@Observable
final class ThemeManager {
    private static let storageKey = "evai.app.theme"

    var selectedTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(selectedTheme.rawValue, forKey: Self.storageKey)
        }
    }

    init() {
        let stored = UserDefaults.standard.string(forKey: Self.storageKey) ?? AppTheme.system.rawValue
        selectedTheme = AppTheme(rawValue: stored) ?? .system
    }

    var preferredColorScheme: ColorScheme? {
        selectedTheme.colorScheme
    }

    func resolvedScheme(for systemScheme: ColorScheme) -> ColorScheme {
        selectedTheme.colorScheme ?? systemScheme
    }

    func isDarkMode(systemScheme: ColorScheme) -> Bool {
        resolvedScheme(for: systemScheme) == .dark
    }

    func setTheme(_ theme: AppTheme) {
        selectedTheme = theme
    }

    func toggleLightDark(systemScheme: ColorScheme) {
        selectedTheme = isDarkMode(systemScheme: systemScheme) ? .light : .dark
    }
}
