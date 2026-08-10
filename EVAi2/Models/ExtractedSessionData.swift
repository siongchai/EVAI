import Foundation

struct ExtractedSessionData: Codable, Equatable {
    var chargingLocation: String?
    var chargerId: String?
    var chargingNetwork: String?
    var chargerType: String?
    var chargerPowerKW: Double?
    var startDate: String?
    var startTime: String?
    var endDate: String?
    var endTime: String?
    var startSOCPercent: Double?
    var endSOCPercent: Double?
    var odometerKM: Double?
    var energyKWh: Double?
    var amountSGD: Double?
    var sessionDuration: String?
    var idleDuration: String?
    var carModel: String?
    var extractionConfidence: Double?

    enum CodingKeys: String, CodingKey {
        case chargingLocation = "charging_location"
        case chargerId = "charger_id"
        case chargingNetwork = "charging_network"
        case chargerType = "charger_type"
        case chargerPowerKW = "charger_power_kw"
        case startDate = "start_date"
        case startTime = "start_time"
        case endDate = "end_date"
        case endTime = "end_time"
        case startSOCPercent = "start_soc_percent"
        case endSOCPercent = "end_soc_percent"
        case odometerKM = "odometer_km"
        case energyKWh = "energy_kwh"
        case amountSGD = "amount_sgd"
        case sessionDuration = "session_duration"
        case idleDuration = "idle_duration"
        case carModel = "car_model"
        case extractionConfidence = "extraction_confidence"
    }
}

struct EditableSessionDraft: Equatable {
    var chargingLocation: String = ""
    var chargerId: String = ""
    var chargingNetwork: String = ""
    var chargerType: String = ""
    var chargerPowerKW: String = ""
    var startDate: Date = .now
    var endDate: Date = .now
    var startSOCPercent: String = ""
    var endSOCPercent: String = ""
    var odometerKM: String = ""
    var energyKWh: String = ""
    var amountSGD: String = ""
    var sessionDurationMinutes: String = ""
    var idleDurationMinutes: String = ""
    var carModel: String = ""
    var extractionConfidence: Double = 0

    init() {}

    init(from extracted: ExtractedSessionData) {
        chargingLocation = extracted.chargingLocation ?? ""
        chargerId = extracted.chargerId ?? ""
        chargingNetwork = extracted.chargingNetwork ?? ""
        chargerType = ChargerTypeOption.normalizedOptional(extracted.chargerType)
        if let rawPower = extracted.chargerPowerKW, rawPower > 0 {
            var type = ChargerTypeOption.from(storedValue: chargerType)
            if type == .others, let inferred = ChargerPowerCatalog.inferChargerType(fromPower: rawPower) {
                type = inferred
                chargerType = inferred.rawValue
            }
            if type != .others {
                chargerPowerKW = ChargerPowerCatalog.format(
                    ChargerPowerCatalog.normalizedPower(rawPower, chargerType: chargerType)
                )
            } else {
                chargerPowerKW = ChargerPowerCatalog.format(rawPower)
            }
        } else {
            chargerPowerKW = ""
        }
        startSOCPercent = extracted.startSOCPercent.map { String(format: "%.0f", $0) } ?? ""
        endSOCPercent = extracted.endSOCPercent.map { String(format: "%.0f", $0) } ?? ""
        odometerKM = extracted.odometerKM.map { String(format: "%.0f", $0) } ?? ""
        energyKWh = extracted.energyKWh.map { String(format: "%.1f", $0) } ?? ""
        amountSGD = extracted.amountSGD.map { String(format: "%.2f", $0) } ?? ""
        carModel = extracted.carModel ?? ""
        extractionConfidence = extracted.extractionConfidence ?? 0

        sessionDurationMinutes = SessionDataParser.durationMinutes(from: extracted.sessionDuration)
        idleDurationMinutes    = SessionDataParser.durationMinutes(from: extracted.idleDuration)

        if let start = SessionDataParser.combinedDate(
            dateString: extracted.startDate,
            timeString: extracted.startTime
        ) {
            startDate = start
        }

        // endDate = when active charging stopped: start + (total session − idle).
        if let chargingEnd = SessionCalculator.chargingEndDate(
            startDate: startDate,
            totalSessionMinutes: SessionDataParser.durationMinutesValue(from: sessionDurationMinutes),
            idleMinutes: SessionDataParser.durationMinutesValue(from: idleDurationMinutes)
        ) {
            endDate = chargingEnd
        } else if let aiEnd = SessionDataParser.combinedDate(
            dateString: extracted.endDate,
            timeString: extracted.endTime
        ) {
            var chargingEnd = aiEnd
            if chargingEnd < startDate {
                chargingEnd = chargingEnd.addingTimeInterval(24 * 3600)
            }
            endDate = chargingEnd
        }
    }

    /// Active charging time in minutes: total session duration minus idle.
    var chargingDurationMinutes: Int {
        SessionCalculator.chargingDurationMinutes(from: self)
    }

    init(from session: ChargingSession) {
        chargingLocation = session.chargingLocation
        chargerId = session.chargerId
        chargingNetwork = session.chargingNetwork
        chargerType = ChargerTypeOption.normalizedStoredValue(session.chargerType)
        chargerPowerKW = session.chargerPowerKW > 0 ? String(format: "%.1f", session.chargerPowerKW) : ""
        startDate = session.startDate
        endDate = session.endDate
        startSOCPercent = session.startSOCPercent > 0 ? String(format: "%.0f", session.startSOCPercent) : ""
        endSOCPercent = session.endSOCPercent > 0 ? String(format: "%.0f", session.endSOCPercent) : ""
        odometerKM = session.odometerKM > 0 ? String(format: "%.0f", session.odometerKM) : ""
        energyKWh = session.energyKWh > 0 ? String(format: "%.1f", session.energyKWh) : ""
        amountSGD = session.amountSGD > 0 ? String(format: "%.2f", session.amountSGD) : ""
        carModel = session.carModel
        extractionConfidence = session.extractionConfidence
        sessionDurationMinutes = session.sessionDuration > 0 ? String(session.sessionDuration / 60) : ""
        idleDurationMinutes = session.idleDuration > 0 ? String(session.idleDuration / 60) : ""
    }

