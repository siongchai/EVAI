import Foundation
import Vision

struct RecognizedTextLine: Sendable, Equatable {
    let text: String
    /// Normalized Vision coordinates (origin bottom-left).
    let boundingBox: CGRect
}

enum VisionTextExtractionService {
    static func extractCombinedText(from images: [CaptureImageItem]) async throws -> String {
        var sections: [String] = []

        for (index, image) in images.enumerated() {
            let text = try await recognizeText(in: image.bestAvailableImageData())
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            sections.append(
                """
                --- Image \(index + 1) ---
                \(trimmed)
                """
            )
        }

        guard !sections.isEmpty else {
            throw SessionExtractionError.noTextFound
        }

        return sections.joined(separator: "\n\n")
    }

    static func recognizeText(in imageData: Data) async throws -> String {
        let lines = try await recognizeLines(in: imageData)
        return lines.map(\.text).joined(separator: "\n")
    }

    static func recognizeLines(in imageData: Data) async throws -> [RecognizedTextLine] {
        try await Task.detached(priority: .userInitiated) {
            try autoreleasepool {
                guard let cgImage = ImageProcessor.downsampledCGImage(
                    from: imageData,
                    maxDimension: ImageProcessor.ocrMaxDimension
                ) else {
                    return []
                }
                return try performRecognizeLines(on: cgImage)
            }
        }.value
    }

    private static func performRecognizeLines(on cgImage: CGImage) throws -> [RecognizedTextLine] {
        try autoreleasepool {
            var lines: [RecognizedTextLine] = []
            var requestError: Error?

            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    requestError = error
                    return
                }

                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                lines = observations.compactMap { observation in
                    guard let text = observation.topCandidates(1).first?.string else { return nil }
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return nil }
                    return RecognizedTextLine(text: trimmed, boundingBox: observation.boundingBox)
                }
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try handler.perform([request])

            if let requestError {
                throw requestError
            }

            return lines
        }
    }
}
