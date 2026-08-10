import CryptoKit
import Foundation

enum RequestSigner {
    static func sign(body: Data, timestamp: TimeInterval = Date().timeIntervalSince1970) -> String {
        let key = signingKey()
        let payload = "\(Int(timestamp))." + body.base64EncodedString()
        let signature = HMAC<SHA256>.authenticationCode(for: Data(payload.utf8), using: key)
        return Data(signature).base64EncodedString()
    }

    static func applySecurityHeaders(to request: inout URLRequest, body: Data) {
        let timestamp = Date().timeIntervalSince1970
        request.setValue(String(Int(timestamp)), forHTTPHeaderField: "X-EVAi-Timestamp")
        request.setValue(sign(body: body, timestamp: timestamp), forHTTPHeaderField: "X-EVAi-Signature")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "X-EVAi-Idempotency-Key")
    }

    private static func signingKey() -> SymmetricKey {
        if let (_, apiKey) = SecureKeyManager.retrievePreferredCloudAPIKey() {
            let derived = SHA256.hash(data: Data("evai-sign:\(apiKey)".utf8))
            return SymmetricKey(data: Data(derived))
        }
        let fallback = SHA256.hash(data: Data("evai-sign:fallback".utf8))
        return SymmetricKey(data: Data(fallback))
    }
}
