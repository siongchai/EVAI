import SwiftUI

struct ThemeSwitcher: View {
    @Environment(\.themeColors) private var colors
    @Bindable var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: EVAiSpacing.sm) {
            Text("Appearance")
                .font(EVAiTypography.headline)
                .foregroundStyle(colors.primaryText)

            HStack(spacing: EVAiSpacing.xs) {
                ForEach(AppTheme.allCases) { theme in
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            themeManager.selectedTheme = theme
                        }
                    } label: {
                        Text(theme.displayName)
                            .font(EVAiTypography.caption)
                            .foregroundStyle(
                                themeManager.selectedTheme == theme ? .white : colors.secondaryText
                            )
                            .padding(.horizontal, EVAiSpacing.md)
                            .padding(.vertical, EVAiSpacing.xs)
                            .background {
                                if themeManager.selectedTheme == theme {
                                    Capsule(style: .continuous)
                                        .fill(EVAiGradients.button)
                                } else {
                                    Capsule(style: .continuous)
                                        .fill(colors.cardBackground)
                                        .overlay {
                                            Capsule(style: .continuous)
                                                .strokeBorder(colors.cardBorder, lineWidth: 1)
                                        }
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
