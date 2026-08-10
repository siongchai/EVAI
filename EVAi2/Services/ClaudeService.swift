import Foundation

enum ClaudeConstants {
    /// Vision-capable models, newest first. If the primary ID is unavailable on an
    /// account, the service tries the next entry automatically.
    static let visionModels = [
        "claude-sonnet-4-6",
        "claude-sonnet-4-5-20250929",
        "claude-3-5-sonnet-20241022"
    ]

    static let model = visionModels[0]
    static let messagesURL = URL(string: "https://api.anthropic.com/v1/messages")!
    static let apiVersion = "2023-06-01"
    static let requestTimeout: TimeInterval = 120
    static let maxRetries = 3
    static let retryBaseDelay: TimeInterval = 1.5
}

enum ClaudeServiceError: LocalizedError {
    case missingAPIKey
    case noImages
    case imageTooLarge
    case networkFailure(String)
    case timeout
    case invalidJSON
    case malformedResponse
    case rateLimited(retryAfter: TimeInterval?)
    case modelUnavailable(String)
    case apiError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "Anthropic API key is not configured. Add your key in Profile → AI Settings."
        case .noImages:
            "No images were provided for extraction."
        case .imageTooLarge:
            "One or more images exceed the upload size limit."
        case .networkFailure(let message):
            "Network request failed: \(message)"
        case .timeout:
            "The Claude request timed out. Please try again."
        case .invalidJSON:
            "Claude returned invalid JSON."
        case .malformedResponse:
            "Received an unexpected response from Claude."
        case .rateLimited(let retryAfter):
            if let retryAfter {
                "Claude rate limit reached. Retry in \(Int(retryAfter)) seconds."
            } else {
                "Claude rate limit reached. Please try again shortly."
            }
        case .modelUnavailable(let model):
            "Claude model \"\(model)\" is not available on your Anthropic account."
        case .apiError(_, let message):
            message
        }
    }
}

private struct ClaudeMessageRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: [ClaudeContentBlock]
    }

    let model: String
    let maxTokens: Int
    let temperature: Double
    let system: String
    let messages: [Message]

    enum CodingKeys: String, CodingKey {
        case model, messages, system, temperature
        case maxTokens = "max_tokens"
    }
}

private enum ClaudeContentBlock: Encodable {
    case text(String)
    case image(base64: String)

    enum CodingKeys: String, CodingKey {
        case type, text, source
    }

    struct ImageSource: Encodable {
        let type: String
        let mediaType: String
        let data: String

        enum CodingKeys: String, CodingKey {
            case type, data
            case mediaType = "media_type"
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let value):
            try container.encode("text", forKey: .type)
            try container.encode(value, forKey: .text)
        case .image(let base64):
            try container.encode("image", forKey: .type)
            try container.encode(
                ImageSource(type: "base64", mediaType: "image/jpeg", data: base64),
                forKey: .source
            )
        }
    }
}

private struct ClaudeMessageResponse: Decodable {
    struct ContentBlock: Decodable {
        let type: String
        let text: String?
    }

    let content: [ContentBlock]
}

enum ClaudeService {
    static var isConfigured: Bool {
        SecureKeyManager.hasAPIKey(for: .claude)
    }

    static func extractSessionData(
        from images: [CaptureImageItem],
        ocrText: String = ""
    ) async throws -> (ExtractedSessionData, String) {
        guard isConfigured else {
            throw ClaudeServiceError.missingAPIKey
        }
        guard !images.isEmpty else {
            throw ClaudeServiceError.noImages
        }

        let preparedImages = try await prepareImages(images)
        let rawContent = try await sendWithRetry(
            images: preparedImages,
            ocrText: ocrText
        )
        let extracted = try SessionExtractionParser.parseJSON(from: rawContent)
        return (extracted, rawContent)
    }

    private static func prepareImages(_ images: [CaptureImageItem]) async throws -> [CaptureImageItem] {
        try await Task.detached(priority: .userInitiated) {
            do {
                return try images.map { image in
                    let optimized = try ImageProcessor.optimizeForOpenAI(image.bestAvailableImageData())
                    return CaptureImageItem(
                        id: image.id,
                        category: image.category,
                        imageData: optimized,
                        thumbnail: image.thumbnail
                    )
                }
            } catch ImageProcessorError.imageTooLarge {
                throw ClaudeServiceError.imageTooLarge
            }
        }.value
    }

    private static func buildPayload(
        images: [CaptureImageItem],
        ocrText: String,
        model: String
    ) throws -> ClaudeMessageRequest {
        var content: [ClaudeContentBlock] = [
            .text(PromptManager.buildVisionPrompt(for: images, ocrText: ocrText))
        ]

        for (index, image) in images.enumerated() {
            content.append(.text("Image \(index + 1):"))
            let base64 = ImageProcessor.convertToBase64(image.imageData)
            content.append(.image(base64: base64))
        }

        return ClaudeMessageRequest(
            model: model,
            maxTokens: 2048,
            temperature: 0,
            system: """
            You extract structured EV charging session data from user-provided screenshots.
            Return ONLY a single JSON object matching the schema in the user message.
            Use null for unavailable fields. Do not guess or invent values.
            Numeric fields must have units and symbols removed.
            """,
            messages: [.init(role: "user", content: content)]
        )
    }

