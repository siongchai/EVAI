import SwiftUI

struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = EVAiSpacing.cardRadius
    var padding: CGFloat = EVAiSpacing.cardPadding
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .glassCard(cornerRadius: cornerRadius, padding: padding)
    }
}
