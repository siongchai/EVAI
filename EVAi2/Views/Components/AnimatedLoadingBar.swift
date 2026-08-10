import SwiftUI

struct AnimatedLoadingBar: View {
    @Environment(\.colorScheme) private var colorScheme

    let progress: CGFloat
    var barWidthRatio: CGFloat = 0.75

    private let barHeight: CGFloat = 6

    var body: some View {
        GeometryReader { geometry in
            let barWidth = geometry.size.width * barWidthRatio
            let fillWidth = max(barHeight, barWidth * min(max(progress, 0), 1))

            HStack {
                Spacer()
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(trackColor)
                        .frame(width: barWidth, height: barHeight)

                    Capsule(style: .continuous)
                        .fill(progressGradient)
                        .frame(width: fillWidth, height: barHeight)
                        .shadow(
                            color: Color(hex: 0x00D4FF).opacity(colorScheme == .dark ? 0.35 : 0.22),
                            radius: 8,
                            y: 0
                        )
                }
                .frame(width: barWidth, height: barHeight)
                Spacer()
            }
        }
        .frame(height: barHeight)
        .accessibilityLabel("Loading progress")
        .accessibilityValue("\(Int(min(max(progress, 0), 1) * 100)) percent")
    }

    private var trackColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.10)
            : Color.black.opacity(0.08)
    }

    private var progressGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: 0x00D4FF),
                Color(hex: 0x007AFF),
                Color(hex: 0x8B5CF6)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

#Preview {
    AnimatedLoadingBar(progress: 0.65)
        .padding(.horizontal, 24)
        .frame(height: 6)
        .background(Color.black)
        .preferredColorScheme(.dark)
}
