import SwiftUI

struct FloatingCaptureButton: View {
    var isSelected: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(EVAiGradients.button)
                    .frame(width: EVAiSpacing.captureButtonSize, height: EVAiSpacing.captureButtonSize)
                    .shadow(color: Color.aiPurple.opacity(0.45), radius: 14, y: 6)

                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Capture")
    }
}
