import Foundation
import Observation
import SwiftUI

enum AppFlow: Equatable {
    case splash
    case onboarding
    case main
}

@Observable
final class AppCoordinator {
    var flow: AppFlow = .splash
    var selectedTab: AppTab = .home
    var sidebarSelection: AppTab? = .home
    var columnVisibility: NavigationSplitViewVisibility = .automatic

    private var onboardingCompleted: Bool {
        get { UserDefaults.standard.bool(forKey: AppConstants.onboardingCompletedKey) }
        set { UserDefaults.standard.set(newValue, forKey: AppConstants.onboardingCompletedKey) }
    }

    func completeSplash() {
        flow = onboardingCompleted ? .main : .onboarding
    }

    func completeOnboarding() {
        onboardingCompleted = true
        flow = .main
    }

    func skipOnboarding() {
        completeOnboarding()
    }

    func selectTab(_ tab: AppTab) {
        selectedTab = tab
        sidebarSelection = tab
    }
}
