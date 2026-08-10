import Foundation

enum ChargerPowerTier: String {
    case standardDC = "Standard DC"
    case ultraFastDC = "Ultra-Fast DC"
}

enum ChargerPowerCatalog {
    static let acPowers: [Double] = [7.4, 11, 22, 43]
    static let dcStandardPowers: [Double] = [50, 75, 100]
    static let dcUltraFastPowers: [Double] = [120, 150, 180, 240, 350]

    static var dcPowers: [Double] {
        dcStandardPowers + dcUltraFastPowers
    }

    static func allowedPowers(for chargerType: ChargerTypeOption) -> [Double] {
        switch chargerType {
        case .acCharger: return acPowers
        case .dcFastCharger: return dcPowers
        case .others: return []
        }
    }

    static func defaultPower(for chargerType: ChargerTypeOption) -> Double? {
        switch chargerType {
        case .acCharger: return 7.4
        case .dcFastCharger: return 50
        case .others: return nil
        }
    }

    static func isValid(_ kilowatts: Double, for chargerType: ChargerTypeOption) -> Bool {
        guard kilowatts > 0 else { return false }
        return allowedPowers(for: chargerType).contains { abs($0 - kilowatts) < 0.05 }
    }

    static func snap(_ kilowatts: Double, for chargerType: ChargerTypeOption) -> Double {
        guard kilowatts > 0 else {
            return defaultPower(for: chargerType) ?? 0
        }

        let options = allowedPowers(for: chargerType)
        guard !options.isEmpty else { return kilowatts }

        return options.min { abs($0 - kilowatts) < abs($1 - kilowatts) } ?? kilowatts
    }

    static func inferChargerType(fromPower kilowatts: Double) -> ChargerTypeOption? {
        guard kilowatts > 0 else { return nil }

        if acPowers.contains(where: { abs($0 - kilowatts) < 0.05 }) {
            return .acCharger
        }
        if dcPowers.contains(where: { abs($0 - kilowatts) < 1 }) {
            return .dcFastCharger
        }
        if kilowatts <= 43 {
            return .acCharger
        }
        if kilowatts >= 50 {
            return .dcFastCharger
        }
        return nil
    }

    static func tier(for kilowatts: Double) -> ChargerPowerTier? {
        if dcStandardPowers.contains(where: { abs($0 - kilowatts) < 0.05 }) || (50 ... 100).contains(kilowatts) {
            return .standardDC
        }
        if dcUltraFastPowers.contains(where: { abs($0 - kilowatts) < 0.05 }) || (120 ... 350).contains(kilowatts) {
            return .ultraFastDC
        }
        return nil
    }

    static func format(_ kilowatts: Double) -> String {
        if abs(kilowatts - kilowatts.rounded()) < 0.05 {
            return String(format: "%.0f", kilowatts.rounded())
        }
        return String(format: "%.1f", kilowatts)
    }

    static func normalizedPowerString(current: String, chargerType: String) -> String {
        let option = ChargerTypeOption.from(storedValue: chargerType)
        guard option != .others else { return current }

        let currentValue = Double(current.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        if currentValue > 0, isValid(currentValue, for: option) {
            return format(currentValue)
        }

        guard let defaultPower = defaultPower(for: option) else { return "" }
        return format(defaultPower)
    }

    static func normalizedPower(_ kilowatts: Double, chargerType: String) -> Double {
        let option = ChargerTypeOption.from(storedValue: chargerType)
        guard option != .others else { return kilowatts }
        return snap(kilowatts, for: option)
    }

    static func powerLabel(_ kilowatts: Double) -> String {
        "\(format(kilowatts)) kW"
    }

    static func displayLabel(kilowatts: Double, chargerType: String) -> String {
        guard kilowatts > 0 else { return "—" }

        let option = ChargerTypeOption.from(storedValue: chargerType)
        let powerText = powerLabel(kilowatts)

        if option == .dcFastCharger, let tier = tier(for: kilowatts) {
            return "\(powerText) (\(tier.rawValue))"
        }
        return powerText
    }
}
