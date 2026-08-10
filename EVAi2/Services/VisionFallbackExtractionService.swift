import Foundation

struct HeuristicExtractionResult: Equatable {
    let data: ExtractedSessionData
    /// Fields matched by labeled regex patterns or dashboard-section SOC parsing.
    let strongFields: Set<ExtractionFieldKey>
    let socFromDashboardSections: Bool
    /// Combined OCR text used to derive the heuristics (empty when OCR failed).
    var ocrText: String = ""

    static let empty = HeuristicExtractionResult(
        data: ExtractedSessionData(),
        strongFields: [],
        socFromDashboardSections: false,
        ocrText: ""
    )

    func enriched(with imagePair: SOCExtractionService.Pair) -> HeuristicExtractionResult {
        guard let start = imagePair.start, let end = imagePair.end, start != end else {
            return self
        }

        var data = self.data
        data.startSOCPercent = start
        data.endSOCPercent = end

        var strongFields = self.strongFields
        strongFields.insert(.startSOCPercent)
        strongFields.insert(.endSOCPercent)

        return HeuristicExtractionResult(
            data: data,
            strongFields: strongFields,
            socFromDashboardSections: true,
            ocrText: ocrText
        )
    }
}

enum VisionFallbackExtractionService {
    static func extractHeuristics(from images: [CaptureImageItem]) async throws -> HeuristicExtractionResult {
        let ocrText = try await VisionTextExtractionService.extractCombinedText(from: images)
        var result = parseHeuristics(from: ocrText)
        result.ocrText = ocrText
        return result
    }

    static func extractSessionData(from images: [CaptureImageItem]) async throws -> (ExtractedSessionData, String) {
        let result = try await extractHeuristics(from: images)
        let raw = SessionExtractionParser.encodeRawResponse(result.data)
        return (result.data, raw)
    }

