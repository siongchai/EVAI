import Foundation

enum SessionExtractionParser {
    static let extractionPrompt = """
You are an EV charging data extraction assistant.
Analyze ALL provided images in any order.

STEP 1 — IDENTIFY IMAGE TYPES:
Classify each image as one of:
- Dashboard before charging
- Dashboard after charging
- Charging app summary (or receipt)

Upload order is not authoritative — infer types from visual content only.

STEP 2 — EXTRACT FROM DASHBOARDS:
Find the battery State of Charge (SOC) on each dashboard photo:
- Must have a "%" symbol linked to a battery level gauge (F/E scale, battery icon, SOC/Battery label)
- ONLY accept numbers displayed as battery charge percentage with "%"
- Ignore numbers WITHOUT "%": cruise/set speed, ADAS, speed limit, temperature, driving range (km), odometer, clock time, drive mode
- CRITICAL: the large central number on many dashboards (e.g. "30" with a speedometer icon, NO "%") is cruise/set speed — NEVER use it as SOC
- Example: dashboard photos show 17% and 100% with central "30" on both → use 17 and 100 only

STEP 3 — ASSIGN BEGIN/END SOC:
This is a charging session — battery level rises while charging:
- start_soc_percent = lower SOC % across dashboard photos (before charging)
- end_soc_percent = higher SOC % across dashboard photos (after charging)
- If dashboard clock times are visible: earlier time = start, later time = end (use with SOC to confirm)
- If only one dashboard SOC is found: set that value and null for the other
- Return numeric 0–100 only (strip "%" in JSON)

STEP 4 — EXTRACT FROM CHARGING APP / RECEIPT:
- charging_location: full site name and address if visible
- charger_id: charger / connector / station identifier
- charging_network: operator brand (SP, Charge+, Shell Recharge, Tesla, etc.)
- charger_type: AC Charger, DC Fast Charger, or Others if unclear
- charger_power_kw: rated power in kW — AC typically 7.4, 11, 22, or 43; DC typically 50–100 (Standard) or 120–350 (Ultra-Fast)
- start_date / start_time: session start date and time
- end_date / end_time: time when charging power dropped to zero on the graph (the moment active charging stopped — NOT the session close time which includes idle)
- energy_kwh: total energy delivered (number before "kWh")
- amount_sgd: grand total paid (Total / Amount Paid / Grand Total — not subtotals or unit price)
- session_duration: TOTAL session duration including idle (e.g. "1h 53m" or "113" minutes). Use "37m 53s" for 37 min 53 sec — NEVER concatenate as 3753.
- idle_duration: idle time only (e.g. "37m 53s" or "37 min 53 sec"). NEVER concatenate minutes+seconds digits (3753 means 37m 53s, not 3753 minutes).
- odometer_km: odometer if visible on a dashboard photo
- car_model: car make/model if visible

STEP 5 — OUTPUT:
- Return valid JSON only — no markdown, no explanations, no extra text
- Use null for unknown or unreadable fields; do not guess
- Dates as YYYY-MM-DD when possible; times as HH:MM or include AM/PM exactly as shown
- Numeric fields: plain numbers only — no "%", "$", "SGD", "kWh", or "km" suffixes in JSON
- extraction_confidence: overall confidence from 0 to 1

Return exactly:

{
"charging_location": null,
"charger_id": null,
"charging_network": null,
"charger_type": null,
"charger_power_kw": null,
"start_date": null,
"start_time": null,
"end_date": null,
"end_time": null,
"start_soc_percent": null,
"end_soc_percent": null,
"odometer_km": null,
"energy_kwh": null,
"amount_sgd": null,
"session_duration": null,
"idle_duration": null,
"car_model": null,
"extraction_confidence": null
}
"""

    /// Text-only extraction prompt for OCR-driven engines (e.g. the on-device
    /// Apple Intelligence model, which never receives the images themselves).
    /// Written for a small model: concrete rules, flat-text heuristics, no
    /// references to "looking at" images or gauges.
    static let ocrExtractionPrompt = """
You are an EV charging data extraction assistant.
You are given ONLY OCR text from charging screenshots — you cannot see the images. OCR is imperfect: spacing may be odd and "%" or "$" may be missing or on a separate line.

The text is divided into sections per screenshot, each starting with "--- Image N ---". Follow the same logic as vision extraction:

STEP 1 — IDENTIFY SECTION TYPES from text cues:
- Dashboard: SOC %, range (km), odometer, clock time
- Charging app / receipt: kWh, Total/Amount, network name, charger ID, durations

STEP 2 — EXTRACT SOC FROM DASHBOARD SECTIONS:
- SOC must be a battery % (0–100), normally with "%" (e.g. "17%", "100 %")
- NOT SOC: range (120 km), odometer (ODO 22280), cruise/set speed (bare "30", "90"), clock times, temperature
- If "%" is missing on a short standalone number in a dashboard section, use context — never use cruise-speed values

STEP 3 — ASSIGN BEGIN/END SOC:
- start_soc_percent = lower SOC across dashboard sections
- end_soc_percent = higher SOC across dashboard sections
- If clock times exist: earlier section = start, later = end
- If only one SOC found: set it and null for the other

STEP 4 — EXTRACT FROM APP / RECEIPT SECTIONS:
- charging_location, charger_id, charging_network, charger_type, charger_power_kw
- start/end dates and times; end_time = when charging power hit zero on the graph (active charging end, NOT the session close time that includes idle)
- energy_kwh, amount_sgd, session_duration (TOTAL including idle, e.g. "1h 53m"), idle_duration (e.g. "37m 53s" — never 3753 for 37 min 53 sec)

STEP 5 — OUTPUT:
- Return ONE JSON object with exactly these keys: charging_location, charger_id, charging_network, charger_type, charger_power_kw, start_date, start_time, end_date, end_time, start_soc_percent, end_soc_percent, odometer_km, energy_kwh, amount_sgd, session_duration, idle_duration, car_model, extraction_confidence
- Numeric fields: plain numbers — strip "%", "$", "SGD", "kWh", "km"
- Use null when not clearly supported; do not guess
- No markdown, no explanation — JSON only
"""

