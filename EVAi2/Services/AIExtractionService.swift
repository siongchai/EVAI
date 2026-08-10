import Foundation

enum ExtractionEngine: Equatable {
    case openAI
    case claude
    case appleIntelligence
    case visionOCR

    var displayName: String {
        switch self {
        case .openAI: "OpenAI GPT-4o"
        case .claude: "Claude Sonnet 4.6"
        case .appleIntelligence: "Apple Intelligence"
        case .visionOCR: "On-Device OCR"
        }
    }
}

enum AIExtractionService {
    static var preferredEngine: ExtractionEngine {
        if let cloud = resolvedCloudProvider() {
            switch cloud {
            case .openAI: return .openAI
            case .claude: return .claude
            }
        }
        if #available(iOS 26.0, *), AppleIntelligenceService.isAvailable {
            return .appleIntelligence
        }
        return .visionOCR
    }

    static var isAvailable: Bool {
        resolvedCloudProvider() != nil || preferredEngine != .visionOCR || true
    }

    static var statusMessage: String? {
        if let cloud = resolvedCloudProvider() {
            switch cloud {
            case .openAI:
                return "Using OpenAI GPT-4o Vision with OCR fusion."
            case .claude:
                return "Using Claude Vision with OCR fusion."
            }
        }
        switch preferredEngine {
        case .openAI, .claude:
            return nil
        case .appleIntelligence:
            return "Using Apple Intelligence with OCR fusion."
        case .visionOCR:
            if #available(iOS 26.0, *) {
                if let reason = AppleIntelligenceService.unavailabilityMessage {
                    return "\(reason) Add an OpenAI or Claude API key in AI Settings, or use on-device OCR."
                }
            }
            return "Add an OpenAI or Claude API key in AI Settings for cloud extraction, or use on-device OCR."
        }
    }

    /// AI confidence threshold above which all AI fields are used as-is (no OCR mixing).
    static let highConfidenceThreshold: Double = 0.75

    static func extractSession(from images: [CaptureImageItem]) async throws -> SessionExtractionOutput {
        let usingCloudAI = resolvedCloudProvider() != nil

        // OCR runs to ground the AI prompt text; also used as fallback for low-confidence results.
        let heuristics = await loadHeuristics(from: images)

        let (aiData, aiRaw, baseEngineName) = try await extractAIData(
            from: images,
            ocrText: heuristics.ocrText
        )

        if usingCloudAI {
            let confidence = aiData.extractionConfidence ?? 0

            if confidence >= highConfidenceThreshold {
                // High confidence: use AI output for every field — no OCR mixing at all.
                let fusion = ExtractionFusionService.useAIOnly(ai: aiData, engineName: baseEngineName)
                return buildSessionOutput(data: fusion.data, aiRaw: aiRaw, fusion: fusion, images: images, engineName: baseEngineName)
            } else {
                // Low confidence: keep AI SOC, blend other fields with OCR.
                let fusion = ExtractionFusionService.mergeKeepingAISOC(ai: aiData, ocr: heuristics)
                let engineName = heuristics.strongFields.isEmpty ? baseEngineName : "\(baseEngineName) + OCR"
                return buildSessionOutput(data: fusion.data, aiRaw: aiRaw, fusion: fusion, images: images, engineName: engineName)
            }
        }

        // OCR-only / Apple Intelligence path: blend AI text output with on-device OCR.
        let imageSOCPair = await SOCExtractionService.extractPairFromImages(images)
        let ocrForFusion = heuristics.enriched(with: imageSOCPair)
        let fusion = ExtractionFusionService.merge(ai: aiData, ocr: ocrForFusion)

        var fusedData = fusion.data
        var fusionNotes = fusion.notes
        let socReconciled = SOCExtractionService.reconcile(
            start: fusedData.startSOCPercent,
            end: fusedData.endSOCPercent,
            ocrText: ocrForFusion.ocrText,
            imagePair: imageSOCPair
        )
        fusedData.startSOCPercent = socReconciled.start
        fusedData.endSOCPercent   = socReconciled.end
        fusionNotes.append(contentsOf: socReconciled.notes)

        let reconciledFusion = ExtractionFusionResult(data: fusedData, fieldSources: fusion.fieldSources, notes: fusionNotes)
        let engineName = ocrForFusion.strongFields.isEmpty && aiData.extractionConfidence != nil
            ? baseEngineName : "\(baseEngineName) + OCR"

        return buildSessionOutput(data: reconciledFusion.data, aiRaw: aiRaw, fusion: reconciledFusion, images: images, engineName: engineName)
    }

    // MARK: - Private

    private static func loadHeuristics(from images: [CaptureImageItem]) async -> HeuristicExtractionResult {
        do {
            return try await VisionFallbackExtractionService.extractHeuristics(from: images)
        } catch {
            ErrorLogger.log("OCR heuristics failed during fusion", category: .extraction, error: error)
            if let text = try? await VisionTextExtractionService.extractCombinedText(from: images) {
                var result = VisionFallbackExtractionService.parseHeuristics(from: text)
                result.ocrText = text
                return result
            }
            return .empty
        }
    }

    private static func extractAIData(
        from images: [CaptureImageItem],
        ocrText: String
    ) async throws -> (ExtractedSessionData, String, String) {
        if let cloud = resolvedCloudProvider() {
            switch cloud {
            case .openAI:
                let (data, raw) = try await OpenAIService.extractSessionData(from: images, ocrText: ocrText)
                return (data, raw, ExtractionEngine.openAI.displayName)
            case .claude:
                let (data, raw) = try await ClaudeService.extractSessionData(from: images, ocrText: ocrText)
                return (data, raw, ExtractionEngine.claude.displayName)
            }
        }

        if #available(iOS 26.0, *), AppleIntelligenceService.isAvailable {
            do {
                let (data, raw) = try await AppleIntelligenceService.extractSessionData(
                    from: images,
                    ocrText: ocrText
                )
                return (data, raw, ExtractionEngine.appleIntelligence.displayName)
            } catch {
                ErrorLogger.log("Apple Intelligence failed, using OCR only", category: .extraction, error: error)
            }
        }

        return (ExtractedSessionData(), "", ExtractionEngine.visionOCR.displayName)
    }

    private static func buildSessionOutput(
        data: ExtractedSessionData,
        aiRaw: String,
        fusion: ExtractionFusionResult,
        images: [CaptureImageItem],
        engineName: String
    ) -> SessionExtractionOutput {
        var extracted = data
        let validation = ExtractionValidator.validateSession(extracted)
        let sources = FieldSourceTracker.attributeFields(data: extracted, images: images)
        var fieldMetadata = ConfidenceEngine.buildFieldMetadata(
            data: extracted,
            sources: sources,
            warnings: validation.warnings
        )
        applyFusionConfidence(fusion: fusion, to: &fieldMetadata)

        ConfidenceEngine.applyOverallConfidence(to: &extracted, fieldMetadata: fieldMetadata)

        fieldMetadata = ConfidenceEngine.buildFieldMetadata(
            data: extracted,
            sources: sources,
            warnings: validation.warnings
        )
        applyFusionConfidence(fusion: fusion, to: &fieldMetadata)

        let missing = ConfidenceEngine.detectMissingFields(in: extracted).map(\.displayName)
        var allWarnings = validation.warnings + validation.errors + fusion.notes
        if !missing.isEmpty {
            allWarnings.append("Partial extraction — review missing fields: \(missing.joined(separator: ", ")).")
        }

        let enrichedRaw = buildEnrichedRawResponse(
            extracted: extracted,
            fieldMetadata: fieldMetadata,
            fusion: fusion,
            warnings: allWarnings,
            aiRaw: aiRaw,
            engineName: engineName
        )

        return SessionExtractionOutput(
            data: extracted,
            rawResponse: enrichedRaw,
            fieldMetadata: fieldMetadata,
            warnings: allWarnings,
            engineName: engineName
        )
    }

    private static func applyFusionConfidence(
        fusion: ExtractionFusionResult,
        to fieldMetadata: inout [ExtractionFieldKey: ExtractionFieldMetadata]
    ) {
        for (field, source) in fusion.fieldSources {
            guard var metadata = fieldMetadata[field] else { continue }
            switch source {
            case .ocr:
                metadata.confidence = min(1.0, metadata.confidence + 0.05)
            case .ai:
                break
            }
            metadata.isUncertain = metadata.confidence > 0 && metadata.confidence < 0.75
            fieldMetadata[field] = metadata
        }
    }

    private static func buildEnrichedRawResponse(
        extracted: ExtractedSessionData,
        fieldMetadata: [ExtractionFieldKey: ExtractionFieldMetadata],
        fusion: ExtractionFusionResult,
        warnings: [String],
        aiRaw: String,
        engineName: String
    ) -> String {
        let sources = fieldMetadata.mapValues { meta -> [String: Any] in
            [
                "confidence": meta.confidence,
                "source": meta.sourceCategory?.title ?? NSNull(),
                "uncertain": meta.isUncertain
            ] as [String: Any]
        }

        let fusionSources = fusion.fieldSources.mapKeys { $0.rawValue }.mapValues(\.rawValue)

        let payload: [String: Any] = [
            "engine": engineName,
            "extracted": (try? JSONSerialization.jsonObject(
                with: SessionExtractionParser.encodeRawResponse(extracted).data(using: .utf8) ?? Data()
            )) ?? [:],
            "field_metadata": sources.mapKeys { $0.rawValue },
            "fusion_sources": fusionSources,
            "fusion_notes": fusion.notes,
            "warnings": warnings,
            "ai_response": aiRaw
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return SessionExtractionParser.encodeRawResponse(extracted)
        }
        return string
    }

    private static func resolvedCloudProvider() -> CloudExtractionProvider? {
        let preferred = CloudExtractionPreferences.preferred
        switch preferred {
        case .openAI:
            if OpenAIService.isConfigured { return .openAI }
            if ClaudeService.isConfigured { return .claude }
        case .claude:
            if ClaudeService.isConfigured { return .claude }
            if OpenAIService.isConfigured { return .openAI }
        }
        return nil
    }
}

private extension Dictionary {
    func mapKeys<T: Hashable>(_ transform: (Key) -> T) -> [T: Value] {
        Dictionary<T, Value>(uniqueKeysWithValues: map { (transform($0.key), $0.value) })
    }
}
