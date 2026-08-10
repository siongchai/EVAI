import SwiftUI
import Charts
import SwiftData

struct AnalyticsView: View {
    @Environment(\.themeColors) private var colors
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query(sort: \ChargingSession.startDate, order: .reverse) private var sessions: [ChargingSession]
    @Query(sort: \Car.createdAt, order: .reverse) private var cars: [Car]

    @State private var viewModel = AnalyticsViewModel()

    private var isWideLayout: Bool {
        DeviceType.isPad || horizontalSizeClass == .regular
    }

    private var sessionsFingerprint: [UUID] { sessions.map(\.id) }
    private var primaryBattery: Double? {
        cars.first(where: \.isPrimary)?.batterySizeKWh
    }

    var body: some View {
        ScrollView {
            if isWideLayout {
                wideLayout
            } else {
                compactLayout
            }
        }
        .scrollIndicators(.hidden)
        .onAppear { viewModel.load(sessions: sessions, primaryBatterySizeKWh: primaryBattery) }
        .onChange(of: sessionsFingerprint) { _, _ in
            viewModel.load(sessions: sessions, primaryBatterySizeKWh: primaryBattery)
        }
    }

    private var compactLayout: some View {
        VStack(alignment: .leading, spacing: EVAiSpacing.sectionSpacing) {
            headerSection
            forecastCards
            metricsGrid
            insightsSection
            monthlyCostChart
            quarterlyChart
            energyUsageChart
            networkComparisonChart
            costComparisonChart
            hourlyAnalysisChart
            heatmapSection
            socIncreaseChart
            batteryUsageChart
            ninetyDayTrendChart
            networkBreakdownSection
            monthlyTrendsSection
        }
        .padding(.horizontal, EVAiSpacing.horizontalPadding)
        .padding(.bottom, EVAiSpacing.tabBarHeight)
    }

