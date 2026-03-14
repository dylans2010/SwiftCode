import Foundation

enum LLMProvider: String, CaseIterable {
    case openRouter = "OpenRouter"
    case anthropic = "Anthropic"
    case openai = "OpenAI"
    case google = "Gemini"
    case mistral = "Mistral"
    case qwen = "Qwen"

    static func from(rawValue: String?) -> LLMProvider {
        guard let rawValue = rawValue else { return .openRouter }
        return LLMProvider(rawValue: rawValue) ?? .openRouter
    }

    var keychainKey: String {
        switch self {
        case .openRouter: return KeychainService.openRouterAPIKey
        case .anthropic: return "anthropic_api_key"
        case .openai: return "openai_api_key"
        case .google: return "gemini_api_key"
        case .mistral: return "mistral_api_key"
        case .qwen: return "qwen_api_key"
        }
    }

    var baseURL: URL {
        switch self {
        case .openRouter: return URL(string: "https://openrouter.ai/api/v1")!
        case .anthropic: return URL(string: "https://api.anthropic.com/v1")!
        case .openai: return URL(string: "https://api.openai.com/v1")!
        case .google: return URL(string: "https://generativelanguage.googleapis.com/v1beta")!
        case .mistral: return URL(string: "https://api.mistral.ai/v1")!
        case .qwen: return URL(string: "https://dashscope.aliyuncs.com/compatible-mode/v1")!
        }
    }
}

enum LLMError: LocalizedError {
    case invalidKey
    case rateLimited
    case networkError(String)
    case modelNotFound
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidKey: return "invalid_key"
        case .rateLimited: return "rate_limited"
        case .networkError(let desc): return "network_error: \(desc)"
        case .modelNotFound: return "model_not_found"
        case .unknown(let desc): return desc
        }
    }
}

struct LLMResponse {
    let modelName: String
    let completionText: String
    let tokenUsage: TokenUsage?
    let latency: TimeInterval

    struct TokenUsage {
        let promptTokens: Int
        let completionTokens: Int
        let totalTokens: Int
    }
}

final class LLMService {
    static let shared = LLMService()
    private init() {}

    // MARK: - Core Methods

    func validateAPIKey(provider: LLMProvider, key: String) async throws -> Bool {
        do {
            // For most providers, fetching models is a good way to validate
            _ = try await fetchAvailableModels(provider: provider, key: key)
            return true
        } catch {
            throw error
        }
    }

    func fetchAvailableModels(provider: LLMProvider, key: String) async throws -> [String] {
        let url = provider.baseURL.appendingPathComponent("models")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        setupHeaders(for: &request, provider: provider, key: key)

        let (data, response) = try await URLSession.shared.data(for: request)
        try handleHTTPError(response, data: data)

        // Anthropic doesn't have a standard /models endpoint like OpenAI
        if provider == .anthropic {
            return ["claude-3-5-sonnet-20240620", "claude-3-opus-20240229", "claude-3-haiku-20240307"]
        }

        let decoded = try JSONDecoder().decode(ModelListResponse.self, from: data)
        return decoded.data.map { $0.id }
    }

    func sendChatRequest(model: String, messages: [AIMessage], key: String? = nil) async throws -> LLMResponse {
        let providerRaw = UserDefaults.standard.string(forKey: "ai.selectedProvider")
        let provider = LLMProvider.from(rawValue: providerRaw)
        let actualKey = key ?? KeychainService.shared.get(forKey: provider.keychainKey) ?? ""

        guard !actualKey.isEmpty else { throw LLMError.invalidKey }

        let startTime = Date()
        let endpoint = provider == .anthropic ? "messages" : "chat/completions"
        let url = provider.baseURL.appendingPathComponent(endpoint)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        setupHeaders(for: &request, provider: provider, key: actualKey)

        let body = try buildRequestBody(provider: provider, model: model, messages: messages, stream: false)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try handleHTTPError(response, data: data)

        let latency = Date().timeIntervalSince(startTime)

        if provider == .anthropic {
            let decoded = try JSONDecoder().decode(AnthropicResponse.self, from: data)
            return LLMResponse(
                modelName: decoded.model,
                completionText: decoded.content.first?.text ?? "",
                tokenUsage: LLMResponse.TokenUsage(
                    promptTokens: decoded.usage.input_tokens,
                    completionTokens: decoded.usage.output_tokens,
                    totalTokens: decoded.usage.input_tokens + decoded.usage.output_tokens
                ),
                latency: latency
            )
        } else {
            let decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
            return LLMResponse(
                modelName: decoded.model,
                completionText: decoded.choices.first?.message.content ?? "",
                tokenUsage: decoded.usage.map { LLMResponse.TokenUsage(promptTokens: $0.prompt_tokens, completionTokens: $0.completion_tokens, totalTokens: $0.total_tokens) },
                latency: latency
            )
        }
    }

