import Foundation

enum ExtractionFieldKey: String, CaseIterable, Hashable, Codable {
    case chargingLocation
    case chargerId
    case chargingNetwork
    case chargerType
    case chargerPowerKW
    case startDate
    case endDate
    case startSOCPercent
    case endSOCPercent
    case odometerKM
    case energyKWh
    case amountSGD
    case sessionDuration
    case idleDuration
    case carModel

    var displayName: String {
        switch self {
        case .chargingLocation: "Location"
        case .chargerId: "Charger ID"
        case .chargingNetwork: "Network"
        case .chargerType: "Charger Type"
        case .chargerPowerKW: "Power"
        case .startDate: "Start"
        case .endDate: "End"
        case .startSOCPercent: "Start SOC"
        case .endSOCPercent: "End SOC"
        case .odometerKM: "Odometer"
        case .energyKWh: "Energy"
        case .amountSGD: "Amount"
        case .sessionDuration: "Charging Duration"
        case .idleDuration: "Idle"
        case .carModel: "Car"
        }
    }
}

struct ExtractionFieldMetadata: Equatable {
    let key: ExtractionFieldKey
    var confidence: Double
    var sourceCategory: CaptureImageCategory?
    var isUncertain: Bool
}

struct SessionExtractionOutput: Equatable {
    let data: ExtractedSessionData
    let rawResponse: String
    let fieldMetadata: [ExtractionFieldKey: ExtractionFieldMetadata]
    let warnings: [String]
    let engineName: String

    var overallConfidence: Double {
        guard !fieldMetadata.isEmpty else { return data.extractionConfidence ?? 0 }
        let total = fieldMetadata.values.reduce(0) { $0 + $1.confidence }
        return total / Double(fieldMetadata.count)
    }
}

struct ValidationResult: Equatable {
    var isValid: Bool
    var warnings: [String]
    var errors: [String]
}
