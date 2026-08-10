import Foundation

/// LTA-style charger categories for session editing, import, and OCR.
enum ChargerTypeOption: String, CaseIterable, Identifiable {
    case others = "Others"
    case acCharger = "AC Charger"
    case dcFastCharger = "DC Fast Charger"

    var id: String { rawValue }

    static let editableOptions: [ChargerTypeOption] = [.acCharger, .dcFastCharger, .others]

    var isClassified: Bool {
        self == .acCharger || self == .dcFastCharger
    }

    static func from(storedValue: String) -> ChargerTypeOption {
        let normalized = storedValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return .others }

        switch normalized {
        case "others", "other", "unknown":
            return .others
        case "ac charger", "ac":
            return .acCharger
        case "dc fast charger", "dc fast", "dcfc", "dc":
            return .dcFastCharger
        default:
            break
        }

        if normalized.contains("type 2") || normalized.contains("type2") {
            return .acCharger
        }
        if normalized.contains("chademo") || normalized.contains("ccs") {
            return .dcFastCharger
        }
        if normalized.contains("ac") && !normalized.contains("dc") {
            return .acCharger
        }
        if normalized.contains("dc") {
            return .dcFastCharger
        }

        return .others
    }

    static func from(powerRating: String, plugType: String = "") -> ChargerTypeOption {
        let rating = powerRating.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        switch rating {
        case "AC": return .acCharger
        case "DC": return .dcFastCharger
        default:
            let fromPlug = from(storedValue: plugType)
            return fromPlug.isClassified ? fromPlug : .others
        }
    }

    static func displayLabel(for storedValue: String) -> String {
        from(storedValue: storedValue).rawValue
    }

    static func normalizedStoredValue(_ storedValue: String) -> String {
        from(storedValue: storedValue).rawValue
    }

    static func normalizedOptional(_ storedValue: String?) -> String {
        guard let storedValue else { return others.rawValue }
        let trimmed = storedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return others.rawValue }
        return from(storedValue: trimmed).rawValue
    }
}
