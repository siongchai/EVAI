import Foundation
import FoundationModels

@available(iOS 26.0, *)
enum AppleIntelligenceService {
    static var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    static var unavailabilityMessage: String? {
        guard !isAvailable else { return nil }

        switch SystemLanguageModel.default.availability {
        case .available:
            return nil
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Apple Intelligence is not enabled. Turn it on in Settings to analyze charging sessions."
        case .unavailable(.deviceNotEligible):
            return "This device does not support Apple Intelligence."
        case .unavailable(.modelNotReady):
            return "Apple Intelligence is still downloading. Try again shortly."
        @unknown default:
            return "Apple Intelligence is currently unavailable on this device."
        }
    }

    static func extractSessionData(
        from images: [CaptureImageItem],
        ocrText precomputedOCR: String = ""
    ) async throws -> (ExtractedSessionData, String) {
        guard isAvailable else {
            throw SessionExtractionError.appleIntelligenceUnavailable(
                unavailabilityMessage ?? "Apple Intelligence is unavailable."
            )
        }

        let ocrText = precomputedOCR.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? try await VisionTextExtractionService.extractCombinedText(from: images)
            : precomputedOCR
        let prompt = SessionExtractionParser.buildPrompt(
            ocrText: ocrText,
            imageCount: images.count
        )

        let session = LanguageModelSession(
            model: .default,
            instructions: """
            You are a precise data-extraction function. You receive OCR text read from EV charging screenshots — you do NOT receive any images, so rely only on the text. Read each value directly from the text, never invent or guess, and use null whenever the text does not clearly contain a value. Numeric fields must have units and symbols removed.
            """
        )

        // Deterministic decoding so the same screenshots yield the same result.
        let options = GenerationOptions(temperature: 0)

        do {
            let response = try await session.respond(
                to: prompt,
                generating: SessionExtractionGenerable.self,
                options: options
            )
            let extracted = response.content.toExtractedSessionData()
            let raw = SessionExtractionParser.encodeRawResponse(extracted)
            return (extracted, raw)
        } catch {
            let fallback = try await session.respond(to: prompt, options: options)
            let extracted = try SessionExtractionParser.parseJSON(from: fallback.content)
            let raw = SessionExtractionParser.encodeRawResponse(extracted)
            return (extracted, raw)
        }
    }
}
