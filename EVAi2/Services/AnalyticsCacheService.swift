import Foundation

struct AnalyticsCacheSummary: Codable {
    var sessionCount: Int
    var selectedMonth: Date
    var totalCost: Double
    var totalEnergy: Double
    var sessionCountForMonth: Int
    var averageCostPerKWh: Double
    var insightMessages: [String]
    var updatedAt: Date
}

enum AnalyticsCacheService {
    private static let cacheKey = "evai.analytics.cache.summary"

    static func save(_ summary: AnalyticsCacheSummary) {
        guard let data = try? JSONEncoder().encode(summary) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey)
    }

    static func load(expectedSessionCount: Int) -> AnalyticsCacheSummary? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let summary = try? JSONDecoder().decode(AnalyticsCacheSummary.self, from: data),
              summary.sessionCount == expectedSessionCount else {
            return nil
        }
        return summary
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
    }

    static func rebuildSummary(
        from sessions: [ChargingSession],
        month: Date
    ) -> AnalyticsCacheSummary {
        let metrics = AnalyticsEngine.monthlyMetrics(from: sessions, month: month)
        let insights = InsightEngine.generateInsights(from: sessions, month: month).map(\.message)
        return AnalyticsCacheSummary(
            sessionCount: sessions.count,
            selectedMonth: month,
            totalCost: metrics.totalCost,
            totalEnergy: metrics.totalEnergy,
            sessionCountForMonth: metrics.sessionCount,
            averageCostPerKWh: metrics.averageCostPerKWh,
            insightMessages: insights,
            updatedAt: .now
        )
    }
}
