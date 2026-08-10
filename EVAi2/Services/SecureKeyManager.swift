import Foundation
import Security

enum APIKeyProvider: String, CaseIterable {
    case openAI
    case claude

    var keychainService: String {
        switch self {
        case .openAI: "sg.tsc.EVAi2.openai"
        case .claude: "sg.tsc.EVAi2.claude"
        }
    }

    var cloudProvider: CloudExtractionProvider {
        switch self {
        case .openAI: .openAI
        case .claude: .claude
        }
    }
}

enum SecureKeyError: LocalizedError {
    case emptyKey
    case storageFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .emptyKey:
            "API key cannot be empty."
        case .storageFailed(let status):
            "Unable to access secure storage (code \(status))."
        }
    }
}

enum SecureKeyManager {
    private static let account = "api_key"

    static var hasAPIKey: Bool {
        hasAPIKey(for: .openAI)
    }

    static var hasAnyCloudKey: Bool {
        APIKeyProvider.allCases.contains { hasAPIKey(for: $0) }
    }

    static func hasAPIKey(for provider: APIKeyProvider) -> Bool {
        retrieveAPIKey(for: provider)?.isEmpty == false
    }

    static func saveAPIKey(_ key: String, provider: APIKeyProvider) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SecureKeyError.emptyKey
        }

        let data = Data(trimmed.utf8)
        let baseQuery = baseQuery(for: provider)
        SecItemDelete(baseQuery as CFDictionary)

        var attributes = baseQuery
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw SecureKeyError.storageFailed(status)
        }
    }

    static func saveAPIKey(_ key: String) throws {
        try saveAPIKey(key, provider: .openAI)
    }

    static func retrieveAPIKey(for provider: APIKeyProvider) -> String? {
        var query = baseQuery(for: provider)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    static func retrieveAPIKey() -> String? {
        retrieveAPIKey(for: .openAI)
    }

    static func deleteAPIKey(for provider: APIKeyProvider) throws {
        let status = SecItemDelete(baseQuery(for: provider) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SecureKeyError.storageFailed(status)
        }
    }

    static func deleteAPIKey() throws {
        try deleteAPIKey(for: .openAI)
    }

    static func deleteAllAPIKeys() throws {
        for provider in APIKeyProvider.allCases {
            try deleteAPIKey(for: provider)
        }
    }

    static func retrievePreferredCloudAPIKey() -> (CloudExtractionProvider, String)? {
        let preferred = CloudExtractionPreferences.preferred
        if let key = retrieveAPIKey(for: preferred.apiKeyProvider), !key.isEmpty {
            return (preferred, key)
        }
        for provider in APIKeyProvider.allCases where provider.cloudProvider != preferred {
            if let key = retrieveAPIKey(for: provider), !key.isEmpty {
                return (provider.cloudProvider, key)
            }
        }
        return nil
    }

    private static func baseQuery(for provider: APIKeyProvider) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: provider.keychainService,
            kSecAttrAccount as String: account
        ]
    }
}

private extension CloudExtractionProvider {
    var apiKeyProvider: APIKeyProvider {
        switch self {
        case .openAI: .openAI
        case .claude: .claude
        }
    }
}
