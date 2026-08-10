import Foundation

enum ExtractionDataSource: String, Equatable {
    case ai
    case ocr
}

struct ExtractionFusionResult: Equatable {
    let data: ExtractedSessionData
    let fieldSources: [ExtractionFieldKey: ExtractionDataSource]
    let notes: [String]
}

enum ExtractionFusionService {

    /// High-confidence cloud AI: use every AI field directly, no OCR involvement.
    /// Only fix is to ensure SOC start ≤ end (charging always raises battery level).
    static func useAIOnly(ai: ExtractedSessionData, engineName: String) -> ExtractionFusionResult {
        var data = ai
        var sources: [ExtractionFieldKey: ExtractionDataSource] = [:]
        var notes: [String] = ["High AI confidence — all fields taken directly from \(engineName)."]

        // Mark every populated field as AI-sourced.
        for field in ExtractionFieldKey.allCases {
            sources[field] = .ai
        }

        // Swap SOC if AI got the order backwards.
        if let s = data.startSOCPercent, let e = data.endSOCPercent, s > e {
            data.startSOCPercent = e
            data.endSOCPercent   = s
            notes.append("SOC start/end swapped to match charging direction.")
        }

        let startStr = data.startSOCPercent.map { "\(Int($0))%" } ?? "—"
        let endStr   = data.endSOCPercent.map   { "\(Int($0))%" } ?? "—"
        notes.append("SOC from AI: \(startStr) → \(endStr).")

        return ExtractionFusionResult(data: data, fieldSources: sources, notes: notes)
    }

    /// Used when cloud AI (OpenAI / Claude) is the extraction engine.
    /// Merges all non-SOC fields using OCR (energy, amounts, times, etc.)
    /// but preserves the AI's SOC values exactly — no OCR override.
    static func mergeKeepingAISOC(
        ai: ExtractedSessionData,
        ocr: HeuristicExtractionResult
    ) -> ExtractionFusionResult {
        var result = merge(ai: ai, ocr: ocr)
        var data    = result.data
        var sources = result.fieldSources
        var notes   = result.notes

        // Restore AI SOC over whatever merge() may have chosen.
        if let start = ai.startSOCPercent {
            data.startSOCPercent        = start
            sources[.startSOCPercent]   = .ai
        }
        if let end = ai.endSOCPercent {
            data.endSOCPercent          = end
            sources[.endSOCPercent]     = .ai
        }

        // Ensure start ≤ end (charging always raises battery level).
        if let s = data.startSOCPercent, let e = data.endSOCPercent, s > e {
            data.startSOCPercent = e
            data.endSOCPercent   = s
            notes.append("AI SOC values swapped to match charging direction (start < end).")
        }

        let startStr = data.startSOCPercent.map { "\(Int($0))%" } ?? "—"
        let endStr   = data.endSOCPercent.map   { "\(Int($0))%" } ?? "—"
        notes.append("SOC from AI vision: \(startStr) → \(endStr).")

        return ExtractionFusionResult(data: data, fieldSources: sources, notes: notes)
    }