    static func buildPrompt(ocrText: String, imageCount: Int) -> String {
        let trimmedOCR = String(ocrText.prefix(6_000))

        return """
        \(PromptManager.effectiveOCRPrompt)

        Worked example —

        OCR text:
        --- Image 1 ---
        Charge+
        Total  $16.20
        Energy  35.5 kWh
        8:34 pm
        --- Image 2 ---
        17 %
        120 km
        ODO 22280
        --- Image 3 ---
        100 %
        410 km
        10:17 am

        Correct JSON (note: 120 km and 410 km are range, 22280 is odometer, 17 is the earlier/start SOC and 100 the later/end SOC, "$" and "kWh" stripped):
        {"charging_location":null,"charger_id":null,"charging_network":"Charge+","charger_type":null,"charger_power_kw":null,"start_date":null,"start_time":"8:34 pm","end_date":null,"end_time":"10:17 am","start_soc_percent":17,"end_soc_percent":100,"odometer_km":22280,"energy_kwh":35.5,"amount_sgd":16.2,"session_duration":null,"idle_duration":null,"car_model":null,"extraction_confidence":0.8}

        Now extract from this OCR text (\(imageCount) image section(s)):
        \(trimmedOCR)
        """
    }

    static func parseJSON(from rawContent: String) throws -> ExtractedSessionData {
        let sanitized = sanitizeJSONPayload(rawContent)
        guard let data = sanitized.data(using: .utf8) else {
            throw SessionExtractionError.decodingFailed
        }

        if var decoded = try? JSONDecoder().decode(ExtractedSessionData.self, from: data) {
            decoded = normalizeDurations(in: decoded)
            return decoded
        }

        if let flexible = parseFlexibleJSON(data) {
            return flexible
        }

        throw SessionExtractionError.decodingFailed
    }

    static func encodeRawResponse(_ data: ExtractedSessionData) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? encoder.encode(data)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    }

    static func sanitizeJSONPayload(_ content: String) -> String {
        var text = content.trimmingCharacters(in: .whitespacesAndNewlines)

        if text.hasPrefix("```") {
            text = text.replacingOccurrences(of: "```json", with: "")
            text = text.replacingOccurrences(of: "```", with: "")
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") {
            return String(text[start...end])
        }

        return text
    }

    private static func parseFlexibleJSON(_ data: Data) -> ExtractedSessionData? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        return ExtractedSessionData(
            chargingLocation: stringValue(object["charging_location"]),
            chargerId: stringValue(object["charger_id"]),
            chargingNetwork: stringValue(object["charging_network"]),
            chargerType: normalizedChargerType(stringValue(object["charger_type"])),
            chargerPowerKW: doubleValue(object["charger_power_kw"]),
            startDate: stringValue(object["start_date"]),
            startTime: stringValue(object["start_time"]),
            endDate: stringValue(object["end_date"]),
            endTime: stringValue(object["end_time"]),
            startSOCPercent: doubleValue(object["start_soc_percent"]),
            endSOCPercent: doubleValue(object["end_soc_percent"]),
            odometerKM: doubleValue(object["odometer_km"]),
            energyKWh: doubleValue(object["energy_kwh"]),
            amountSGD: doubleValue(object["amount_sgd"]),
            sessionDuration: normalizedDuration(stringValue(object["session_duration"])),
            idleDuration: normalizedDuration(stringValue(object["idle_duration"])),
            carModel: stringValue(object["car_model"]),
            extractionConfidence: doubleValue(object["extraction_confidence"])
        )
    }

    private static func normalizeDurations(in data: ExtractedSessionData) -> ExtractedSessionData {
        var copy = data
        copy.sessionDuration = normalizedDuration(data.sessionDuration)
        copy.idleDuration = normalizedDuration(data.idleDuration)
        return copy
    }

    private static func normalizedDuration(_ value: String?) -> String? {
        guard let value else { return nil }
        let parsed = DurationParsingService.parseToMinutes(from: value)
        if !parsed.isEmpty { return parsed }
        return value.nilIfEmpty
    }

    private static func normalizedChargerType(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return ChargerTypeOption.normalizedStoredValue(trimmed)
    }

    private static func stringValue(_ value: Any?) -> String? {
        switch value {
        case let string as String:
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        case let number as NSNumber:
            return number.stringValue
        case is NSNull, nil:
            return nil
        default:
            return nil
        }
    }

    private static func doubleValue(_ value: Any?) -> Double? {
        switch value {
        case let double as Double:
            return double
        case let int as Int:
            return Double(int)
        case let string as String:
            let cleaned = string
                .replacingOccurrences(of: "%", with: "")
                .replacingOccurrences(of: "$", with: "")
                .replacingOccurrences(of: "SGD", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return Double(cleaned)
        case let number as NSNumber:
            return number.doubleValue
        case is NSNull, nil:
            return nil
        default:
            return nil
        }
    }
}

enum SessionExtractionError: LocalizedError {
    case appleIntelligenceUnavailable(String)
    case noTextFound
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .appleIntelligenceUnavailable(let reason):
            reason
        case .noTextFound:
            "No readable text was found in the uploaded images."
        case .decodingFailed:
            "Failed to decode the extracted session data."
        }
    }
}
