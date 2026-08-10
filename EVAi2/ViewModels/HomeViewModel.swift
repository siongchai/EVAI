import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class HomeViewModel {
    private(set) var selectedMonth: Date = .now.startOfMonth
    private(set) var metrics = MonthlyMetrics(totalCost: 0, totalEnergy: 0, sessionCount: 0, averageCostPerKWh: 0)
    private(set) var costTrend: [DailyCostPoint] = []
    private(set) var recentSessions: [ChargingSession] = []
    private(set) var insight: AIInsight?
    private(set) var isLoading = false

    private var allSessions: [ChargingSession] = []

    func load(sessions: [ChargingSession]) {
        allSessions = sessions
        refresh()
    }

    func selectMonth(_ month: Date) {
        selectedMonth = month.startOfMonth
        refresh()
    }

    func shiftMonth(by offset: Int) {
        guard let newMonth = Calendar.current.date(byAdding: .month, value: offset, to: selectedMonth) else { return }
        selectedMonth = newMonth.startOfMonth
        refresh()
    }

    func greeting(for userName: String) -> String {
        let hour = Calendar.current.component(.hour, from: .now)
        let salutation: String
        switch hour {
        case 5..<12: salutation = "Good morning"
        case 12..<17: salutation = "Good afternoon"
        default: salutation = "Good evening"
        }
        let name = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = name.isEmpty ? AppConstants.defaultUserName : name
        return "\(salutation), \(displayName) 👋"
    }

    private func refresh() {
        metrics = SessionAnalyticsService.monthlyMetrics(from: allSessions, month: selectedMonth)
        costTrend = SessionAnalyticsService.dailyCostPoints(from: allSessions, month: selectedMonth)
        recentSessions = SessionAnalyticsService.recentSessions(from: allSessions.filter {
            $0.startDate.isSameMonth(as: selectedMonth)
        })
        insight = SessionAnalyticsService.generateInsight(from: allSessions, month: selectedMonth)
        WidgetDataStore.sync(from: allSessions)
    }
}
