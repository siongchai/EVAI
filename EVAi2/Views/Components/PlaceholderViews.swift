import SwiftUI

struct HistoryPlaceholderView: View {
    @Environment(\.themeColors) private var colors

    var body: some View {
        ContentPlaceholderView(
            icon: "clock.fill",
            title: "History",
            message: "Your charging session history will appear here."
        )
    }
}

struct CapturePlaceholderView: View {
    @Environment(\.themeColors) private var colors

    var body: some View {
        ContentPlaceholderView(
            icon: "camera.fill",
            title: "AI Capture",
            message: "Upload dashboard photos, app screenshots, or receipt PDFs to analyze charging sessions."
        )
    }
}

struct AnalyticsPlaceholderView: View {
    var body: some View {
        ContentPlaceholderView(
            icon: "chart.bar.fill",
            title: "Analytics",
            message: "Detailed cost and energy analytics coming in the next phase."
        )
    }
}

struct ProfilePlaceholderView: View {
    var body: some View {
        ContentPlaceholderView(
            icon: "person.fill",
            title: "Profile",
            message: "Manage your cars and account settings."
        )
    }
}

struct SettingsPlaceholderView: View {
    @Bindable var themeManager: ThemeManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EVAiSpacing.sectionSpacing) {
                ContentPlaceholderView(
                    icon: "gearshape.fill",
                    title: "Settings",
                    message: "App preferences and AI configuration."
                )

                ThemeSwitcher(themeManager: themeManager)
                    .glassCard()
            }
            .padding(.horizontal, EVAiSpacing.horizontalPadding)
            .padding(.bottom, EVAiSpacing.xxxl)
        }
    }
}
private struct ContentPlaceholderView: View {
    @Environment(\.themeColors) private var colors

    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: EVAiSpacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(EVAiGradients.brand)
                .symbolRenderingMode(.hierarchical)

            Text(title)
                .font(EVAiTypography.title2)
                .foregroundStyle(colors.primaryText)

            Text(message)
                .font(EVAiTypography.body)
                .foregroundStyle(colors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(EVAiSpacing.xxxl)
        .glassCard()
    }
}

