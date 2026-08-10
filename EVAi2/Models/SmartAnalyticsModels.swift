import Foundation

struct StationCostSummary: Identifiable, Hashable {
    let location: String
    let network: String
    let totalCost: Double
    let sessionCount: Int
    let averageCostPerKWh: Double

    var id: String { location }
}

struct HourlyCostSummary: Identifiable, Hashable {
    let hour: Int
    let averageCostPerKWh: Double
    let sessionCount: Int

    var id: Int { hour }

    var hourLabel: String {
        String(format: "%02d:00", hour)
    }
}

struct QuarterlyTrendPoint: Identifiable, Hashable {
    let quarterStart: Date
    let label: String
    let totalCost: Double
    let totalEnergy: Double
    let sessionCount: Int

    var id: Date { quarterStart }
}

struct DailyTrendPoint: Identifiable, Hashable {
    let date: Date
    let totalCost: Double
    let totalEnergy: Double

    var id: Date { date }
}

struct NetworkComparisonItem: Identifiable, Hashable {
    let network: String
    let averageCostPerKWh: Double
    let totalCost: Double
    let sessionCount: Int

    var id: String { network }
}

struct HeatmapCell: Identifiable, Hashable {
    let weekday: Int
    let hour: Int
    let sessionCount: Int

    var id: String { "\(weekday)-\(hour)" }
}

struct SOCTrendPoint: Identifiable, Hashable {
    let date: Date
    let averageIncrease: Double

    var id: Date { date }
}

struct BatteryUsagePoint: Identifiable, Hashable {
    let date: Date
    let energyKWh: Double
    let estimatedBatteryPercent: Double?

    var id: Date { date }
}

struct ChargingForecast: Hashable {
    let projectedMonthlyCost: Double
    let projectedMonthlyEnergy: Double
    let projectedSessionCount: Int
    let trendDirection: TrendDirection
}

enum TrendDirection: String, Hashable {
    case up
    case down
    case stable

    var label: String {
        switch self {
        case .up: "Increasing"
        case .down: "Decreasing"
        case .stable: "Stable"
        }
    }
}

struct ChargingHabitSummary: Hashable {
    let preferredHour: Int?
    let preferredWeekday: Int?
    let offPeakSessionRatio: Double
    let averageSessionsPerWeek: Double
    let lateNightSavingsPercent: Double?
}

struct SmartAnalyticsSnapshot: Hashable {
    let bestNetwork: NetworkComparisonItem?
    let mostExpensiveStation: StationCostSummary?
    let cheapestHour: HourlyCostSummary?
    let networkCostAverages: [NetworkComparisonItem]
    let ninetyDayTrend: [DailyTrendPoint]
    let monthlyForecast: ChargingForecast
    let costPrediction: ChargingForecast
    let chargingHabits: ChargingHabitSummary
}
