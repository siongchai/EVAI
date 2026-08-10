import SwiftUI

struct GlassBackground: ViewModifier {
    @Environment(\.themeColors) private var colors
    @Environment(\.colorScheme) private var colorScheme

    var cornerRadius: CGFloat = EVAiSpacing.cardRadius
    var padding: CGFloat = EVAiSpacing.cardPadding

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .background {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(colors.cardBackground)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(colors.cardBorder, lineWidth: 1)
                    }
                    .shadow(color: colors.shadow, radius: colorScheme == .dark ? 16 : 12, y: 6)
            }
    }
}

struct GlassCapsuleBackground: ViewModifier {
    @Environment(\.themeColors) private var colors

    func body(content: Content) -> some View {
        content
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
    }
}

extension View {
    func glassCard(
        cornerRadius: CGFloat = EVAiSpacing.cardRadius,
        padding: CGFloat = EVAiSpacing.cardPadding
    ) -> some View {
        modifier(GlassBackground(cornerRadius: cornerRadius, padding: padding))
    }

    func glassCapsule() -> some View {
        modifier(GlassCapsuleBackground())
    }
}

struct AmbientBackground: View {
    @Environment(\.themeColors) private var colors
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            colors.background
                .ignoresSafeArea()

            if colorScheme == .dark {
                Circle()
                    .fill(Color.primaryBlue.opacity(0.18))
                    .frame(width: 320, height: 320)
                    .blur(radius: 80)
                    .offset(x: -120, y: -280)

                Circle()
                    .fill(Color.aiPurple.opacity(0.16))
                    .frame(width: 360, height: 360)
                    .blur(radius: 90)
                    .offset(x: 140, y: 120)
            } else {
                Circle()
                    .fill(Color.primaryBlue.opacity(0.10))
                    .frame(width: 300, height: 300)
                    .blur(radius: 70)
                    .offset(x: -100, y: -260)

                Circle()
                    .fill(Color.aiPurple.opacity(0.08))
                    .frame(width: 340, height: 340)
                    .blur(radius: 80)
                    .offset(x: 120, y: 100)
            }
        }
    }
}
