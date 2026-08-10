import SwiftUI

enum AccessibilitySupport {
    static var isReduceMotionEnabled: Bool {
        UIAccessibility.isReduceMotionEnabled
    }

    static var isVoiceOverRunning: Bool {
        UIAccessibility.isVoiceOverRunning
    }

    static var isDarkerSystemColorsEnabled: Bool {
        UIAccessibility.isDarkerSystemColorsEnabled
    }
}

extension View {
    func evaiAccessibleLabel(_ label: String, hint: String? = nil) -> some View {
        modifier(EVAiAccessibilityModifier(label: label, hint: hint))
    }

    func evaiReduceMotionAnimation<V: Equatable>(
        _ preferredAnimation: Animation? = .default,
        value: V
    ) -> some View {
        self.animation(AccessibilitySupport.isReduceMotionEnabled ? nil : preferredAnimation, value: value)
    }

    func evaiDynamicTypeSize(_ range: ClosedRange<DynamicTypeSize> = .xSmall ... .accessibility3) -> some View {
        dynamicTypeSize(range)
    }
}

private struct EVAiAccessibilityModifier: ViewModifier {
    let label: String
    let hint: String?

    func body(content: Content) -> some View {
        if let hint {
            content.accessibilityLabel(label).accessibilityHint(hint)
        } else {
            content.accessibilityLabel(label)
        }
    }
}

struct EVAiFocusableCard<Content: View>: View {
    @Environment(\.themeColors) private var colors
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(EVAiSpacing.cardPadding)
            .background(colors.cardBackground, in: RoundedRectangle(cornerRadius: EVAiSpacing.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: EVAiSpacing.cardRadius, style: .continuous)
                    .strokeBorder(colors.cardBorder, lineWidth: 0.5)
            }
            .accessibilityElement(children: .contain)
    }
}
