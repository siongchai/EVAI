import Foundation

enum OpenAIConstants {
    static let model = "gpt-4o"
    static let chatCompletionsURL = URL(string: "https://api.openai.com/v1/chat/completions")!
    static let requestTimeout: TimeInterval = 120
    static let maxRetries = 3
    static let retryBaseDelay: TimeInterval = 1.5
}

enum OpenAIServiceError: LocalizedError {
    case missingAPIKey
    case noImages
    case imageTooLarge
    case networkFailure(String)
    case timeout
    case invalidJSON
    case malformedResponse
    case rateLimited(retryAfter: TimeInterval?)
    case apiError(statusCode: Int, message: String)
    case partialExtraction(missingFields: [String])

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "OpenAI API key is not configured. Add your key in Profile → AI Settings."
        case .noImages:
            "No images were provided for extraction."
        case .imageTooLarge:
            "One or more images exceed the upload size limit."
        case .networkFailure(let message):
            "Network request failed: \(message)"
        case .timeout:
            "The OpenAI request timed out. Please try again."
        case .invalidJSON:
            "OpenAI returned invalid JSON."
        case .malformedResponse:
            "Received an unexpected response from OpenAI."
        case .rateLimited(let retryAfter):
            if let retryAfter {
                "OpenAI rate limit reached. Retry in \(Int(retryAfter)) seconds."
            } else {
                "OpenAI rate limit reached. Please try again shortly."
            }
        case .apiError(_, let message):
            message
        case .partialExtraction(let fields):
            "Partial extraction — missing fields: \(fields.joined(separator: ", "))."
        }
    }
}

private struct OpenAIChatRequest: Encodable {
    struct ResponseFormat: Encodable {
        let type: String
    }

    struct Message: Encodable {
        let role: String
        let content: [OpenAIContentPart]
    }

    let model: String
    let messages: [Message]
    let maxTokens: Int
    let responseFormat: ResponseFormat
    let temperature: Double
    let topP: Double
    let seed: Int

    enum CodingKeys: String, CodingKey {
        case model, messages, temperature, seed
        case maxTokens = "max_tokens"
        case responseFormat = "response_format"
        case topP = "top_p"
    }
}

private enum OpenAIContentPart: Encodable {
    case text(String)
    case imageURL(base64: String, detail: String)

    enum CodingKeys: String, CodingKey {
        case type, text
        case imageURL = "image_url"
    }

    struct ImageURL: Encodable {
        let url: String
        let detail: String
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let value):
            try container.encode("text", forKey: .type)
            try container.encode(value, forKey: .text)
        case .imageURL(let base64, let detail):
            try container.encode("image_url", forKey: .type)
            try container.encode(
                ImageURL(url: "data:image/jpeg;base64,\(base64)", detail: detail),
                forKey: .imageURL
            )
        }
    }
}

private struct OpenAIChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String?
        }
        let message: Message
    }
    let choices: [Choice]
}

enum OpenAIService {
    static var isConfigured: Bool {
        SecureKeyManager.hasAPIKey(for: .openAI)
    }

    static func extractSessionData(
        from images: [CaptureImageItem],
        ocrText: String = ""
    ) async throws -> (ExtractedSessionData, String) {
        guard isConfigured else {
            throw OpenAIServiceError.missingAPIKey
        }
        guard !images.isEmpty else {
            throw OpenAIServiceError.noImages
        }

        let preparedImages = try await prepareImages(images)
        let payload = try buildPayload(images: preparedImages, ocrText: ocrText)
        let rawContent = try await sendWithRetry(payload: payload)
        let extracted = try SessionExtractionParser.parseJSON(from: rawContent)
        return (extracted, rawContent)
    }

    static func extractSession(from images: [CaptureImageItem]) async throws -> SessionExtractionOutput {
        try await AIExtractionService.extractSession(from: images)
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
                throw OpenAIServiceError.imageTooLarge
            }
        }.value
    }

    private static func buildPayload(
        images: [CaptureImageItem],
        ocrText: String
    ) throws -> OpenAIChatRequest {
        var content: [OpenAIContentPart] = [
            .text(PromptManager.buildVisionPrompt(for: images, ocrText: ocrText))
        ]

        for (index, image) in images.enumerated() {
            content.append(.text("Image \(index + 1):"))
            let base64 = ImageProcessor.convertToBase64(image.imageData)
            content.append(.imageURL(base64: base64, detail: "high"))
        }

        return OpenAIChatRequest(
            model: OpenAIConstants.model,
            messages: [.init(role: "user", content: content)],
            maxTokens: 1800,
            responseFormat: .init(type: "json_object"),
            temperature: 0,
            topP: 1,
            seed: 7
        )
    }

    private static func sendWithRetry(payload: OpenAIChatRequest) async throws -> String {
        var lastError: Error?

        for attempt in 0..<OpenAIConstants.maxRetries {
            do {
                return try await sendRequest(payload: payload)
            } catch let error as OpenAIServiceError {
                lastError = error
                if case .rateLimited(let retryAfter) = error, attempt < OpenAIConstants.maxRetries - 1 {
                    let delay = retryAfter ?? OpenAIConstants.retryBaseDelay * pow(2, Double(attempt))
                    try await Task.sleep(for: .seconds(delay))
                    continue
                }
                if case .networkFailure = error, attempt < OpenAIConstants.maxRetries - 1 {
                    try await Task.sleep(for: .seconds(OpenAIConstants.retryBaseDelay * pow(2, Double(attempt))))
                    continue
                }
                if case .timeout = error, attempt < OpenAIConstants.maxRetries - 1 {
                    try await Task.sleep(for: .seconds(OpenAIConstants.retryBaseDelay))
                    continue
                }
                throw error
            } catch {
                lastError = error
                if attempt < OpenAIConstants.maxRetries - 1 {
                    try await Task.sleep(for: .seconds(OpenAIConstants.retryBaseDelay))
                    continue
                }
                throw OpenAIServiceError.networkFailure(error.localizedDescription)
            }
        }

        throw lastError ?? OpenAIServiceError.malformedResponse
    }

    private static func sendRequest(payload: OpenAIChatRequest) async throws -> String {
        guard let apiKey = SecureKeyManager.retrieveAPIKey(for: .openAI) else {
            throw OpenAIServiceError.missingAPIKey
        }

        var request = URLRequest(url: OpenAIConstants.chatCompletionsURL)
        request.httpMethod = "POST"
        request.timeoutInterval = OpenAIConstants.requestTimeout
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
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
            throw OpenAIServiceError.timeout
        } catch {
            throw OpenAIServiceError.networkFailure(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIServiceError.malformedResponse
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 429:
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
            throw OpenAIServiceError.rateLimited(retryAfter: retryAfter)
        default:
            throw OpenAIServiceError.apiError(
                statusCode: httpResponse.statusCode,
                message: parseErrorMessage(from: data, statusCode: httpResponse.statusCode)
            )
        }

        let decoded = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content, !content.isEmpty else {
            throw OpenAIServiceError.malformedResponse
        }

        return content
    }

    private static func parseErrorMessage(from data: Data, statusCode: Int) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            return message
        }
        return "OpenAI request failed with status \(statusCode)."
    }
}
