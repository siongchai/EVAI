import SwiftUI

struct SessionComputedMetricsCard: View {
    @Environment(\.themeColors) private var colors

    let metrics: SessionComputedMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: EVAiSpacing.md) {
            Text("Auto-Calculated")
                .font(EVAiTypography.title3)
                .foregroundStyle(colors.primaryText)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: EVAiSpacing.sm),
                    GridItem(.flexible(), spacing: EVAiSpacing.sm)
                ],
                spacing: EVAiSpacing.sm
            ) {
                metricTile(title: "Cost / kWh", value: metrics.costPerKWh.costPerKWhFormatted)
                metricTile(title: "Charging Duration", value: metrics.sessionDurationMinutes.minutesDurationFormatted)
                metricTile(title: "SOC Delta", value: metrics.socDelta.percentFormatted)
                metricTile(
                    title: "Efficiency",
                    value: metrics.efficiencyPercent.map { String(format: "%.0f%%", $0) } ?? "—"
                )
            }
        }
        .padding(EVAiSpacing.cardPadding)
        .glassCard(padding: 0)
    }

    private func metricTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: EVAiSpacing.xxs) {
            Text(title)
                .font(EVAiTypography.caption)
                .foregroundStyle(colors.secondaryText)
            Text(value)
                .font(EVAiTypography.headline)
                .foregroundStyle(colors.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(EVAiSpacing.sm)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(colors.cardBorder.opacity(0.25))
        }
    }
}

#Preview {
    SessionComputedMetricsCard(metrics: SessionComputedMetrics(
        costPerKWh: 0.42,
        sessionDurationMinutes: 55,
        socDelta: 45,
        efficiencyPercent: 62
    ))
    .padding()
    .environment(ThemeManager())
    .applyTheme(ThemeManager())
}