    static func merge(
        ai: ExtractedSessionData,
        ocr: HeuristicExtractionResult
    ) -> ExtractionFusionResult {
        var merged = ai
        var fieldSources: [ExtractionFieldKey: ExtractionDataSource] = [:]
        var notes: [String] = []

        mergeSOC(
            ai: ai,
            ocr: ocr,
            into: &merged,
            fieldSources: &fieldSources,
            notes: &notes
        )

        mergeNumeric(
            field: .energyKWh,
            ai: ai.energyKWh,
            ocr: ocr.data.energyKWh,
            preferOCR: ocr.strongFields.contains(.energyKWh),
            tolerance: 0.5,
            into: &merged.energyKWh,
            fieldSources: &fieldSources,
            notes: &notes
        )

        mergeNumeric(
            field: .amountSGD,
            ai: ai.amountSGD,
            ocr: ocr.data.amountSGD,
            preferOCR: ocr.strongFields.contains(.amountSGD),
            tolerance: 0.05,
            into: &merged.amountSGD,
            fieldSources: &fieldSources,
            notes: &notes
        )

        mergeNumeric(
            field: .chargerPowerKW,
            ai: ai.chargerPowerKW,
            ocr: ocr.data.chargerPowerKW,
            preferOCR: ocr.strongFields.contains(.chargerPowerKW),
            tolerance: 1.0,
            into: &merged.chargerPowerKW,
            fieldSources: &fieldSources,
            notes: &notes
        )

        mergeNumeric(
            field: .odometerKM,
            ai: ai.odometerKM,
            ocr: ocr.data.odometerKM,
            preferOCR: ocr.strongFields.contains(.odometerKM),
            tolerance: 5,
            into: &merged.odometerKM,
            fieldSources: &fieldSources,
            notes: &notes
        )

        mergeString(
            field: .sessionDuration,
            ai: ai.sessionDuration,
            ocr: ocr.data.sessionDuration,
            preferOCR: ocr.strongFields.contains(.sessionDuration),
            into: &merged.sessionDuration,
            fieldSources: &fieldSources,
            notes: &notes
        )

        mergeString(
            field: .idleDuration,
            ai: ai.idleDuration,
            ocr: ocr.data.idleDuration,
            preferOCR: ocr.strongFields.contains(.idleDuration),
            into: &merged.idleDuration,
            fieldSources: &fieldSources,
            notes: &notes
        )

        mergeString(
            field: .chargingLocation,
            ai: ai.chargingLocation,
            ocr: ocr.data.chargingLocation,
            preferOCR: false,
            into: &merged.chargingLocation,
            fieldSources: &fieldSources,
            notes: &notes
        )

        mergeString(
            field: .chargerId,
            ai: ai.chargerId,
            ocr: ocr.data.chargerId,
            preferOCR: false,
            into: &merged.chargerId,
            fieldSources: &fieldSources,
            notes: &notes
        )

        mergeString(
            field: .chargingNetwork,
            ai: ai.chargingNetwork,
            ocr: ocr.data.chargingNetwork,
            preferOCR: ocr.strongFields.contains(.chargingNetwork) && ai.chargingNetwork?.isEmpty != false,
            into: &merged.chargingNetwork,
            fieldSources: &fieldSources,
            notes: &notes
        )

        mergeString(
            field: .chargerType,
            ai: ai.chargerType,
            ocr: ocr.data.chargerType,
            preferOCR: ocr.strongFields.contains(.chargerType) && ai.chargerType?.isEmpty != false,
            into: &merged.chargerType,
            fieldSources: &fieldSources,
            notes: &notes
        )

        mergeString(
            field: .carModel,
            ai: ai.carModel,
            ocr: ocr.data.carModel,
            preferOCR: false,
            into: &merged.carModel,
            fieldSources: &fieldSources,
            notes: &notes
        )

        mergeDateTime(
            ai: ai,
            ocr: ocr,
            into: &merged,
            fieldSources: &fieldSources,
            notes: &notes
        )

        if merged.extractionConfidence == nil || merged.extractionConfidence == 0 {
            merged.extractionConfidence = ai.extractionConfidence ?? ocr.data.extractionConfidence
        }

        merged.chargerType = ChargerTypeOption.normalizedOptional(merged.chargerType)

        if let power = merged.chargerPowerKW, power > 0 {
            var type = ChargerTypeOption.from(storedValue: merged.chargerType ?? "")
            if type == .others, let inferred = ChargerPowerCatalog.inferChargerType(fromPower: power) {
                type = inferred
                merged.chargerType = inferred.rawValue
            }
            if type != .others {
                merged.chargerPowerKW = ChargerPowerCatalog.normalizedPower(power, chargerType: type.rawValue)
            }
        }

        merged.sessionDuration = normalizeDurationField(merged.sessionDuration)
        merged.idleDuration = normalizeDurationField(merged.idleDuration)

        return ExtractionFusionResult(
            data: merged,
            fieldSources: fieldSources,
            notes: notes
        )
    }

    // MARK: - SOC