    private var wideLayout: some View {
        VStack(alignment: .leading, spacing: EVAiSpacing.sectionSpacing) {
            headerSection
            forecastCards
            metricsGrid
            insightsSection

            HStack(alignment: .top, spacing: EVAiSpacing.lg) {
                VStack(alignment: .leading, spacing: EVAiSpacing.sectionSpacing) {
                    monthlyCostChart
                    quarterlyChart
                    ninetyDayTrendChart
                    monthlyTrendsSection
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: EVAiSpacing.sectionSpacing) {
                    energyUsageChart
                    networkComparisonChart
                    hourlyAnalysisChart
                    socIncreaseChart
                    batteryUsageChart
                }
                .frame(maxWidth: .infinity)
            }

            heatmapSection
            costComparisonChart
            networkBreakdownSection
        }
        .padding(.horizontal, EVAiSpacing.horizontalPadding)
        .padding(.bottom, EVAiSpacing.xxxl)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: EVAiSpacing.sm) {
            Text("Analytics")
                .font(EVAiTypography.title2)
                .foregroundStyle(colors.primaryText)

            HStack {
                Button { viewModel.shiftMonth(by: -1) } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)

                Text(viewModel.selectedMonth.monthYearDisplay)
                    .font(EVAiTypography.headline)
                    .foregroundStyle(colors.primaryText)
                    .frame(maxWidth: .infinity)

                Button { viewModel.shiftMonth(by: 1) } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.plain)
                .disabled(viewModel.selectedMonth.isSameMonth(as: .now))
            }
            .foregroundStyle(colors.secondaryText)
        }
        .padding(.top, EVAiSpacing.sm)
    }

    private var forecastCards: some View {
        HStack(spacing: EVAiSpacing.sm) {
            forecastCard(
                title: "Forecast Cost",
                value: viewModel.smartSnapshot.monthlyForecast.projectedMonthlyCost.currencyFormatted,
                subtitle: viewModel.smartSnapshot.monthlyForecast.trendDirection.label
            )
            forecastCard(
                title: "Forecast Energy",
                value: String(format: "%.0f kWh", viewModel.smartSnapshot.monthlyForecast.projectedMonthlyEnergy),
                subtitle: "\(viewModel.smartSnapshot.monthlyForecast.projectedSessionCount) sessions"
            )
        }
    }

    private func forecastCard(title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: EVAiSpacing.xxs) {
            Text(title)
                .font(EVAiTypography.caption)
                .foregroundStyle(colors.secondaryText)
            Text(value)
                .font(EVAiTypography.headline)
                .foregroundStyle(colors.primaryText)
            Text(subtitle)
                .font(EVAiTypography.caption2)
                .foregroundStyle(Color.primaryBlue)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(padding: EVAiSpacing.sm)
    }

    private var metricsGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: EVAiSpacing.metricGridSpacing),
                GridItem(.flexible(), spacing: EVAiSpacing.metricGridSpacing)
            ],
            spacing: EVAiSpacing.metricGridSpacing
        ) {
            MetricCard(title: "Avg Cost / kWh", value: viewModel.averageCostPerKWh.costPerKWhFormatted, iconName: "chart.line.uptrend.xyaxis", iconColor: .primaryBlue)
            MetricCard(title: "Total Sessions", value: "\(viewModel.totalSessions)", iconName: "list.bullet.rectangle.fill", iconColor: .aiPurple)
            MetricCard(title: "Avg SOC Gain", value: viewModel.averageSOCIncrease.percentFormatted, iconName: "battery.100.bolt", iconColor: .electricCyan)
            MetricCard(title: "Top Network", value: viewModel.mostUsedNetwork?.network ?? "—", iconName: "ev.charger.fill", iconColor: .primaryBlue)
        }
    }

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: EVAiSpacing.md) {
            SectionHeader(title: "AI Insights")
            if viewModel.insights.isEmpty {
                Text("Add more sessions to unlock insights.")
                    .font(EVAiTypography.subheadline)
                    .foregroundStyle(colors.secondaryText)
                    .glassCard()
            } else {
                VStack(spacing: EVAiSpacing.sm) {
                    ForEach(Array(viewModel.insights.enumerated()), id: \.offset) { _, insight in
                        InsightCard(insight: insight)
                    }
                }
            }
        }
    }

    private var monthlyCostChart: some View {
        chartSection(title: "Monthly Cost") {
            Chart(viewModel.monthlyCostTrend) { point in
                BarMark(x: .value("Day", point.day), y: .value("Cost", point.cost))
                    .foregroundStyle(Color.primaryBlue.gradient)
                    .cornerRadius(4)
            }
            .frame(height: 200)
        }
    }

    private var quarterlyChart: some View {
        chartSection(title: "Quarterly Trends") {
            Chart(viewModel.quarterlyTrends) { point in
                BarMark(x: .value("Quarter", point.label), y: .value("Cost", point.totalCost))
                    .foregroundStyle(Color.aiPurple.gradient)
            }
            .frame(height: 180)
        }
    }

    private var energyUsageChart: some View {
        chartSection(title: "Energy Usage") {
            Chart(viewModel.dailyEnergyTrend) { point in
                LineMark(x: .value("Day", point.day), y: .value("Energy", point.energy))
                    .foregroundStyle(Color.electricCyan)
                    .interpolationMethod(.catmullRom)
                AreaMark(x: .value("Day", point.day), y: .value("Energy", point.energy))
                    .foregroundStyle(Color.electricCyan.opacity(0.18))
                    .interpolationMethod(.catmullRom)
            }
            .frame(height: 200)
        }
    }

    private var networkComparisonChart: some View {
        chartSection(title: "Network Comparison") {
            Chart(viewModel.networkComparison) { item in
                BarMark(x: .value("Network", item.network), y: .value("Avg $/kWh", item.averageCostPerKWh))
                    .foregroundStyle(Color.primaryBlue.gradient)
            }
            .frame(height: 200)
        }
    }

    private var costComparisonChart: some View {
        chartSection(title: "Cost Comparison by Network") {
            Chart(viewModel.networkBreakdown) { item in
                BarMark(x: .value("Network", item.network), y: .value("Cost", item.totalCost))
                    .foregroundStyle(EVAiGradients.brand)
            }
            .frame(height: 200)
        }
    }

    private var hourlyAnalysisChart: some View {
        chartSection(title: "Charging Hour Analysis") {
            Chart(viewModel.hourlyCostAnalysis) { item in
                LineMark(x: .value("Hour", item.hour), y: .value("Avg $/kWh", item.averageCostPerKWh))
                    .foregroundStyle(Color.primaryBlue)
                PointMark(x: .value("Hour", item.hour), y: .value("Avg $/kWh", item.averageCostPerKWh))
                    .foregroundStyle(Color.aiPurple)
            }
            .frame(height: 180)
        }
    }

    private var heatmapSection: some View {
        chartSection(title: "Session Frequency Heatmap") {
            let maxCount = max(1, viewModel.heatmapCells.map(\.sessionCount).max() ?? 1)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 24), spacing: 2) {
                ForEach(viewModel.heatmapCells.filter { $0.weekday == 2 }) { cell in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.primaryBlue.opacity(Double(cell.sessionCount) / Double(maxCount)))
                        .frame(height: 14)
                }
            }
            Text("Monday hourly frequency (darker = more sessions)")
                .font(EVAiTypography.caption2)
                .foregroundStyle(colors.secondaryText)
        }
    }

    private var socIncreaseChart: some View {
        chartSection(title: "Average SOC Increase") {
            Chart(viewModel.socTrend) { point in
                BarMark(x: .value("Day", point.date, unit: .day), y: .value("SOC", point.averageIncrease))
                    .foregroundStyle(Color.electricCyan.gradient)
            }
            .frame(height: 180)
        }
    }

    private var batteryUsageChart: some View {
        chartSection(title: "Battery Usage Trend") {
            Chart(viewModel.batteryUsageTrend) { point in
                LineMark(x: .value("Date", point.date, unit: .day), y: .value("Energy", point.energyKWh))
                    .foregroundStyle(Color.aiPurple)
            }
            .frame(height: 180)
        }
    }

    private var ninetyDayTrendChart: some View {
        chartSection(title: "90-Day Charging Trend") {
            Chart(viewModel.ninetyDayTrend) { point in
                LineMark(x: .value("Date", point.date, unit: .day), y: .value("Cost", point.totalCost))
                    .foregroundStyle(EVAiGradients.brand)
                    .interpolationMethod(.catmullRom)
            }
            .frame(height: 180)
        }
    }

    private var networkBreakdownSection: some View {
        VStack(alignment: .leading, spacing: EVAiSpacing.md) {
            SectionHeader(title: "Network Breakdown")
            if viewModel.networkBreakdown.isEmpty {
                Text("No network data for this month")
                    .font(EVAiTypography.subheadline)
                    .foregroundStyle(colors.secondaryText)
                    .glassCard()
            } else {
                VStack(spacing: EVAiSpacing.sm) {
                    ForEach(viewModel.networkBreakdown) { item in
                        HStack {
                            NetworkBadge(network: item.network, initials: networkInitials(for: item.network))
                            VStack(alignment: .leading, spacing: EVAiSpacing.xxs) {
                                Text(item.network).font(EVAiTypography.headline).foregroundStyle(colors.primaryText)
                                Text("\(item.sessionCount) sessions · \(item.averageCostPerKWh.costPerKWhFormatted)/kWh")
                                    .font(EVAiTypography.caption).foregroundStyle(colors.secondaryText)
                            }
                            Spacer()
                            Text(item.totalCost.currencyFormatted).font(EVAiTypography.subheadline).foregroundStyle(colors.primaryText)
                        }
                        .padding(EVAiSpacing.md)
                        .glassCard(padding: 0)
                    }
                }
            }
        }
    }

    private var monthlyTrendsSection: some View {
        chartSection(title: "Monthly Trends") {
            Chart(viewModel.monthlyTrends) { point in
                LineMark(x: .value("Month", point.month, unit: .month), y: .value("Cost", point.totalCost))
                    .foregroundStyle(EVAiGradients.brand)
                PointMark(x: .value("Month", point.month, unit: .month), y: .value("Cost", point.totalCost))
                    .foregroundStyle(Color.primaryBlue)
            }
            .frame(height: 200)
        }
    }

    private func chartSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: EVAiSpacing.md) {
            SectionHeader(title: title)
            content()
                .glassCard()
        }
    }

    private func networkInitials(for network: String) -> String {
        network.split(separator: " ").prefix(2).compactMap { $0.first.map(String.init) }.joined().uppercased()
    }
}

#Preview {
    NavigationStack { AnalyticsView() }
        .modelContainer(for: [ChargingSession.self, Car.self], inMemory: true)
        .environment(ThemeManager())
        .applyTheme(ThemeManager())
}
