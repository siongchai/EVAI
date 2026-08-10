import Foundation

enum CloudExtractionProvider: String, CaseIterable, Codable, Identifiable {
    case openAI
    case claude

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openAI: "OpenAI GPT-4o"
        case .claude: "Claude Sonnet 4.6"
        }
    }

    var keyPlaceholder: String {
        switch self {
        case .openAI: "sk-..."
        case .claude: "sk-ant-..."
        }
    }

    var keyHelpText: String {
        switch self {
        case .openAI:
            "Get a key at platform.openai.com. Stored securely in the device Keychain."
        case .claude:
            "Get a key at console.anthropic.com. Stored securely in the device Keychain."
        }
    }
}

enum CloudExtractionPreferences {
    private static let providerKey = "evai.ai.cloudProvider"

    static var preferred: CloudExtractionProvider {
        get {
            guard let raw = UserDefaults.standard.string(forKey: providerKey),
                  let provider = CloudExtractionProvider(rawValue: raw) else {
                return .openAI
            }
            return provider
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: providerKey)
        }
    }
}
