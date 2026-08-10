import Foundation

enum InsightEngine {
    static func generateInsights(
        from sessions: [ChargingSession],
        month: Date = .now.startOfMonth
    ) -> [AIInsight] {
        var insights: [AIInsight] = []
        let snapshot = SmartAnalyticsEngine.buildSnapshot(from: sessions, referenceMonth: month)

        if let spendInsight = monthOverMonthSpendInsight(sessions: sessions, month: month) {
            insights.append(spendInsight)
        }

        if let lateNight = lateNightSavingsInsight(habits: snapshot.chargingHabits) {
            insights.append(lateNight)
        }

        if let network = cheapestNetworkInsight(snapshot: snapshot) {
            insights.append(network)
        }

        if let trend = averageSessionCostTrendInsight(sessions: sessions) {
            insights.append(trend)
        }

        if let forecast = forecastInsight(forecast: snapshot.monthlyForecast) {
            insights.append(forecast)
        }

        if let station = expensiveStationInsight(station: snapshot.mostExpensiveStation) {
            insights.append(station)
        }

        if let hour = cheapestHourInsight(hour: snapshot.cheapestHour) {
            insights.append(hour)
        }

        if insights.isEmpty, let fallback = AnalyticsEngine.generateAIInsights(from: sessions, month: month) {
            insights.append(fallback)
        }

        return insights
    }

    private static func monthOverMonthSpendInsight(sessions: [ChargingSession], month: Date) -> AIInsight? {
        let calendar = Calendar.current
        guard let previousMonth = calendar.date(byAdding: .month, value: -1, to: month.startOfMonth) else {
            return nil
        }

        let current = AnalyticsEngine.calculateMonthlyCost(from: sessions, month: month)
        let previous = AnalyticsEngine.calculateMonthlyCost(from: sessions, month: previousMonth)
        guard previous > 0, current > 0 else { return nil }

        let change = ((current - previous) / previous) * 100
        let rounded = Int(abs(change).rounded())

        if abs(change) < 3 {
            return AIInsight(
                message: "Your spending is stable compared to last month.",
                iconName: "chart.line.flattrend.xyaxis"
            )
        }

        if change > 0 {
            return AIInsight(
                message: "You spent \(rounded)% more this month than last month.",
                iconName: "arrow.up.right.circle.fill"
            )
        }

        return AIInsight(
            message: "You spent \(rounded)% less this month — nice work.",
            iconName: "arrow.down.right.circle.fill"
        )
    }

    private static func lateNightSavingsInsight(habits: ChargingHabitSummary) -> AIInsight? {
        guard let savings = habits.lateNightSavingsPercent, savings >= 5 else { return nil }
        return AIInsight(
            message: "You save more charging after 10 PM — about \(Int(savings.rounded()))% cheaper per kWh.",
            iconName: "moon.stars.fill"
        )
    }

    private static func cheapestNetworkInsight(snapshot: SmartAnalyticsSnapshot) -> AIInsight? {
        guard let best = snapshot.bestNetwork else { return nil }
        return AIInsight(
            message: "\(best.network) is your cheapest provider at \(best.averageCostPerKWh.costPerKWhFormatted) per kWh.",
            iconName: "ev.charger.fill"
        )
    }

    private static func averageSessionCostTrendInsight(sessions: [ChargingSession]) -> AIInsight? {
        let sorted = sessions.sorted { $0.startDate < $1.startDate }
        guard sorted.count >= 6 else { return nil }

        let midpoint = sorted.count / 2
        let firstHalf = Array(sorted.prefix(midpoint))
        let secondHalf = Array(sorted.suffix(sorted.count - midpoint))

        let firstAvg = averageSessionCost(firstHalf)
        let secondAvg = averageSessionCost(secondHalf)
        guard firstAvg > 0, secondAvg > 0 else { return nil }

        let change = ((secondAvg - firstAvg) / firstAvg) * 100
        if abs(change) < 5 {
            return AIInsight(
                message: "Your average session cost has remained steady recently.",
                iconName: "chart.bar.fill"
            )
        }

        if change > 0 {
            return AIInsight(
                message: "Average session cost is increasing — up \(Int(change.rounded()))% in recent sessions.",
                iconName: "exclamationmark.triangle.fill"
            )
        }

        return AIInsight(
            message: "Average session cost is trending down by \(Int(abs(change).rounded()))%.",
            iconName: "chart.line.downtrend.xyaxis"
        )
    }

    private static func forecastInsight(forecast: ChargingForecast) -> AIInsight? {
        guard forecast.projectedMonthlyCost > 0 else { return nil }
        return AIInsight(
            message: "Forecast: \(forecast.projectedMonthlyCost.currencyFormatted) this month (\(forecast.trendDirection.label)).",
            iconName: "sparkles"
        )
    }

    private static func expensiveStationInsight(station: StationCostSummary?) -> AIInsight? {
        guard let station else { return nil }
        return AIInsight(
            message: "Most expensive station: \(station.location) at \(station.averageCostPerKWh.costPerKWhFormatted)/kWh.",
            iconName: "mappin.and.ellipse"
        )
    }

    private static func cheapestHourInsight(hour: HourlyCostSummary?) -> AIInsight? {
        guard let hour, hour.sessionCount >= 2 else { return nil }
        return AIInsight(
            message: "Cheapest charging hour: \(hour.hourLabel) at \(hour.averageCostPerKWh.costPerKWhFormatted)/kWh.",
            iconName: "clock.fill"
        )
    }

    private static func averageSessionCost(_ sessions: [ChargingSession]) -> Double {
        guard !sessions.isEmpty else { return 0 }
        return sessions.reduce(0) { $0 + $1.amountSGD } / Double(sessions.count)
    }
}
