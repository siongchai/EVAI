import Foundation

enum ConfidenceEngine {
    private static let uncertaintyThreshold = 0.75

    static func calculateFieldConfidence(
        for field: ExtractionFieldKey,
        data: ExtractedSessionData,
        source: CaptureImageCategory?,
        warnings: [String]
    ) -> Double {
        guard hasValue(field, in: data) else { return 0 }

        var confidence = baseConfidence(for: field, data: data)

        if source != nil {
            confidence = min(1.0, confidence + 0.08)
        } else {
            confidence = max(0.35, confidence - 0.15)
        }

        if warnings.contains(where: { $0.localizedCaseInsensitiveContains(field.displayName) }) {
            confidence = max(0.25, confidence - 0.20)
        }

        return min(1.0, max(0, confidence))
    }

    static func calculateOverallConfidence(
        fieldConfidences: [ExtractionFieldKey: Double],
        aiReported: Double?
    ) -> Double {
        let populated = fieldConfidences.values.filter { $0 > 0 }
        guard !populated.isEmpty else {
            return aiReported ?? 0
        }

        let average = populated.reduce(0, +) / Double(populated.count)
        if let aiReported {
            return (average * 0.7) + (aiReported * 0.3)
        }
        return average
    }

    static func detectMissingFields(in data: ExtractedSessionData) -> [ExtractionFieldKey] {
        ExtractionFieldKey.allCases.filter { !hasValue($0, in: data) }
    }

    static func buildFieldMetadata(
        data: ExtractedSessionData,
        sources: [ExtractionFieldKey: CaptureImageCategory?],
        warnings: [String]
    ) -> [ExtractionFieldKey: ExtractionFieldMetadata] {
        var metadata: [ExtractionFieldKey: ExtractionFieldMetadata] = [:]

        for field in ExtractionFieldKey.allCases {
            let confidence = calculateFieldConfidence(
                for: field,
                data: data,
                source: sources[field] ?? nil,
                warnings: warnings
            )
            metadata[field] = ExtractionFieldMetadata(
                key: field,
                confidence: confidence,
                sourceCategory: sources[field] ?? nil,
                isUncertain: confidence > 0 && confidence < uncertaintyThreshold
            )
        }

        return metadata
    }

    static func applyOverallConfidence(
        to data: inout ExtractedSessionData,
        fieldMetadata: [ExtractionFieldKey: ExtractionFieldMetadata]
    ) {
        let confidences = fieldMetadata.mapValues(\.confidence)
        data.extractionConfidence = calculateOverallConfidence(
            fieldConfidences: confidences,
            aiReported: data.extractionConfidence
        )
    }

    private static func baseConfidence(for field: ExtractionFieldKey, data: ExtractedSessionData) -> Double {
        switch field {
        case .amountSGD:
            return data.amountSGD != nil ? 0.98 : 0
        case .energyKWh:
            return data.energyKWh != nil ? 0.96 : 0
        case .startSOCPercent, .endSOCPercent:
            return 0.85
        case .chargingLocation:
            return 0.75
        case .chargerId, .chargingNetwork:
            return 0.80
        case .startDate, .endDate, .sessionDuration:
            return 0.82
        default:
            return 0.78
        }
    }

    private static func hasValue(_ field: ExtractionFieldKey, in data: ExtractedSessionData) -> Bool {
        switch field {
        case .chargingLocation: data.chargingLocation?.isEmpty == false
        case .chargerId: data.chargerId?.isEmpty == false
        case .chargingNetwork: data.chargingNetwork?.isEmpty == false
        case .chargerType: data.chargerType?.isEmpty == false
        case .chargerPowerKW: (data.chargerPowerKW ?? 0) > 0
        case .startDate: data.startDate?.isEmpty == false || data.startTime?.isEmpty == false
        case .endDate: data.endDate?.isEmpty == false || data.endTime?.isEmpty == false
        case .startSOCPercent: data.startSOCPercent != nil
        case .endSOCPercent: data.endSOCPercent != nil
        case .odometerKM: (data.odometerKM ?? 0) > 0
        case .energyKWh: (data.energyKWh ?? 0) > 0
        case .amountSGD: (data.amountSGD ?? 0) > 0
        case .sessionDuration: data.sessionDuration?.isEmpty == false
        case .idleDuration: data.idleDuration?.isEmpty == false
        case .carModel: data.carModel?.isEmpty == false
        }
    }
}
