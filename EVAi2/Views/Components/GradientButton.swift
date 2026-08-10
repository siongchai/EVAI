import SwiftUI

struct GradientButton: View {
    let title: String
    var iconName: String? = nil
    var isEnabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: EVAiSpacing.xs) {
                if let iconName {
                    Image(systemName: iconName)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(title)
                    .font(EVAiTypography.button)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, EVAiSpacing.md)
            .background {
                RoundedRectangle(cornerRadius: EVAiSpacing.buttonRadius, style: .continuous)
                    .fill(EVAiGradients.button)
                    .opacity(isEnabled ? 1 : 0.45)
            }
            .shadow(color: Color.aiPurple.opacity(0.35), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

struct OutlineButton: View {
    @Environment(\.themeColors) private var colors

    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(EVAiTypography.button)
                .foregroundStyle(colors.primaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, EVAiSpacing.md)
                .background {
                    RoundedRectangle(cornerRadius: EVAiSpacing.buttonRadius, style: .continuous)
                        .strokeBorder(colors.cardBorder, lineWidth: 1.5)
                }
        }
        .buttonStyle(.plain)
    }
}
