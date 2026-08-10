import SwiftUI

struct AIProcessingView: View {
    @Environment(\.themeColors) private var colors
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var viewModel: CaptureViewModel

    @State private var ringRotation: Double = 0
    @State private var pulse = false

    var body: some View {
        VStack(spacing: EVAiSpacing.sectionSpacing) {
            Spacer()

            processingGraphic

            VStack(spacing: EVAiSpacing.lg) {
                Text("Analyzing Your Session")
                    .font(EVAiTypography.title2)
                    .foregroundStyle(colors.primaryText)

                VStack(spacing: EVAiSpacing.sm) {
                    ForEach(viewModel.processingSteps) { step in
                        ProcessingStepRow(step: step)
                    }
                }
                .padding(EVAiSpacing.cardPadding)
                .glassCard()
            }

            infoCard

            Spacer()
        }
        .padding(.horizontal, EVAiSpacing.horizontalPadding)
        .onAppear {
            withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
                ringRotation = 360
            }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    private var processingGraphic: some View {
        ZStack {
            Circle()
                .stroke(colors.cardBorder, lineWidth: 6)
                .frame(width: 180, height: 180)

            Circle()
                .trim(from: 0, to: 0.72)
                .stroke(
                    EVAiGradients.brand,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .frame(width: 180, height: 180)
                .rotationEffect(.degrees(ringRotation))

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.primaryBlue.opacity(colorScheme == .dark ? 0.25 : 0.12),
                            .clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 80
                    )
                )
                .frame(width: 140, height: 140)
                .scaleEffect(pulse ? 1.06 : 0.94)

            Image(systemName: "car.side.fill")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(EVAiGradients.brand)
                .symbolRenderingMode(.hierarchical)
        }
        .padding(.bottom, EVAiSpacing.md)
    }

    private var infoCard: some View {
        HStack(alignment: .top, spacing: EVAiSpacing.md) {
            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.primaryBlue)

            Text("This usually takes 10–20 seconds. Please don't close the app.")
                .font(EVAiTypography.subheadline)
                .foregroundStyle(colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(EVAiSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: EVAiSpacing.cardRadius, style: .continuous)
                .fill(colors.insightBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: EVAiSpacing.cardRadius, style: .continuous)
                        .strokeBorder(colors.insightBorder, lineWidth: 0.5)
                }
        }
    }
}

private struct ProcessingStepRow: View {
    @Environment(\.themeColors) private var colors

    let step: ProcessingStepState

    var body: some View {
        HStack(spacing: EVAiSpacing.md) {
            statusIcon
                .frame(width: 24, height: 24)

            Text(step.id.title)
                .font(EVAiTypography.subheadline)
                .foregroundStyle(colors.primaryText)

            Spacer()

            if !step.detail.isEmpty {
                Text(step.detail)
                    .font(EVAiTypography.caption)
                    .foregroundStyle(colors.secondaryText)
            }
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch step.status {
        case .pending:
            Image(systemName: "circle")
                .foregroundStyle(colors.secondaryText)
        case .inProgress:
            ProgressView()
                .controlSize(.small)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.primaryBlue)
                .symbolRenderingMode(.hierarchical)
        }
    }
}

#Preview {
    AIProcessingView(viewModel: CaptureViewModel())
        .environment(ThemeManager())
        .applyTheme(ThemeManager())
}
