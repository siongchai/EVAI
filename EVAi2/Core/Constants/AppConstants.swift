import Foundation

enum AppConstants {
    static let appName = "EVAi"
    static let tagline = "AI-Powered EV Charging Analytics"
    static let defaultUserName = "TSC"
    static let currencyCode = "SGD"
    static let currencySymbol = "$"
    static let splashDuration: TimeInterval = 2.4
    static let onboardingCompletedKey = "evai.onboarding.completed"
}

enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case home
    case history
    case capture
    case analytics
    case profile
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .history: "History"
        case .capture: "Capture"
        case .analytics: "Analytics"
        case .profile: "Profile"
        case .settings: "Settings"
        }
    }

    var iconName: String {
        switch self {
        case .home: "house.fill"
        case .history: "clock.fill"
        case .capture: "plus"
        case .analytics: "chart.bar.fill"
        case .profile: "person.fill"
        case .settings: "gearshape.fill"
        }
    }

    static var phoneTabs: [AppTab] {
        [.home, .history, .capture, .analytics, .profile]
    }

    static var sidebarTabs: [AppTab] {
        allCases
    }
}
