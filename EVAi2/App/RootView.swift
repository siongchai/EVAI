import SwiftUI

struct RootView: View {
    @Bindable var coordinator: AppCoordinator
    @Bindable var themeManager: ThemeManager

    var body: some View {
        Group {
            switch coordinator.flow {
            case .splash:
                SplashView {
                    withAnimation(.easeInOut(duration: 0.45)) {
                        coordinator.completeSplash()
                    }
                }
                .transition(.opacity)

            case .onboarding:
                OnboardingView(
                    onComplete: {
                        withAnimation(.easeInOut(duration: 0.45)) {
                            coordinator.completeOnboarding()
                        }
                    },
                    onSkip: {
                        withAnimation(.easeInOut(duration: 0.45)) {
                            coordinator.skipOnboarding()
                        }
                    }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))

            case .main:
                AdaptiveNavigationView(
                    coordinator: coordinator,
                    themeManager: themeManager
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.45), value: coordinator.flow)
        .environment(themeManager)
        .applyTheme(themeManager)
    }
}

#Preview {
    RootView(
        coordinator: AppCoordinator(),
        themeManager: ThemeManager()
    )
}
