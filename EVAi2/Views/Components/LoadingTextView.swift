import SwiftUI

struct LoadingTextView: View {
    @Environment(\.colorScheme) private var colorScheme

    let opacity: Double

    var body: some View {
        Text("Loading...")
            .font(.system(size: 16, weight: .medium, design: .default))
            .foregroundStyle(textColor)
            .opacity(opacity)
            .accessibilityLabel("Loading")
    }

    private var textColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.75)
            : Color.black.opacity(0.55)
    }
}

#Preview {
    LoadingTextView(opacity: 0.8)
        .preferredColorScheme(.dark)
}
