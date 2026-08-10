import Foundation

enum AIConfiguration {
    static var isExtractionAvailable: Bool {
        true
    }

    static var hasCloudKey: Bool {
        SecureKeyManager.hasAnyCloudKey
    }

    static var hasOpenAIKey: Bool {
        SecureKeyManager.hasAPIKey(for: .openAI)
    }

    static var hasClaudeKey: Bool {
        SecureKeyManager.hasAPIKey(for: .claude)
    }

    static var statusMessage: String? {
        AIExtractionService.statusMessage
    }

    static var preferredEngineName: String {
        AIExtractionService.preferredEngine.displayName
    }
}
