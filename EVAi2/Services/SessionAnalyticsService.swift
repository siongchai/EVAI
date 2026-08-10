import Foundation
import SwiftData

struct DailyCostPoint: Identifiable, Hashable {
    let id = UUID()
    let day: Int
    let date: Date
    let cost: Double
}

struct MonthlyMetrics: Hashable {
    let totalCost: Double
    let totalEnergy: Double
    let sessionCount: Int
    let averageCostPerKWh: Double
}

struct AIInsight: Hashable {
    let message: String
    let iconName: String
}

enum SessionAnalyticsService {
    static func monthlyMetrics(from sessions: [ChargingSession], month: Date) -> MonthlyMetrics {
        let filtered = sessions.filter { $0.startDate.isSameMonth(as: month) }
        let totalCost = filtered.reduce(0) { $0 + $1.amountSGD }
        let totalEnergy = filtered.reduce(0) { $0 + $1.energyKWh }
        let count = filtered.count
        let average = totalEnergy > 0 ? totalCost / totalEnergy : 0

        return MonthlyMetrics(
            totalCost: totalCost,
            totalEnergy: totalEnergy,
            sessionCount: count,
            averageCostPerKWh: average
        )
    }

    static func dailyCostPoints(from sessions: [ChargingSession], month: Date) -> [DailyCostPoint] {
        let calendar = Calendar.current
        let filtered = sessions.filter { $0.startDate.isSameMonth(as: month) }
        let grouped = Dictionary(grouping: filtered) { session in
            calendar.component(.day, from: session.startDate)
        }

        let range = calendar.range(of: .day, in: .month, for: month) ?? 1..<31
        return range.map { day in
            let daySessions = grouped[day] ?? []
            let cost = daySessions.reduce(0) { $0 + $1.amountSGD }
            let date = calendar.date(bySetting: .day, value: day, of: month.startOfMonth) ?? month
            return DailyCostPoint(day: day, date: date, cost: cost)
        }
    }

    static func recentSessions(from sessions: [ChargingSession], limit: Int = 3) -> [ChargingSession] {
        Array(
            sessions
                .sorted { $0.startDate > $1.startDate }
                .prefix(limit)
        )
    }

    static func generateInsight(from sessions: [ChargingSession], month: Date) -> AIInsight? {
        let filtered = sessions.filter { $0.startDate.isSameMonth(as: month) }
        guard !filtered.isEmpty else { return nil }

        let calendar = Calendar.current
        let lateNight = filtered.filter { session in
            let hour = calendar.component(.hour, from: session.startDate)
            return hour >= 22
        }
        let regular = filtered.filter { session in
            let hour = calendar.component(.hour, from: session.startDate)
            return hour < 22
        }

        let lateAvg = averageCostPerKWh(for: lateNight)
        let regularAvg = averageCostPerKWh(for: regular)

        if lateAvg > 0, regularAvg > 0, lateAvg < regularAvg {
            let savings = ((regularAvg - lateAvg) / regularAvg) * 100
            let rounded = Int(savings.rounded())
            if rounded > 0 {
                return AIInsight(
                    message: "You saved \(rounded)% by charging after 10PM this month.",
                    iconName: "sparkles"
                )
            }
        }

        let totalCost = filtered.reduce(0) { $0 + $1.amountSGD }
        let totalEnergy = filtered.reduce(0) { $0 + $1.energyKWh }
        if totalEnergy > 0 {
            return AIInsight(
                message: "Your average cost is \(String(format: "%@%.2f", AppConstants.currencySymbol, totalCost / totalEnergy)) per kWh across \(filtered.count) sessions.",
                iconName: "lightbulb.fill"
            )
        }

        return nil
    }

    private static func averageCostPerKWh(for sessions: [ChargingSession]) -> Double {
        let energy = sessions.reduce(0) { $0 + $1.energyKWh }
        let cost = sessions.reduce(0) { $0 + $1.amountSGD }
        guard energy > 0 else { return 0 }
        return cost / energy
    }
}
