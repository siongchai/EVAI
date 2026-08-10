import Foundation

enum SearchScope: String, CaseIterable, Identifiable {
    case all
    case location
    case chargerId
    case network
    case car
    case month

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All"
        case .location: "Location"
        case .chargerId: "Charger ID"
        case .network: "Network"
        case .car: "Car"
        case .month: "Month"
        }
    }
}

enum SearchEngine {
    static func search(
        sessions: [ChargingSession],
        query: String,
        scope: SearchScope = .all
    ) -> [ChargingSession] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return sessions }

        return sessions.filter { session in
            matches(session: session, query: trimmed, scope: scope)
        }
    }

    static func matches(
        session: ChargingSession,
        query: String,
        scope: SearchScope = .all
    ) -> Bool {
        let normalized = query.lowercased()

        switch scope {
        case .all:
            return session.chargingLocation.lowercased().contains(normalized)
                || session.chargerId.lowercased().contains(normalized)
                || session.chargingNetwork.lowercased().contains(normalized)
                || session.carModel.lowercased().contains(normalized)
                || session.startDate.monthYearDisplay.lowercased().contains(normalized)
                || session.chargerType.lowercased().contains(normalized)
        case .location:
            return session.chargingLocation.lowercased().contains(normalized)
        case .chargerId:
            return session.chargerId.lowercased().contains(normalized)
        case .network:
            return session.chargingNetwork.lowercased().contains(normalized)
        case .car:
            return session.carModel.lowercased().contains(normalized)
        case .month:
            return session.startDate.monthYearDisplay.lowercased().contains(normalized)
                || monthTokenMatches(session.startDate, query: normalized)
        }
    }

    private static func monthTokenMatches(_ date: Date, query: String) -> Bool {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        formatter.dateFormat = "MMMM yyyy"
        if formatter.string(from: date).lowercased().contains(query) { return true }

        formatter.dateFormat = "MMM yyyy"
        if formatter.string(from: date).lowercased().contains(query) { return true }

        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date).lowercased().contains(query)
    }
}