    static func parseHeuristics(from text: String) -> HeuristicExtractionResult {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let lower = text.lowercased()
        var populatedFields = 0
        var strongFields: Set<ExtractionFieldKey> = []

        let energy = firstMatch(in: text, patterns: [
            #"(?i)(?:energy|delivered|charged)[^\d]{0,20}(\d+\.?\d*)\s*kwh"#,
            #"(\d+\.?\d*)\s*kwh"#
        ])
        if energy != nil {
            populatedFields += 1
            if text.range(of: #"(?i)(?:energy|delivered|charged)[^\d]{0,20}\d+\.?\d*\s*kwh"#, options: .regularExpression) != nil {
                strongFields.insert(.energyKWh)
            }
        }

        let amount = firstMatch(in: text, patterns: [
            #"(?i)(?:total|amount|cost|fee|paid)[^\d]{0,20}(?:sgd|\$)?\s*(\d+\.?\d*)"#,
            #"(?i)sgd\s*(\d+\.?\d*)"#,
            #"\$\s*(\d+\.?\d*)"#
        ])
        if amount != nil {
            populatedFields += 1
            if text.range(of: #"(?i)(?:total|amount|cost|fee|paid)[^\d]{0,20}(?:sgd|\$)?\s*\d+\.?\d*"#, options: .regularExpression) != nil
                || text.range(of: #"(?i)sgd\s*\d+\.?\d*"#, options: .regularExpression) != nil {
                strongFields.insert(.amountSGD)
            }
        }

        let power = firstMatch(in: text, patterns: [
            #"(?i)(?:power|output|rate)[^\d]{0,20}(\d+\.?\d*)\s*kw"#,
            #"(\d+\.?\d*)\s*kw"#
        ])
        if power != nil {
            populatedFields += 1
            if text.range(of: #"(?i)(?:power|output|rate)[^\d]{0,20}\d+\.?\d*\s*kw"#, options: .regularExpression) != nil {
                strongFields.insert(.chargerPowerKW)
            }
        }

        let socPair = SOCExtractionService.extractPair(from: text)
        let startSOC = socPair.start
        let endSOC = socPair.end
        let socFromDashboardSections = socPair.readings.count >= 1
        if startSOC != nil { strongFields.insert(.startSOCPercent) }
        if endSOC != nil { strongFields.insert(.endSOCPercent) }
        if socPair.readings.count >= 2 {
            strongFields.insert(.startSOCPercent)
            strongFields.insert(.endSOCPercent)
        }
        let resolvedStartSOC = startSOC
        let resolvedEndSOC = endSOC

        if resolvedStartSOC != nil { populatedFields += 1 }
        if resolvedEndSOC != nil { populatedFields += 1 }

        let odometer = firstMatch(in: text, patterns: [
            #"(?i)(?:odometer|odo|mileage|km)[^\d]{0,16}(\d{3,7})"#,
            #"(\d{3,7})\s*km"#
        ])
        if odometer != nil {
            populatedFields += 1
            if text.range(of: #"(?i)(?:odometer|odo|mileage)"#, options: .regularExpression) != nil {
                strongFields.insert(.odometerKM)
            }
        }

        let duration = firstMatch(in: text, patterns: [
            #"(?i)(?:session|charging|duration)[^\d]{0,20}(\d+\s*h\s*\d+\s*min|\d+\s*h|\d+\s*min|\d+:\d+)"#,
            #"(\d+\s*h\s*\d+\s*min|\d+\s*h|\d+\s*min|\d+:\d+)"#
        ])
        if duration != nil {
            populatedFields += 1
            if text.range(of: #"(?i)(?:session|charging|duration)[^\d]{0,20}(\d+\s*h|\d+\s*min|\d+:\d+)"#, options: .regularExpression) != nil {
                strongFields.insert(.sessionDuration)
            }
        }

        let idle = firstMatch(in: text, patterns: [
            #"(?i)idle[^\d]{0,30}(\d+\s*(?:min|mins|m)\s*\d+\s*(?:sec|secs|s)|\d+\s*h\s*\d+\s*min|\d+\s*h|\d+\s*min|\d+:\d+)"#
        ])
        if idle != nil {
            populatedFields += 1
            strongFields.insert(.idleDuration)
        }

        let network = detectNetwork(in: lower)
        if network != nil {
            populatedFields += 1
            strongFields.insert(.chargingNetwork)
        }

        let chargerType = detectChargerType(in: lower)
        if chargerType != nil {
            populatedFields += 1
            strongFields.insert(.chargerType)
        }

        let location = detectLocation(from: lines)
        if location != nil { populatedFields += 1 }

        let carModel = detectCarModel(from: lines)
        if carModel != nil { populatedFields += 1 }

        let (startDate, startTime, endDate, endTime) = detectDateTimes(in: text)
        if startDate != nil {
            populatedFields += 1
            strongFields.insert(.startDate)
        }
        if endDate != nil {
            populatedFields += 1
            strongFields.insert(.endDate)
        }

        let confidence = min(0.85, max(0.35, Double(populatedFields) / 12.0 * 0.85))

        var resolvedChargerType = chargerType.map { ChargerTypeOption.normalizedStoredValue($0) }
        let rawPower = power.flatMap(Double.init)

        if resolvedChargerType == nil || resolvedChargerType == ChargerTypeOption.others.rawValue,
           let rawPower,
           let inferred = ChargerPowerCatalog.inferChargerType(fromPower: rawPower) {
            resolvedChargerType = inferred.rawValue
        }

        let resolvedPower: Double?
        if let type = resolvedChargerType,
           let rawPower,
           rawPower > 0,
           ChargerTypeOption.from(storedValue: type) != .others {
            resolvedPower = ChargerPowerCatalog.normalizedPower(rawPower, chargerType: type)
        } else {
            resolvedPower = rawPower
        }

        let data = ExtractedSessionData(
            chargingLocation: location,
            chargerId: firstMatch(in: text, patterns: [
                #"(?i)(?:charger|station|evse|id)[#:\s-]+([A-Z0-9-]{4,})"#
            ]),
            chargingNetwork: network,
            chargerType: resolvedChargerType,
            chargerPowerKW: resolvedPower,
            startDate: startDate,
            startTime: startTime,
            endDate: endDate,
            endTime: endTime,
            startSOCPercent: resolvedStartSOC,
            endSOCPercent: resolvedEndSOC,
            odometerKM: odometer.flatMap(Double.init),
            energyKWh: energy.flatMap(Double.init),
            amountSGD: amount.flatMap(Double.init),
            sessionDuration: normalizedDurationString(duration),
            idleDuration: normalizedDurationString(idle),
            carModel: carModel,
            extractionConfidence: confidence
        )

        return HeuristicExtractionResult(
            data: data,
            strongFields: strongFields,
            socFromDashboardSections: socFromDashboardSections
        )
    }

    private static func firstMatch(in text: String, patterns: [String]) -> String? {
        for pattern in patterns {
            if let value = firstCapture(in: text, pattern: pattern) {
                return value
            }
        }
        return nil
    }

    private static func firstCapture(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        let value = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private static func allMatches(in text: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard match.numberOfRanges > 1, let capture = Range(match.range(at: 1), in: text) else {
                return nil
            }
            return String(text[capture])
        }
    }

    private static func detectNetwork(in lower: String) -> String? {
        let networks = [
            "charge+", "chargeplus", "shell recharge", "shell", "sp group", "spgroup",
            "tesla", "chargepoint", "evgo", "electrify america", "bp pulse", "ionity",
            "pod point", "gridserve", "blink", "greenlots"
        ]
        return networks.first { lower.contains($0) }?.capitalized
    }

    private static func detectChargerType(in lower: String) -> String? {
        if lower.contains("dc fast") || lower.contains("dcfc") || lower.contains("ccs") || lower.contains("chademo") {
            return ChargerTypeOption.dcFastCharger.rawValue
        }
        if lower.contains("type 2") || lower.contains("type2") || lower.contains(" ac ") || lower.contains("ac charger") {
            return ChargerTypeOption.acCharger.rawValue
        }
        if lower.contains("ac ") || lower.hasSuffix(" ac") {
            return ChargerTypeOption.acCharger.rawValue
        }
        if lower.contains(" dc ") || lower.contains("dc charger") {
            return ChargerTypeOption.dcFastCharger.rawValue
        }
        return nil
    }

    private static func detectLocation(from lines: [String]) -> String? {
        let addressPattern = #"(?i)\d{1,5}\s+[A-Za-z0-9\s,'.-]{4,}"#
        for line in lines {
            if line.count >= 12,
               line.range(of: addressPattern, options: .regularExpression) != nil {
                return line
            }
        }

        return lines.first { line in
            line.count >= 15 &&
            line.contains(where: \.isNumber) &&
            line.contains(where: \.isLetter) &&
            !line.lowercased().contains("kwh") &&
            !line.lowercased().contains("battery")
        }
    }

    private static func detectCarModel(from lines: [String]) -> String? {
        let brands = ["tesla", "byd", "bmw", "mercedes", "audi", "volkswagen", "vw", "hyundai", "kia", "nissan", "porsche", "polestar", "volvo", "mg", "xpeng", "nio"]
        for line in lines {
            let lower = line.lowercased()
            if let brand = brands.first(where: { lower.contains($0) }) {
                return line
            }
        }
        return nil
    }

    private static func normalizedDurationString(_ value: String?) -> String? {
        guard let value else { return nil }
        let parsed = DurationParsingService.parseToMinutes(from: value)
        if !parsed.isEmpty { return parsed }
        return value.nilIfEmpty
    }

    private static func detectDateTimes(in text: String) -> (String?, String?, String?, String?) {
        let datePatterns = [
            #"\b(\d{4}-\d{2}-\d{2})\b"#,
            #"\b(\d{1,2}/\d{1,2}/\d{4})\b"#,
            #"\b(\d{1,2}\s+[A-Za-z]{3}\s+\d{4})\b"#
        ]
        let timePatterns = [
            #"\b(\d{1,2}:\d{2}(?::\d{2})?\s*(?:AM|PM|am|pm)?)\b"#
        ]

        var dates: [String] = []
        for pattern in datePatterns {
            dates.append(contentsOf: allMatches(in: text, pattern: pattern))
        }

        var times: [String] = []
        for pattern in timePatterns {
            times.append(contentsOf: allMatches(in: text, pattern: pattern))
        }

        let startDate = dates.first
        let endDate = dates.count > 1 ? dates.last : dates.first
        let startTime = times.first
        let endTime = times.count > 1 ? times.last : times.first

        return (startDate, startTime, endDate, endTime)
    }
}