    private static func mergeSOC(
        ai: ExtractedSessionData,
        ocr: HeuristicExtractionResult,
        into merged: inout ExtractedSessionData,
        fieldSources: inout [ExtractionFieldKey: ExtractionDataSource],
        notes: inout [String]
    ) {
        // Check if each AI value is a valid, non-cruise SOC.
        let aiStartValid = ai.startSOCPercent.map { SOCExtractionService.isValidSOC($0) } ?? false
        let aiEndValid   = ai.endSOCPercent.map   { SOCExtractionService.isValidSOC($0) } ?? false

        // Case 1: AI gave us a complete valid pair. Trust it — cloud vision reads actual pixels.
        // OCR is unreliable for small battery-% digits and cross-day timestamp ordering.
        if aiStartValid, aiEndValid,
           let aiStart = ai.startSOCPercent, let aiEnd = ai.endSOCPercent {
            merged.startSOCPercent = min(aiStart, aiEnd)
            merged.endSOCPercent   = max(aiStart, aiEnd)
            fieldSources[.startSOCPercent] = .ai
            fieldSources[.endSOCPercent]   = .ai
            return
        }

        // Case 2: AI has one or both cruise-speed values — reject those, fill from OCR.
        if !aiStartValid, let s = ai.startSOCPercent {
            notes.append("Fusion: rejected AI start SOC \(Int(s))% (cruise/set-speed).")
        }
        if !aiEndValid, let e = ai.endSOCPercent {
            notes.append("Fusion: rejected AI end SOC \(Int(e))% (cruise/set-speed).")
        }

        if aiStartValid, let start = ai.startSOCPercent {
            merged.startSOCPercent = start
            fieldSources[.startSOCPercent] = .ai
        } else if let ocrStart = ocr.data.startSOCPercent {
            merged.startSOCPercent = ocrStart
            fieldSources[.startSOCPercent] = .ocr
        }

        if aiEndValid, let end = ai.endSOCPercent {
            merged.endSOCPercent = end
            fieldSources[.endSOCPercent] = .ai
        } else if let ocrEnd = ocr.data.endSOCPercent {
            merged.endSOCPercent = ocrEnd
            fieldSources[.endSOCPercent] = .ocr
        }

    }

    private static func fillMissingSOC(
        from ocr: ExtractedSessionData,
        into merged: inout ExtractedSessionData,
        fieldSources: inout [ExtractionFieldKey: ExtractionDataSource]
    ) {
        if merged.startSOCPercent == nil, let start = ocr.startSOCPercent {
            merged.startSOCPercent = start
            fieldSources[.startSOCPercent] = .ocr
        }
        if merged.endSOCPercent == nil, let end = ocr.endSOCPercent {
            merged.endSOCPercent = end
            fieldSources[.endSOCPercent] = .ocr
        }
    }

    private static func isValidSOCPair(start: Double?, end: Double?) -> Bool {
        guard let start, let end else { return false }
        return (0...100).contains(start) && (0...100).contains(end) && end >= start
    }

    private static func isAISOCSuspect(ai: ExtractedSessionData) -> Bool {
        let candidates = [ai.startSOCPercent, ai.endSOCPercent].compactMap { $0 }
        return candidates.contains { value in
            let intValue = Int(value.rounded())
            return [25, 30, 35, 40, 50, 60, 70, 80, 90].contains(intValue)
        }
    }

    private static func isDuplicateCruiseAI(ai: ExtractedSessionData) -> Bool {
        guard let start = ai.startSOCPercent, let end = ai.endSOCPercent, start == end else {
            return false
        }
        let intValue = Int(start.rounded())
        return [20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 100].contains(intValue)
    }

    // MARK: - Generic merge helpers

    private static func mergeNumeric(
        field: ExtractionFieldKey,
        ai: Double?,
        ocr: Double?,
        preferOCR: Bool,
        tolerance: Double,
        into merged: inout Double?,
        fieldSources: inout [ExtractionFieldKey: ExtractionDataSource],
        notes: inout [String]
    ) {
        let (value, source, note) = pickNumeric(
            field: field,
            ai: ai,
            ocr: ocr,
            preferOCR: preferOCR,
            tolerance: tolerance
        )
        merged = value
        if let source {
            fieldSources[field] = source
        }
        if let note {
            notes.append(note)
        }
    }

    private static func mergeString(
        field: ExtractionFieldKey,
        ai: String?,
        ocr: String?,
        preferOCR: Bool,
        into merged: inout String?,
        fieldSources: inout [ExtractionFieldKey: ExtractionDataSource],
        notes: inout [String]
    ) {
        let (value, source, note) = pickString(
            field: field,
            ai: ai,
            ocr: ocr,
            preferOCR: preferOCR
        )
        merged = value
        if let source {
            fieldSources[field] = source
        }
        if let note {
            notes.append(note)
        }
    }

