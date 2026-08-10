import CryptoKit
import Foundation
import Security

enum DataProtectionError: LocalizedError {
    case keyUnavailable
    case encryptionFailed
    case decryptionFailed
    case invalidPayload

    var errorDescription: String? {
        switch self {
        case .keyUnavailable: "Encryption key is unavailable."
        case .encryptionFailed: "Failed to encrypt sensitive data."
        case .decryptionFailed: "Failed to decrypt sensitive data."
        case .invalidPayload: "Encrypted payload is invalid."
        }
    }
}

enum DataProtectionService {
    private static let encryptedPrefix = "enc:v1:"
    private static let keyService = "sg.tsc.EVAi2.encryption"
    private static let keyAccount = "data_protection_key"

    static func encrypt(_ plaintext: String) throws -> String {
        guard !plaintext.isEmpty else { return plaintext }
        let key = try encryptionKey()
        let sealed = try AES.GCM.seal(Data(plaintext.utf8), using: key)
        guard let combined = sealed.combined else {
            throw DataProtectionError.encryptionFailed
        }
        return encryptedPrefix + combined.base64EncodedString()
    }

    static func decrypt(_ value: String) throws -> String {
        guard value.hasPrefix(encryptedPrefix) else { return value }
        let encoded = String(value.dropFirst(encryptedPrefix.count))
        guard let combined = Data(base64Encoded: encoded) else {
            throw DataProtectionError.invalidPayload
        }
        let key = try encryptionKey()
        let sealed = try AES.GCM.SealedBox(combined: combined)
        let decrypted = try AES.GCM.open(sealed, using: key)
        guard let string = String(data: decrypted, encoding: .utf8) else {
            throw DataProtectionError.decryptionFailed
        }
        return string
    }

    static func isEncrypted(_ value: String) -> Bool {
        value.hasPrefix(encryptedPrefix)
    }

    private static func encryptionKey() throws -> SymmetricKey {
        if let existing = loadKeyFromKeychain() {
            return SymmetricKey(data: existing)
        }
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            throw DataProtectionError.keyUnavailable
        }
        let keyData = Data(bytes)
        try saveKeyToKeychain(keyData)
        return SymmetricKey(data: keyData)
    }

    private static func loadKeyFromKeychain() -> Data? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keyService,
            kSecAttrAccount as String: keyAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return data
    }

    private static func saveKeyToKeychain(_ data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keyService,
            kSecAttrAccount as String: keyAccount
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw DataProtectionError.keyUnavailable
        }
    }
}
