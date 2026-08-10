import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class AnalyticsViewModel {
    private(set) var selectedMonth: Date = .now.startOfMonth
    private(set) var metrics = MonthlyMetrics(totalCost: 0, totalEnergy: 0, sessionCount: 0, averageCostPerKWh: 0)
    private(set) var monthlyCostTrend: [DailyCostPoint] = []
    private(set) var dailyEnergyTrend: [DailyEnergyPoint] = []
    private(set) var networkBreakdown: [NetworkBreakdownItem] = []
    private(set) var monthlyTrends: [MonthlyTrendPoint] = []
    private(set) var quarterlyTrends: [QuarterlyTrendPoint] = []
    private(set) var ninetyDayTrend: [DailyTrendPoint] = []
    private(set) var networkComparison: [NetworkComparisonItem] = []
    private(set) var hourlyCostAnalysis: [HourlyCostSummary] = []
    private(set) var heatmapCells: [HeatmapCell] = []
    private(set) var socTrend: [SOCTrendPoint] = []
    private(set) var batteryUsageTrend: [BatteryUsagePoint] = []
    private(set) var smartSnapshot = SmartAnalyticsEngine.buildSnapshot(from: [])
    private(set) var insights: [AIInsight] = []
    private(set) var averageCostPerKWh: Double = 0
    private(set) var averageSOCIncrease: Double = 0
    private(set) var mostUsedNetwork: (network: String, count: Int)?
    private(set) var totalSessions: Int = 0
    private(set) var isRefreshing = false

    private var allSessions: [ChargingSession] = []
    private var primaryBatterySizeKWh: Double?
    private var refreshTask: Task<Void, Never>?

    func load(sessions: [ChargingSession], primaryBatterySizeKWh: Double? = nil) {
        allSessions = sessions
        self.primaryBatterySizeKWh = primaryBatterySizeKWh

        if let cache = AnalyticsCacheService.load(expectedSessionCount: sessions.count) {
            metrics = MonthlyMetrics(
                totalCost: cache.totalCost,
                totalEnergy: cache.totalEnergy,
                sessionCount: cache.sessionCountForMonth,
                averageCostPerKWh: cache.averageCostPerKWh
            )
            insights = cache.insightMessages.map { AIInsight(message: $0, iconName: "sparkles") }
        }

        refreshTask?.cancel()
        refreshTask = Task {
            await refreshAsync()
        }
    }

    func selectMonth(_ month: Date) {
        selectedMonth = month.startOfMonth
        refreshTask?.cancel()
        refreshTask = Task { await refreshAsync() }
    }

    func shiftMonth(by offset: Int) {
        guard let newMonth = Calendar.current.date(byAdding: .month, value: offset, to: selectedMonth) else {
            return
        }
        selectedMonth = newMonth.startOfMonth
        refreshTask?.cancel()
        refreshTask = Task { await refreshAsync() }
    }

    private func refreshAsync() async {
        isRefreshing = true
        let sessions = allSessions
        let month = selectedMonth
        let battery = primaryBatterySizeKWh

        let computed = await Task.detached(priority: .utility) {
            AnalyticsComputationResult.build(from: sessions, month: month, batterySizeKWh: battery)
        }.value

        guard !Task.isCancelled else {
            isRefreshing = false
            return
        }

        metrics = computed.metrics
        monthlyCostTrend = computed.monthlyCostTrend
        dailyEnergyTrend = computed.dailyEnergyTrend
        networkBreakdown = computed.networkBreakdown
        monthlyTrends = computed.monthlyTrends
        quarterlyTrends = computed.quarterlyTrends
        ninetyDayTrend = computed.ninetyDayTrend
        networkComparison = computed.networkComparison
        hourlyCostAnalysis = computed.hourlyCostAnalysis
        heatmapCells = computed.heatmapCells
        socTrend = computed.socTrend
        batteryUsageTrend = computed.batteryUsageTrend
        smartSnapshot = computed.smartSnapshot
        insights = computed.insights
        averageCostPerKWh = computed.averageCostPerKWh
        averageSOCIncrease = computed.averageSOCIncrease
        mostUsedNetwork = computed.mostUsedNetwork
        totalSessions = computed.totalSessions

        AnalyticsCacheService.save(
            AnalyticsCacheService.rebuildSummary(from: sessions, month: month)
        )
        WidgetDataStore.sync(from: sessions)
        isRefreshing = false
    }
}

private struct AnalyticsComputationResult {
    let metrics: MonthlyMetrics
    let monthlyCostTrend: [DailyCostPoint]
    let dailyEnergyTrend: [DailyEnergyPoint]
    let networkBreakdown: [NetworkBreakdownItem]
    let monthlyTrends: [MonthlyTrendPoint]
    let quarterlyTrends: [QuarterlyTrendPoint]
    let ninetyDayTrend: [DailyTrendPoint]
    let networkComparison: [NetworkComparisonItem]
    let hourlyCostAnalysis: [HourlyCostSummary]
    let heatmapCells: [HeatmapCell]
    let socTrend: [SOCTrendPoint]
    let batteryUsageTrend: [BatteryUsagePoint]
    let smartSnapshot: SmartAnalyticsSnapshot
    let insights: [AIInsight]
    let averageCostPerKWh: Double
    let averageSOCIncrease: Double
    let mostUsedNetwork: (network: String, count: Int)?
    let totalSessions: Int

    static func build(
        from sessions: [ChargingSession],
        month: Date,
        batterySizeKWh: Double?
    ) -> AnalyticsComputationResult {
        let monthSessions = sessions.filter { $0.startDate.isSameMonth(as: month) }
        return AnalyticsComputationResult(
            metrics: AnalyticsEngine.monthlyMetrics(from: sessions, month: month),
            monthlyCostTrend: AnalyticsEngine.dailyCostPoints(from: sessions, month: month),
            dailyEnergyTrend: AnalyticsEngine.dailyEnergyPoints(from: sessions, month: month),
            networkBreakdown: AnalyticsEngine.networkBreakdown(from: sessions, month: month),
            monthlyTrends: AnalyticsEngine.monthlyTrendPoints(from: sessions, monthCount: 6),
            quarterlyTrends: SmartAnalyticsEngine.quarterlyTrendPoints(from: sessions),
            ninetyDayTrend: SmartAnalyticsEngine.chargingTrendOver90Days(from: sessions),
            networkComparison: SmartAnalyticsEngine.averageCostPerKWhByNetwork(from: monthSessions),
            hourlyCostAnalysis: SmartAnalyticsEngine.hourlyCostAnalysis(from: monthSessions),
            heatmapCells: SmartAnalyticsEngine.sessionFrequencyHeatmap(from: sessions),
            socTrend: SmartAnalyticsEngine.socIncreaseTrend(from: sessions, month: month),
            batteryUsageTrend: SmartAnalyticsEngine.batteryUsageTrend(from: monthSessions, batterySizeKWh: batterySizeKWh),
            smartSnapshot: SmartAnalyticsEngine.buildSnapshot(from: sessions, referenceMonth: month),
            insights: InsightEngine.generateInsights(from: sessions, month: month),
            averageCostPerKWh: AnalyticsEngine.calculateAverageCostPerKWh(from: sessions, month: month),
            averageSOCIncrease: AnalyticsEngine.calculateAverageSOCIncrease(from: monthSessions),
            mostUsedNetwork: AnalyticsEngine.calculateMostUsedChargingNetwork(from: monthSessions),
            totalSessions: AnalyticsEngine.calculateTotalSessions(from: sessions, month: month)
        )
    }
}
