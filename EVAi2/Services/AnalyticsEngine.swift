import Foundation
import SwiftData

struct NetworkBreakdownItem: Identifiable, Hashable {
    let network: String
    let sessionCount: Int
    let totalCost: Double
    let totalEnergy: Double

    var id: String { network }

    var averageCostPerKWh: Double {
        guard totalEnergy > 0 else { return 0 }
        return totalCost / totalEnergy
    }
}

struct MonthlyTrendPoint: Identifiable, Hashable {
    let month: Date
    let totalCost: Double
    let totalEnergy: Double
    let sessionCount: Int

    var id: Date { month }
}

struct DailyEnergyPoint: Identifiable, Hashable {
    let day: Int
    let date: Date
    let energy: Double

    var id: Int { day }
}

enum AnalyticsEngine {
    static func calculateMonthlyCost(from sessions: [ChargingSession], month: Date) -> Double {
        sessions
            .filter { $0.startDate.isSameMonth(as: month) }
            .reduce(0) { $0 + $1.amountSGD }
    }

    static func calculateMonthlyEnergy(from sessions: [ChargingSession], month: Date) -> Double {
        sessions
            .filter { $0.startDate.isSameMonth(as: month) }
            .reduce(0) { $0 + $1.energyKWh }
    }

    static func calculateAverageCostPerKWh(from sessions: [ChargingSession], month: Date? = nil) -> Double {
        let filtered: [ChargingSession]
        if let month {
            filtered = sessions.filter { $0.startDate.isSameMonth(as: month) }
        } else {
            filtered = sessions
        }

        let totalCost = filtered.reduce(0) { $0 + $1.amountSGD }
        let totalEnergy = filtered.reduce(0) { $0 + $1.energyKWh }
        guard totalEnergy > 0 else { return 0 }
        return totalCost / totalEnergy
    }

    static func calculateMostUsedChargingNetwork(from sessions: [ChargingSession]) -> (network: String, count: Int)? {
        let grouped = Dictionary(grouping: sessions) { $0.chargingNetwork }
        guard let top = grouped.max(by: { $0.value.count < $1.value.count }),
              !top.key.isEmpty else {
            return nil
        }
        return (top.key, top.value.count)
    }

    static func calculateAverageSOCIncrease(from sessions: [ChargingSession]) -> Double {
        let increases = sessions.map { $0.endSOCPercent - $0.startSOCPercent }.filter { $0 > 0 }
        guard !increases.isEmpty else { return 0 }
        return increases.reduce(0, +) / Double(increases.count)
    }

    static func calculateTotalSessions(from sessions: [ChargingSession], month: Date? = nil) -> Int {
        if let month {
            return sessions.filter { $0.startDate.isSameMonth(as: month) }.count
        }
        return sessions.count
    }

    static func generateAIInsights(from sessions: [ChargingSession], month: Date) -> AIInsight? {
        SessionAnalyticsService.generateInsight(from: sessions, month: month)
    }

    static func networkBreakdown(from sessions: [ChargingSession], month: Date) -> [NetworkBreakdownItem] {
        let filtered = sessions.filter { $0.startDate.isSameMonth(as: month) }
        let grouped = Dictionary(grouping: filtered) { $0.chargingNetwork }

        return grouped
            .map { network, items in
                NetworkBreakdownItem(
                    network: network.isEmpty ? "Unknown" : network,
                    sessionCount: items.count,
                    totalCost: items.reduce(0) { $0 + $1.amountSGD },
                    totalEnergy: items.reduce(0) { $0 + $1.energyKWh }
                )
            }
            .sorted { $0.totalCost > $1.totalCost }
    }

    static func monthlyTrendPoints(from sessions: [ChargingSession], monthCount: Int = 6) -> [MonthlyTrendPoint] {
        let calendar = Calendar.current
        let anchor = Date.now.startOfMonth

        return (0..<monthCount).reversed().compactMap { offset in
            guard let month = calendar.date(byAdding: .month, value: -offset, to: anchor) else {
                return nil
            }

            let monthSessions = sessions.filter { $0.startDate.isSameMonth(as: month) }
            return MonthlyTrendPoint(
                month: month,
                totalCost: monthSessions.reduce(0) { $0 + $1.amountSGD },
                totalEnergy: monthSessions.reduce(0) { $0 + $1.energyKWh },
                sessionCount: monthSessions.count
            )
        }
    }

    static func dailyEnergyPoints(from sessions: [ChargingSession], month: Date) -> [DailyEnergyPoint] {
        let calendar = Calendar.current
        let filtered = sessions.filter { $0.startDate.isSameMonth(as: month) }
        let grouped = Dictionary(grouping: filtered) { calendar.component(.day, from: $0.startDate) }
        let range = calendar.range(of: .day, in: .month, for: month) ?? 1..<31

        return range.map { day in
            let daySessions = grouped[day] ?? []
            let energy = daySessions.reduce(0) { $0 + $1.energyKWh }
            let date = calendar.date(bySetting: .day, value: day, of: month.startOfMonth) ?? month
            return DailyEnergyPoint(day: day, date: date, energy: energy)
        }
    }

    static func monthlyMetrics(from sessions: [ChargingSession], month: Date) -> MonthlyMetrics {
        SessionAnalyticsService.monthlyMetrics(from: sessions, month: month)
    }

    static func dailyCostPoints(from sessions: [ChargingSession], month: Date) -> [DailyCostPoint] {
        SessionAnalyticsService.dailyCostPoints(from: sessions, month: month)
    }
}