    private static func pickNumeric(
        field: ExtractionFieldKey,
        ai: Double?,
        ocr: Double?,
        preferOCR: Bool,
        tolerance: Double
    ) -> (Double?, ExtractionDataSource?, String?) {
        let aiPresent = ai != nil
        let ocrPresent = ocr != nil

        guard aiPresent || ocrPresent else { return (nil, nil, nil) }

        if preferOCR, let ocr {
            if let ai, abs(ai - ocr) > tolerance {
                return (
                    ocr,
                    .ocr,
                    "\(field.displayName) taken from OCR (\(format(ocr))) — AI had \(format(ai))."
                )
            }
            return (ocr, .ocr, nil)
        }

        if let ai {
            if let ocr, abs(ai - ocr) > tolerance {
                return (ai, .ai, nil)
            }
            return (ai, .ai, nil)
        }

        return (ocr, .ocr, nil)
    }

    private static func pickString(
        field: ExtractionFieldKey,
        ai: String?,
        ocr: String?,
        preferOCR: Bool
    ) -> (String?, ExtractionDataSource?, String?) {
        let aiValue = ai?.trimmingCharacters(in: .whitespacesAndNewlines)
        let ocrValue = ocr?.trimmingCharacters(in: .whitespacesAndNewlines)
        let aiPresent = aiValue?.isEmpty == false
        let ocrPresent = ocrValue?.isEmpty == false

        guard aiPresent || ocrPresent else { return (nil, nil, nil) }

        if preferOCR, ocrPresent {
            if aiPresent, aiValue?.caseInsensitiveCompare(ocrValue ?? "") != .orderedSame {
                return (ocrValue, .ocr, "\(field.displayName) taken from OCR.")
            }
            return (ocrValue, .ocr, nil)
        }

        if aiPresent {
            return (aiValue, .ai, nil)
        }

        return (ocrValue, .ocr, nil)
    }

    private static func mergeDateTime(
        ai: ExtractedSessionData,
        ocr: HeuristicExtractionResult,
        into merged: inout ExtractedSessionData,
        fieldSources: inout [ExtractionFieldKey: ExtractionDataSource],
        notes: inout [String]
    ) {
        let aiStartParses = SessionDataParser.combinedDate(dateString: ai.startDate, timeString: ai.startTime) != nil
        let aiEndParses = SessionDataParser.combinedDate(dateString: ai.endDate, timeString: ai.endTime) != nil
        let ocrStartParses = SessionDataParser.combinedDate(dateString: ocr.data.startDate, timeString: ocr.data.startTime) != nil
        let ocrEndParses = SessionDataParser.combinedDate(dateString: ocr.data.endDate, timeString: ocr.data.endTime) != nil

        if aiStartParses {
            merged.startDate = ai.startDate
            merged.startTime = ai.startTime
            fieldSources[.startDate] = .ai
        } else if ocrStartParses {
            merged.startDate = ocr.data.startDate
            merged.startTime = ocr.data.startTime
            fieldSources[.startDate] = .ocr
        } else {
            merged.startDate = ai.startDate ?? ocr.data.startDate
            merged.startTime = ai.startTime ?? ocr.data.startTime
            if merged.startDate != nil || merged.startTime != nil {
                fieldSources[.startDate] = ai.startDate != nil ? .ai : .ocr
            }
        }

        if aiEndParses {
            merged.endDate = ai.endDate
            merged.endTime = ai.endTime
            fieldSources[.endDate] = .ai
        } else if ocrEndParses {
            merged.endDate = ocr.data.endDate
            merged.endTime = ocr.data.endTime
            fieldSources[.endDate] = .ocr
        } else {
            merged.endDate = ai.endDate ?? ocr.data.endDate
            merged.endTime = ai.endTime ?? ocr.data.endTime
            if merged.endDate != nil || merged.endTime != nil {
                fieldSources[.endDate] = ai.endDate != nil ? .ai : .ocr
            }
        }

        if let start = SessionDataParser.combinedDate(dateString: merged.startDate, timeString: merged.startTime),
           let end = SessionDataParser.combinedDate(dateString: merged.endDate, timeString: merged.endTime),
           end < start,
           ocrEndParses,
           let ocrEnd = SessionDataParser.combinedDate(dateString: ocr.data.endDate, timeString: ocr.data.endTime),
           ocrEnd >= start {
            merged.endDate = ocr.data.endDate
            merged.endTime = ocr.data.endTime
            fieldSources[.endDate] = .ocr
            notes.append("End time taken from OCR — AI end time was before start.")
        }
    }

    private static func normalizeDurationField(_ value: String?) -> String? {
        guard let value else { return nil }
        let parsed = DurationParsingService.parseToMinutes(from: value)
        if !parsed.isEmpty { return parsed }
        return value.nilIfEmpty
    }

    private static func format(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.2f", value)
    }
}
