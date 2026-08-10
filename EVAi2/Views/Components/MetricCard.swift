import SwiftUI

struct MetricCard: View {
    @Environment(\.themeColors) private var colors

    let title: String
    let value: String
    let iconName: String
    var iconColor: Color = .primaryBlue

    var body: some View {
        VStack(alignment: .leading, spacing: EVAiSpacing.sm) {
            HStack {
                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 28, height: 28)
                    .background(iconColor.opacity(0.15), in: Circle())

                Spacer(minLength: 0)
            }

            Text(value)
                .font(EVAiTypography.metricValue)
                .foregroundStyle(colors.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(title)
                .font(EVAiTypography.metricLabel)
                .foregroundStyle(colors.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(padding: EVAiSpacing.md)
    }
}
