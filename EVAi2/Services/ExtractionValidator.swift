import Foundation

enum ExtractionValidator {
    static func validateSession(_ data: ExtractedSessionData) -> ValidationResult {
        var warnings: [String] = []
        var errors: [String] = []

        warnings.append(contentsOf: validateSOC(data))
        warnings.append(contentsOf: validateDates(data))
        warnings.append(contentsOf: validateDuration(data))
        warnings.append(contentsOf: validateEnergy(data))
        warnings.append(contentsOf: generateWarnings(for: data))

        if data.chargingLocation?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            errors.append("Charging location is required.")
        }

        return ValidationResult(
            isValid: errors.isEmpty,
            warnings: warnings,
            errors: errors
        )
    }

    static func validateSOC(_ data: ExtractedSessionData) -> [String] {
        var warnings: [String] = []

        if let start = data.startSOCPercent {
            if start < 0 || start > 100 {
                warnings.append("Start SOC value is impossible (\(Int(start))%).")
            }
        }

        if let end = data.endSOCPercent {
            if end < 0 || end > 100 {
                warnings.append("End SOC value is impossible (\(Int(end))%).")
            }
        }

        if let start = data.startSOCPercent, let end = data.endSOCPercent, end < start {
            warnings.append("End SOC is lower than Start SOC.")
        }

        if let start = data.startSOCPercent, let end = data.endSOCPercent, end - start > 95 {
            warnings.append("SOC increase exceeds 95% — please verify Start SOC and End SOC.")
        }

        return warnings
    }

    static func validateDates(_ data: ExtractedSessionData) -> [String] {
        var warnings: [String] = []

        let start = SessionDataParser.combinedDate(dateString: data.startDate, timeString: data.startTime)
        let end = SessionDataParser.combinedDate(dateString: data.endDate, timeString: data.endTime)

        if data.startDate != nil || data.startTime != nil, start == nil {
            warnings.append("Start date/time could not be parsed.")
        }

        if data.endDate != nil || data.endTime != nil, end == nil {
            warnings.append("End date/time could not be parsed.")
        }

        if let start, let end, end < start {
            warnings.append("End time is before start time.")
        }

        if let start, start > Date.now.addingTimeInterval(86_400) {
            warnings.append("Start date appears to be in the future.")
        }

        return warnings
    }

    static func validateDuration(_ data: ExtractedSessionData) -> [String] {
        var warnings: [String] = []

        let start = SessionDataParser.combinedDate(dateString: data.startDate, timeString: data.startTime)
        let end = SessionDataParser.combinedDate(dateString: data.endDate, timeString: data.endTime)

        if let start, let end {
            let intervalMinutes = Int(end.timeIntervalSince(start) / 60)
            if intervalMinutes <= 0 {
                warnings.append("Session duration mismatch: end is not after start.")
            }
        }

        if let idleText = data.idleDuration, !idleText.isEmpty {
            let idleMinutes = Int(SessionDataParser.durationMinutes(from: idleText)) ?? 0
            if let durationText = data.sessionDuration {
                let sessionMinutes = Int(SessionDataParser.durationMinutes(from: durationText)) ?? 0
                if sessionMinutes > 0, idleMinutes > sessionMinutes {
                    warnings.append("Idle duration exceeds total session duration.")
                }
            }
        }

        return warnings
    }

    static func generateWarnings(for data: ExtractedSessionData) -> [String] {
        var warnings: [String] = []

        let missing = ConfidenceEngine.detectMissingFields(in: data)
        let critical: Set<ExtractionFieldKey> = [.chargingLocation, .energyKWh, .amountSGD]
        for field in missing where critical.contains(field) {
            warnings.append("Missing required field: \(field.displayName).")
        }

        if let energy = data.energyKWh, energy <= 0 {
            warnings.append("Energy must be greater than zero.")
        }

        if let amount = data.amountSGD, amount < 0 {
            warnings.append("Amount cannot be negative.")
        }

        if let energy = data.energyKWh, energy > 500 {
            warnings.append("Energy value seems unusually high (\(energy) kWh).")
        }

        if (data.extractionConfidence ?? 1) < 0.5 {
            warnings.append("Overall extraction confidence is low.")
        }

        return warnings
    }

    private static func validateEnergy(_ data: ExtractedSessionData) -> [String] {
        var warnings: [String] = []
        if let energy = data.energyKWh, energy < 0 {
            warnings.append("Energy cannot be negative.")
        }
        return warnings
    }
}