    private static func sendWithRetry(
        images: [CaptureImageItem],
        ocrText: String
    ) async throws -> String {
        var lastError: Error?

        for model in ClaudeConstants.visionModels {
            let payload: ClaudeMessageRequest
            do {
                payload = try buildPayload(images: images, ocrText: ocrText, model: model)
            } catch {
                throw error
            }

            for attempt in 0..<ClaudeConstants.maxRetries {
                do {
                    return try await sendRequest(payload: payload)
                } catch let error as ClaudeServiceError {
                    lastError = error
                    if case .modelUnavailable = error {
                        break
                    }
                    if case .rateLimited(let retryAfter) = error, attempt < ClaudeConstants.maxRetries - 1 {
                        let delay = retryAfter ?? ClaudeConstants.retryBaseDelay * pow(2, Double(attempt))
                        try await Task.sleep(for: .seconds(delay))
                        continue
                    }
                    if case .networkFailure = error, attempt < ClaudeConstants.maxRetries - 1 {
                        try await Task.sleep(for: .seconds(ClaudeConstants.retryBaseDelay * pow(2, Double(attempt))))
                        continue
                    }
                    if case .timeout = error, attempt < ClaudeConstants.maxRetries - 1 {
                        try await Task.sleep(for: .seconds(ClaudeConstants.retryBaseDelay))
                        continue
                    }
                    throw error
                } catch {
                    lastError = error
                    if attempt < ClaudeConstants.maxRetries - 1 {
                        try await Task.sleep(for: .seconds(ClaudeConstants.retryBaseDelay))
                        continue
                    }
                    throw ClaudeServiceError.networkFailure(error.localizedDescription)
                }
            }
        }

        throw lastError ?? ClaudeServiceError.malformedResponse
    }

    private static func sendRequest(payload: ClaudeMessageRequest) async throws -> String {
        guard let apiKey = SecureKeyManager.retrieveAPIKey(for: .claude) else {
            throw ClaudeServiceError.missingAPIKey
        }

        var request = URLRequest(url: ClaudeConstants.messagesURL)
        request.httpMethod = "POST"
        request.timeoutInterval = ClaudeConstants.requestTimeout
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(ClaudeConstants.apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)
        if let body = request.httpBody {
            RequestSigner.applySecurityHeaders(to: &request, body: body)
        }

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            throw ClaudeServiceError.timeout
        } catch {
            throw ClaudeServiceError.networkFailure(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeServiceError.malformedResponse
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 429:
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
            throw ClaudeServiceError.rateLimited(retryAfter: retryAfter)
        default:
            let message = parseErrorMessage(from: data, statusCode: httpResponse.statusCode)
            if isModelUnavailable(statusCode: httpResponse.statusCode, message: message, model: payload.model) {
                throw ClaudeServiceError.modelUnavailable(payload.model)
            }
            throw ClaudeServiceError.apiError(
                statusCode: httpResponse.statusCode,
                message: message
            )
        }

        let decoded = try JSONDecoder().decode(ClaudeMessageResponse.self, from: data)
        guard let text = decoded.content.first(where: { $0.type == "text" })?.text,
              !text.isEmpty else {
            throw ClaudeServiceError.malformedResponse
        }

        return text
    }

    private static func parseErrorMessage(from data: Data, statusCode: Int) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let error = json["error"] as? [String: Any] {
                if let message = error["message"] as? String, !message.isEmpty {
                    return humanizeAnthropicMessage(message)
                }
                if let type = error["type"] as? String {
                    return "Claude API error (\(type))."
                }
            }
            if let message = json["message"] as? String, !message.isEmpty {
                return humanizeAnthropicMessage(message)
            }
        }
        return "Claude request failed with status \(statusCode)."
    }

    private static func humanizeAnthropicMessage(_ message: String) -> String {
        if message.hasPrefix("model:") {
            let model = message.replacingOccurrences(of: "model:", with: "").trimmingCharacters(in: .whitespaces)
            return "The Claude model \"\(model)\" is not available. The app will try another supported model automatically."
        }
        return message
    }

    private static func isModelUnavailable(statusCode: Int, message: String, model: String) -> Bool {
        if statusCode == 404 { return true }
        let lower = message.lowercased()
        return lower.contains("model") && (
            lower.contains("not found")
            || lower.contains("not_found")
            || lower.contains("does not exist")
            || lower.contains("invalid")
            || message.hasPrefix("model:")
            || message.contains(model)
        )
    }
}
