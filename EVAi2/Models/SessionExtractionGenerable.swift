import Foundation
import FoundationModels

@available(iOS 26.0, *)
@Generable(description: "Extracted EV charging session data")
struct SessionExtractionGenerable {
    var charging_location: String?
    var charger_id: String?
    var charging_network: String?
    var charger_type: String?
    var charger_power_kw: Double?
    var start_date: String?
    var start_time: String?
    var end_date: String?
    var end_time: String?
    var start_soc_percent: Double?
    var end_soc_percent: Double?
    var odometer_km: Double?
    var energy_kwh: Double?
    var amount_sgd: Double?
    var session_duration: String?
    var idle_duration: String?
    var car_model: String?
    var extraction_confidence: Double?
}

@available(iOS 26.0, *)
extension SessionExtractionGenerable {
    func toExtractedSessionData() -> ExtractedSessionData {
        ExtractedSessionData(
            chargingLocation: charging_location,
            chargerId: charger_id,
            chargingNetwork: charging_network,
            chargerType: ChargerTypeOption.normalizedOptional(charger_type),
            chargerPowerKW: charger_power_kw,
            startDate: start_date,
            startTime: start_time,
            endDate: end_date,
            endTime: end_time,
            startSOCPercent: start_soc_percent,
            endSOCPercent: end_soc_percent,
            odometerKM: odometer_km,
            energyKWh: energy_kwh,
            amountSGD: amount_sgd,
            sessionDuration: normalizedDuration(session_duration),
            idleDuration: normalizedDuration(idle_duration),
            carModel: car_model,
            extractionConfidence: extraction_confidence
        )
    }

    private func normalizedDuration(_ value: String?) -> String? {
        guard let value else { return nil }
        let parsed = DurationParsingService.parseToMinutes(from: value)
        if !parsed.isEmpty { return parsed }
        return value.nilIfEmpty
    }
}
