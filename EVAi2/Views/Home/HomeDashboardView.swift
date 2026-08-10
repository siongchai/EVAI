import SwiftUI
import Charts
import SwiftData

struct HomeDashboardView: View {
    @Environment(\.themeColors) private var colors
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query(sort: \ChargingSession.startDate, order: .reverse) private var sessions: [ChargingSession]
    @Query private var userProfiles: [UserProfile]

    @Bindable var coordinator: AppCoordinator
    @State private var viewModel = HomeViewModel()
    @State private var showMonthPicker = false

    private var isWideLayout: Bool {
        DeviceType.isPad || horizontalSizeClass == .regular
    }

    private var sessionsFingerprint: [UUID] {
        sessions.map(\.id)
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
        .onAppear { viewModel.load(sessions: sessions) }
        .onChange(of: sessionsFingerprint) { _, _ in
            viewModel.load(sessions: sessions)
        }
    }

    private var compactLayout: some View {
        VStack(alignment: .leading, spacing: EVAiSpacing.sectionSpacing) {
            headerSection
            metricsGrid
            costTrendSection
            recentSessionsSection
            if let insight = viewModel.insight {
                InsightCard(insight: insight)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(.horizontal, EVAiSpacing.horizontalPadding)
        .padding(.bottom, EVAiSpacing.xxxl)
    }

    private var wideLayout: some View {
        VStack(alignment: .leading, spacing: EVAiSpacing.sectionSpacing) {
            headerSection

            HStack(alignment: .top, spacing: EVAiSpacing.lg) {
                VStack(alignment: .leading, spacing: EVAiSpacing.sectionSpacing) {
                    metricsGrid
                    costTrendSection
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: EVAiSpacing.sectionSpacing) {
                    recentSessionsSection
                    if let insight = viewModel.insight {
                        InsightCard(insight: insight)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, EVAiSpacing.horizontalPadding)
        .padding(.bottom, EVAiSpacing.xxxl)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: EVAiSpacing.md) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: EVAiSpacing.xxs) {
                    Text(viewModel.greeting(for: UserProfileService.displayName(from: userProfiles.first)))
                        .font(EVAiTypography.title2)
                        .foregroundStyle(colors.primaryText)

                    monthSelector
                }

                Spacer()

                Button {} label: {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(colors.primaryText)
                        .frame(width: 44, height: 44)
                        .glassCapsule()
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, EVAiSpacing.sm)
    }

    private var monthSelector: some View {
        Menu {
            ForEach(-6...0, id: \.self) { offset in
                let date = Calendar.current.date(byAdding: .month, value: offset, to: .now.startOfMonth) ?? .now
                Button(date.monthYearDisplay) {
                    viewModel.selectMonth(date)
                }
            }
        } label: {
            HStack(spacing: EVAiSpacing.xxs) {
                Text(viewModel.selectedMonth.monthYearDisplay)
                    .font(EVAiTypography.subheadline)
                    .foregroundStyle(colors.secondaryText)

                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(colors.secondaryText)
            }
        }
    }

    private var metricsGrid: some View {
        VStack(alignment: .leading, spacing: EVAiSpacing.md) {
            SectionHeader(title: "Overview")

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: EVAiSpacing.metricGridSpacing),
                    GridItem(.flexible(), spacing: EVAiSpacing.metricGridSpacing)
                ],
                spacing: EVAiSpacing.metricGridSpacing
            ) {
                MetricCard(
                    title: "Total Cost",
                    value: viewModel.metrics.totalCost.currencyFormatted,
                    iconName: "dollarsign.circle.fill",
                    iconColor: .primaryBlue
                )
                MetricCard(
                    title: "Energy Charged",
                    value: String(format: "%.0f kWh", viewModel.metrics.totalEnergy),
                    iconName: "bolt.fill",
                    iconColor: .electricCyan
                )
                MetricCard(
                    title: "Sessions",
                    value: "\(viewModel.metrics.sessionCount)",
                    iconName: "list.bullet.rectangle.fill",
                    iconColor: .aiPurple
                )
                MetricCard(
                    title: "Cost / kWh",
                    value: viewModel.metrics.averageCostPerKWh.costPerKWhFormatted,
                    iconName: "chart.bar.fill",
                    iconColor: .primaryBlue
                )
            }
        }
    }

    private var costTrendSection: some View {
        VStack(alignment: .leading, spacing: EVAiSpacing.md) {
            SectionHeader(title: "Cost Trend")

            GlassCard {
                VStack(alignment: .leading, spacing: EVAiSpacing.md) {
                    Text("Cost Over Time (SGD)")
                        .font(EVAiTypography.caption)
                        .foregroundStyle(colors.secondaryText)

                    Chart(viewModel.costTrend) { point in
                        LineMark(
                            x: .value("Day", point.day),
                            y: .value("Cost", point.cost)
                        )
                        .foregroundStyle(EVAiGradients.brand)
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))

                        AreaMark(
                            x: .value("Day", point.day),
                            y: .value("Cost", point.cost)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.primaryBlue.opacity(0.35), Color.aiPurple.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: 5)) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(colors.chartGrid)
                            AxisValueLabel {
                                if let day = value.as(Int.self) {
                                    Text("\(day)")
                                        .font(EVAiTypography.caption2)
                                        .foregroundStyle(colors.secondaryText)
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(colors.chartGrid)
                            AxisValueLabel {
                                if let cost = value.as(Double.self) {
                                    Text(String(format: "$%.0f", cost))
                                        .font(EVAiTypography.caption2)
                                        .foregroundStyle(colors.secondaryText)
                                }
                            }
                        }
                    }
                    .frame(height: 200)
                }
            }
        }
    }

    private var recentSessionsSection: some View {
        VStack(alignment: .leading, spacing: EVAiSpacing.md) {
            SectionHeader(title: "Recent Sessions", actionTitle: "See All") {
                coordinator.selectTab(.history)
            }

            if viewModel.recentSessions.isEmpty {
                Text("No sessions this month")
                    .font(EVAiTypography.subheadline)
                    .foregroundStyle(colors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard()
            } else {
                VStack(spacing: EVAiSpacing.sm) {
                    ForEach(viewModel.recentSessions, id: \.id) { session in
                        SessionCard(session: session)
                    }
                }
            }
        }
    }
}

#Preview {
    HomeDashboardView(coordinator: AppCoordinator())
        .modelContainer(for: [ChargingSession.self, Car.self, AISettings.self, UserProfile.self], inMemory: true)
        .environment(ThemeManager())
        .applyTheme(ThemeManager())
}
