import SwiftUI

struct InsightCard: View {
    @Environment(\.themeColors) private var colors

    let insight: AIInsight

    var body: some View {
        HStack(alignment: .top, spacing: EVAiSpacing.md) {
            Image(systemName: insight.iconName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.primaryBlue)
                .frame(width: 40, height: 40)
                .background(colors.insightBackground, in: Circle())

            VStack(alignment: .leading, spacing: EVAiSpacing.xxs) {
                Text("AI Insight")
                    .font(EVAiTypography.caption)
                    .foregroundStyle(Color.primaryBlue)

                Text(insight.message)
                    .font(EVAiTypography.subheadline)
                    .foregroundStyle(colors.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(EVAiSpacing.cardPadding)
        .background {
            RoundedRectangle(cornerRadius: EVAiSpacing.cardRadius, style: .continuous)
                .fill(colors.insightBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: EVAiSpacing.cardRadius, style: .continuous)
                        .strokeBorder(colors.insightBorder, lineWidth: 1)
                }
        }
    }
}