    func apply(to session: ChargingSession) {
        session.chargingLocation = chargingLocation
        session.chargerId = chargerId
        session.chargingNetwork = chargingNetwork
        session.chargerType = ChargerTypeOption.normalizedStoredValue(chargerType)
        session.chargerPowerKW = Double(chargerPowerKW) ?? session.chargerPowerKW
        session.startDate = startDate
        session.endDate = endDate
        session.startSOCPercent = Double(startSOCPercent) ?? session.startSOCPercent
        session.endSOCPercent = Double(endSOCPercent) ?? session.endSOCPercent
        session.odometerKM = Double(odometerKM) ?? session.odometerKM
        session.energyKWh = Double(energyKWh) ?? session.energyKWh
        session.amountSGD = Double(amountSGD) ?? session.amountSGD
        session.sessionDuration = SessionDataParser.durationMinutesValue(from: sessionDurationMinutes) * 60
        session.idleDuration = SessionDataParser.durationMinutesValue(from: idleDurationMinutes) * 60
        session.carModel = carModel
        session.extractionConfidence = extractionConfidence
        session.updatedAt = .now
    }

    func toChargingSession(rawAIResponse: String, sourceImageIDs: String = "") -> ChargingSession? {
        guard !chargingLocation.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }

        let sessionMinutes = SessionDataParser.durationMinutesValue(from: sessionDurationMinutes)
        let idleMinutes = SessionDataParser.durationMinutesValue(from: idleDurationMinutes)

        // endDate is already the charging end (set in init / updated by user in the form).
        // Correct for cross-midnight edits just in case.
        var interval = endDate.timeIntervalSince(startDate)
        if interval < 0 { interval += 24 * 3600 }
        let storedEndDate = interval > 0 ? endDate : startDate

        let protectedResponse: String
        if rawAIResponse.isEmpty {
            protectedResponse = ""
        } else if let encrypted = try? DataProtectionService.encrypt(rawAIResponse) {
            protectedResponse = encrypted
        } else {
            protectedResponse = rawAIResponse
        }

        return ChargingSession(
            chargingLocation: chargingLocation,
            chargerId: chargerId.isEmpty ? "UNKNOWN" : chargerId,
            chargingNetwork: chargingNetwork.isEmpty ? "Unknown" : chargingNetwork,
            chargerType: ChargerTypeOption.normalizedStoredValue(chargerType),
            chargerPowerKW: Double(chargerPowerKW) ?? 0,
            startDate: startDate,
            endDate: storedEndDate,
            startSOCPercent: Double(startSOCPercent) ?? 0,
            endSOCPercent: Double(endSOCPercent) ?? 0,
            odometerKM: Double(odometerKM) ?? 0,
            energyKWh: Double(energyKWh) ?? 0,
            amountSGD: Double(amountSGD) ?? 0,
            sessionDuration: sessionMinutes * 60,   // total session seconds (charging + idle)
            idleDuration: idleMinutes * 60,          // idle seconds
            carModel: carModel.isEmpty ? "Unknown Car" : carModel,
            extractionConfidence: extractionConfidence,
            rawAIResponse: protectedResponse,
            sourceImageIDs: sourceImageIDs
        )
    }
}

enum SessionDataParser {
    static func combinedDate(dateString: String?, timeString: String?) -> Date? {
        let datePart = dateString?.trimmingCharacters(in: .whitespaces) ?? ""
        let timePart = timeString?.trimmingCharacters(in: .whitespaces) ?? ""

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        // Full date + time
        if !datePart.isEmpty {
            let combined = [datePart, timePart].filter { !$0.isEmpty }.joined(separator: " ")
            let dateTimeFormats = [
                "yyyy-MM-dd HH:mm",
                "yyyy-MM-dd'T'HH:mm:ss",
                "yyyy-MM-dd h:mm a",
                "yyyy-MM-dd h:mma",
                "dd MMM yyyy HH:mm",
                "dd/MM/yyyy HH:mm"
            ]
            for fmt in dateTimeFormats {
                formatter.dateFormat = fmt
                if let d = formatter.date(from: combined) ?? formatter.date(from: datePart) {
                    return d
                }
            }
            if let d = ISO8601DateFormatter().date(from: combined) { return d }
        }

        // Time only — parse relative to today; caller adjusts for cross-midnight if needed
        if !timePart.isEmpty {
            let timeFormats = ["h:mm a", "h:mma", "HH:mm", "h:mm"]
            for fmt in timeFormats {
                formatter.dateFormat = fmt
                if let t = formatter.date(from: timePart) {
                    // Anchor to today's date
                    let cal = Calendar.current
                    let now = Date()
                    let comps = cal.dateComponents([.hour, .minute], from: t)
                    return cal.date(bySettingHour: comps.hour ?? 0,
                                    minute: comps.minute ?? 0,
                                    second: 0,
                                    of: now)
                }
            }
        }

        return nil
    }

    /// Parses a duration string into a whole-number minute count.
    static func durationMinutes(from value: String?) -> String {
        DurationParsingService.parseToMinutes(from: value)
    }

    /// Parses a duration string into whole minutes, returning 0 when invalid.
    static func durationMinutesValue(from value: String) -> Int {
        DurationParsingService.parseToMinutesValue(from: value)
    }
}
