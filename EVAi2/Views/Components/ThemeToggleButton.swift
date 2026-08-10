import SwiftUI

struct ThemeToggleButton: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.themeColors) private var colors
    @Environment(ThemeManager.self) private var themeManager

    private var isDark: Bool {
        themeManager.isDarkMode(systemScheme: colorScheme)
    }

    var body: some View {
        HStack(spacing: 2) {
            themeSegment(
                icon: "sun.max.fill",
                isActive: !isDark,
                accessibilityLabel: "Light mode"
            ) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    themeManager.setTheme(.light)
                }
            }

            themeSegment(
                icon: "moon.fill",
                isActive: isDark,
                accessibilityLabel: "Dark mode"
            ) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    themeManager.setTheme(.dark)
                }
            }
        }
        .padding(4)
        .background {
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .background {
                    Capsule(style: .continuous)
                        .fill(colors.cardBackground)
                }
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(colors.cardBorder, lineWidth: 1)
                }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Theme")
    }

    private func themeSegment(
        icon: String,
        isActive: Bool,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isActive ? .white : colors.secondaryText)
                .frame(width: 36, height: 36)
                .background {
                    if isActive {
                        Circle()
                            .fill(EVAiGradients.button)
                            .shadow(color: Color.aiPurple.opacity(0.3), radius: 6, y: 2)
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
    }
}

#Preview {
    ThemeToggleButton()
        .padding()
        .environment(ThemeManager())
        .applyTheme(ThemeManager())
}