    func measureLatency(provider: LLMProvider, key: String) async throws -> TimeInterval {
        let startTime = Date()
        // Simple validation or model fetch to measure latency
        _ = try await fetchAvailableModels(provider: provider, key: key)
        return Date().timeIntervalSince(startTime)
    }

    func streamChat(
        messages: [AIMessage],
        model: String,
        systemPrompt: String,
        onToken: @escaping @Sendable (String) async -> Void
    ) async throws {
        let providerRaw = UserDefaults.standard.string(forKey: "ai.selectedProvider")
        let provider = LLMProvider.from(rawValue: providerRaw)

        if provider == .openRouter {
            try await OpenRouterService.shared.streamChat(
                messages: messages,
                model: model,
                systemPrompt: systemPrompt,
                onToken: onToken
            )
            return
        }

        let key = KeychainService.shared.get(forKey: provider.keychainKey) ?? ""
        guard !key.isEmpty else { throw LLMError.invalidKey }

        let endpoint = provider == .anthropic ? "messages" : "chat/completions"
        let url = provider.baseURL.appendingPathComponent(endpoint)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        setupHeaders(for: &request, provider: provider, key: key)

        var allMessages = messages
        if !systemPrompt.isEmpty && provider != .anthropic {
             // For OpenAI, system prompt is a message
             // We'll handle it in buildRequestBody
        }

        let body = try buildRequestBody(provider: provider, model: model, messages: messages, systemPrompt: systemPrompt, stream: true)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (stream, response) = try await URLSession.shared.bytes(for: request)
        try handleHTTPError(response, data: nil)

        for try await line in stream.lines {
            guard line.hasPrefix("data: ") else { continue }
            let jsonString = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            guard jsonString != "[DONE]" else { break }

            if let data = jsonString.data(using: .utf8) {
                if provider == .anthropic {
                    if let chunk = try? JSONDecoder().decode(AnthropicStreamChunk.self, from: data),
                       let token = chunk.delta?.text {
                        await onToken(token)
                    }
                } else {
                    if let chunk = try? JSONDecoder().decode(ChatCompletionChunk.self, from: data),
                       let token = chunk.choices.first?.delta.content {
                        await onToken(token)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func setupHeaders(for request: inout URLRequest, provider: LLMProvider, key: String) {
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        switch provider {
        case .anthropic:
            request.setValue(key, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        case .google:
            request.url = request.url?.appending(queryItems: [URLQueryItem(name: "key", value: key)])
        default:
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
    }

    private func buildRequestBody(provider: LLMProvider, model: String, messages: [AIMessage], systemPrompt: String = "", stream: Bool) throws -> [String: Any] {
        var body: [String: Any] = [
            "model": model,
            "stream": stream
        ]

        if provider == .anthropic {
            if !systemPrompt.isEmpty {
                body["system"] = systemPrompt
            }
            body["messages"] = messages.map { ["role": $0.role, "content": $0.content] }
            body["max_tokens"] = 4096
        } else {
            var apiMessages: [[String: String]] = []
            if !systemPrompt.isEmpty {
                apiMessages.append(["role": "system", "content": systemPrompt])
            }
            apiMessages += messages.map { ["role": $0.role, "content": $0.content] }
            body["messages"] = apiMessages
        }

        return body
    }

    private func handleHTTPError(_ response: URLResponse, data: Data?) throws {
        guard let httpResponse = response as? HTTPURLResponse else { return }

        if httpResponse.statusCode == 200 { return }

        switch httpResponse.statusCode {
        case 401: throw LLMError.invalidKey
        case 429: throw LLMError.rateLimited
        case 404: throw LLMError.modelNotFound
        default:
            let errorDesc = data.flatMap { String(data: $0, encoding: .utf8) } ?? "HTTP \(httpResponse.statusCode)"
            throw LLMError.networkError(errorDesc)
        }
    }
}

// MARK: - Decodable Structures

private struct ModelListResponse: Decodable {
    struct ModelData: Decodable {
        let id: String
    }
    let data: [ModelData]
}

private struct ChatCompletionResponse: Decodable {
    let model: String
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
    struct Usage: Decodable {
        let prompt_tokens: Int
        let completion_tokens: Int
        let total_tokens: Int
    }
    let usage: Usage?
}

private struct ChatCompletionChunk: Decodable {
    struct Choice: Decodable {
        struct Delta: Decodable {
            let content: String?
        }
        let delta: Delta
    }
    let choices: [Choice]
}

private struct AnthropicResponse: Decodable {
    let model: String
    struct Content: Decodable {
        let text: String
    }
    let content: [Content]
    struct Usage: Decodable {
        let input_tokens: Int
        let output_tokens: Int
    }
    let usage: Usage
}

private struct AnthropicStreamChunk: Decodable {
    struct Delta: Decodable {
        let text: String?
    }
    let delta: Delta?
}
