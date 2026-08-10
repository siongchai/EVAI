import SwiftUI

private struct OnboardingPage: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let systemImage: String
    let gradient: [Color]
}

struct OnboardingView: View {
    @Environment(\.themeColors) private var colors

    let onComplete: () -> Void
    let onSkip: () -> Void

    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "Track Every Charge Automatically",
            subtitle: "Capture dashboard photos and receipts — EVAi logs every session for you.",
            systemImage: "bolt.car.fill",
            gradient: [.primaryBlue, .electricCyan]
        ),
        OnboardingPage(
            title: "AI Extracts Charging Information",
            subtitle: "Our AI reads your photos to extract location, energy, cost, and SOC data instantly.",
            systemImage: "sparkles.rectangle.stack.fill",
            gradient: [.electricCyan, .aiPurple]
        ),
        OnboardingPage(
            title: "Understand Charging Costs & Trends",
            subtitle: "Visualize spending, compare networks, and discover ways to save on every charge.",
            systemImage: "chart.line.uptrend.xyaxis",
            gradient: [.primaryBlue, .aiPurple]
        )
    ]

    var body: some View {
        ZStack {
            AmbientBackground()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("Skip", action: onSkip)
                        .font(EVAiTypography.subheadline)
                        .foregroundStyle(colors.secondaryText)
                        .padding(.horizontal, EVAiSpacing.horizontalPadding)
                        .padding(.top, EVAiSpacing.md)
                }

                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                        onboardingPageView(page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.35), value: currentPage)

                pageIndicator
                    .padding(.bottom, EVAiSpacing.lg)

                GradientButton(
                    title: currentPage == pages.count - 1 ? "Get Started" : "Continue",
                    iconName: currentPage == pages.count - 1 ? "arrow.right" : nil
                ) {
                    if currentPage < pages.count - 1 {
                        withAnimation { currentPage += 1 }
                    } else {
                        onComplete()
                    }
                }
                .padding(.horizontal, EVAiSpacing.horizontalPadding)
                .padding(.bottom, EVAiSpacing.xxxl)
            }
        }
    }

    private func onboardingPageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: EVAiSpacing.xxl) {
            Spacer()

            Image("EVAiLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 120)
                .padding(.bottom, EVAiSpacing.sm)

            ZStack {
                RoundedRectangle(cornerRadius: EVAiSpacing.cardRadius, style: .continuous)
                    .fill(
                        LinearGradient(colors: page.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                            .opacity(0.15)
                    )
                    .frame(width: 280, height: 280)

                Image(systemName: page.systemImage)
                    .font(.system(size: 72, weight: .light))
                    .foregroundStyle(
                        LinearGradient(colors: page.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .symbolRenderingMode(.hierarchical)
            }

            VStack(spacing: EVAiSpacing.md) {
                Text(page.title)
                    .font(EVAiTypography.title2)
                    .foregroundStyle(colors.primaryText)
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(EVAiTypography.body)
                    .foregroundStyle(colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, EVAiSpacing.xxl)
            }

            Spacer()
            Spacer()
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: EVAiSpacing.xs) {
            ForEach(0..<pages.count, id: \.self) { index in
                Group {
                    if index == currentPage {
                        Capsule()
                            .fill(EVAiGradients.button)
                    } else {
                        Capsule()
                            .fill(colors.secondaryText.opacity(0.3))
                    }
                }
                .frame(width: index == currentPage ? 24 : 8, height: 8)
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: currentPage)
            }
        }
    }
}

#Preview {
    OnboardingView(onComplete: {}, onSkip: {})
        .environment(\.themeColors, ThemeColors.palette(for: .dark))
}
