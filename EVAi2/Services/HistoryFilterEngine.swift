import Foundation

enum HistoryFilterChip: Identifiable, Equatable, Hashable {
    case all
    case month(Date)
    case network(String)
    case car(String)

    var id: String {
        switch self {
        case .all:
            return "all"
        case .month(let date):
            return "month-\(date.timeIntervalSince1970)"
        case .network(let network):
            return "network-\(network)"
        case .car(let car):
            return "car-\(car)"
        }
    }

    var title: String {
        switch self {
        case .all:
            return "All"
        case .month(let date):
            return date.monthYearDisplay
        case .network(let network):
            return network
        case .car(let car):
            return car
        }
    }
}

enum HistorySortOption: String, CaseIterable, Identifiable {
    case date
    case month
    case network
    case car

    var id: String { rawValue }

    var title: String {
        switch self {
        case .date: return "Date"
        case .month: return "Month"
        case .network: return "Network"
        case .car: return "Car"
        }
    }
}

struct HistoryAdvancedFilters: Equatable {
    var startDate: Date?
    var endDate: Date?
    var selectedNetworks: Set<String> = []
    var selectedCars: Set<String> = []
    var minCost: Double?
    var maxCost: Double?
    var minEnergy: Double?
    var maxEnergy: Double?
    var locationQuery: String = ""

    var isActive: Bool {
        startDate != nil
            || endDate != nil
            || !selectedNetworks.isEmpty
            || !selectedCars.isEmpty
            || minCost != nil
            || maxCost != nil
            || minEnergy != nil
            || maxEnergy != nil
            || !locationQuery.trimmingCharacters(in: .whitespaces).isEmpty
    }

    mutating func reset() {
        self = HistoryAdvancedFilters()
    }
}

enum HistoryFilterEngine {
    static func apply(
        sessions: [ChargingSession],
        chip: HistoryFilterChip,
        advanced: HistoryAdvancedFilters
    ) -> [ChargingSession] {
        var results = sessions

        switch chip {
        case .all:
            break
        case .month(let month):
            results = results.filter { $0.startDate.isSameMonth(as: month) }
        case .network(let network):
            results = results.filter { $0.chargingNetwork == network }
        case .car(let car):
            results = results.filter { $0.carModel == car }
        }

        if let startDate = advanced.startDate {
            results = results.filter { $0.startDate >= Calendar.current.startOfDay(for: startDate) }
        }

        if let endDate = advanced.endDate {
            let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate
            results = results.filter { $0.startDate <= endOfDay }
        }

        if !advanced.selectedNetworks.isEmpty {
            results = results.filter { advanced.selectedNetworks.contains($0.chargingNetwork) }
        }

        if !advanced.selectedCars.isEmpty {
            results = results.filter { advanced.selectedCars.contains($0.carModel) }
        }

        if let minCost = advanced.minCost {
            results = results.filter { $0.amountSGD >= minCost }
        }

        if let maxCost = advanced.maxCost {
            results = results.filter { $0.amountSGD <= maxCost }
        }

        if let minEnergy = advanced.minEnergy {
            results = results.filter { $0.energyKWh >= minEnergy }
        }

        if let maxEnergy = advanced.maxEnergy {
            results = results.filter { $0.energyKWh <= maxEnergy }
        }

        let location = advanced.locationQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if !location.isEmpty {
            results = results.filter { $0.chargingLocation.localizedCaseInsensitiveContains(location) }
        }

        return results
    }
}
