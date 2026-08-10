import Foundation

enum PromptManager {
    private static let customPromptKey = "evai.ai.promptOverride"

    static var defaultPrompt: String {
        SessionExtractionParser.extractionPrompt
    }

    static var customPromptOverride: String {
        get { UserDefaults.standard.string(forKey: customPromptKey) ?? "" }
        set {
            if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                UserDefaults.standard.removeObject(forKey: customPromptKey)
            } else {
                UserDefaults.standard.set(newValue, forKey: customPromptKey)
            }
        }
    }

    static var effectivePrompt: String {
        let override = customPromptOverride.trimmingCharacters(in: .whitespacesAndNewlines)
        return override.isEmpty ? defaultPrompt : override
    }

    /// Prompt used by OCR/text-only engines (Apple Intelligence). Falls back to
    /// the dedicated text-extraction prompt unless the user set a custom one.
    static var effectiveOCRPrompt: String {
        let override = customPromptOverride.trimmingCharacters(in: .whitespacesAndNewlines)
        return override.isEmpty ? SessionExtractionParser.ocrExtractionPrompt : override
    }

    static var isUsingDefaultPrompt: Bool {
        customPromptOverride.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func restoreDefault() {
        customPromptOverride = ""
    }

    static func saveCustomPrompt(_ prompt: String) {
        customPromptOverride = prompt
    }

    static func buildVisionPrompt(for images: [CaptureImageItem], ocrText: String = "") -> String {
        var sections: [String] = [
            effectivePrompt,
            """
            You will receive \(images.count) image(s) in upload order. Read every number directly from the pixels — zoom into small dashboard SOC digits, app graph timestamps, and receipt totals.
            """
        ]

        let trimmedOCR = ocrText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedOCR.isEmpty {
            sections.append("""
            On-device OCR text from the same images is provided below to help you locate values. The OCR may contain mistakes, so the image pixels are the source of truth — use OCR only to cross-check digits you read from the image.

            OCR text:
            \(String(trimmedOCR.prefix(8_000)))
            """)
        }

        sections.append("Return ONLY the JSON object described above, with null for anything not clearly visible.")

        return sections.joined(separator: "\n\n")
    }
}
