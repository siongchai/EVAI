import SwiftUI

struct SplashView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let onComplete: () -> Void

    @State private var progress: CGFloat = 0
    @State private var loadingTextOpacity: Double = 0.4
    @State private var screenOpacity: Double = 1

    private var isPad: Bool {
        horizontalSizeClass == .regular
    }

    private var barWidthRatio: CGFloat {
        isPad ? 0.60 : 0.75
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Image(ThemeAssetManager.splashBackgroundName(for: colorScheme))
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .ignoresSafeArea()

                VStack(spacing: 18) {
                    AnimatedLoadingBar(progress: progress, barWidthRatio: barWidthRatio)
                        .padding(.horizontal, isPad ? 48 : 0)

                    LoadingTextView(opacity: loadingTextOpacity)
                }
                .frame(width: geometry.size.width)
                .position(
                    x: geometry.size.width * 0.5,
                    y: geometry.size.height * 0.85
                )
            }
        }
        .opacity(screenOpacity)
        .ignoresSafeArea()
        .onAppear {
            startLoadingSequence()
        }
    }

    private func startLoadingSequence() {
        if AccessibilitySupport.isReduceMotionEnabled {
            progress = 1
            loadingTextOpacity = 1
            Task {
                try? await Task.sleep(for: .seconds(3.2))
                await finishSplash()
            }
            return
        }

        withAnimation(.linear(duration: 2.8)) {
            progress = 1
        }

        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            loadingTextOpacity = 1.0
        }

        Task {
            try? await Task.sleep(for: .seconds(2.8))
            try? await Task.sleep(for: .seconds(0.4))
            await finishSplash()
        }
    }

    @MainActor
    private func finishSplash() {
        withAnimation(.easeOut(duration: 0.5)) {
            screenOpacity = 0
        }
        Task {
            try? await Task.sleep(for: .seconds(0.5))
            onComplete()
        }
    }
}

#Preview("Dark") {
    SplashView(onComplete: {})
        .preferredColorScheme(.dark)
}

#Preview("Light") {
    SplashView(onComplete: {})
        .preferredColorScheme(.light)
}
