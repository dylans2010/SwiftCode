import Foundation

enum LLMProvider: String {
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
}

final class LLMService {
    static let shared = LLMService()
    private init() {}

    func streamChat(
        messages: [AIMessage],
        model: String,
        systemPrompt: String,
        onToken: @escaping @Sendable (String) async -> Void
    ) async throws {
        let providerRaw = UserDefaults.standard.string(forKey: "ai.selectedProvider")
        let provider = LLMProvider.from(rawValue: providerRaw)

        switch provider {
        case .openRouter:
            try await OpenRouterService.shared.streamChat(
                messages: messages,
                model: model,
                systemPrompt: systemPrompt,
                onToken: onToken
            )
        case .anthropic, .openai, .google, .mistral, .qwen:
            try await performDirectStreamChat(
                provider: provider,
                messages: messages,
                model: model,
                systemPrompt: systemPrompt,
                onToken: onToken
            )
        }
    }

    private func performDirectStreamChat(
        provider: LLMProvider,
        messages: [AIMessage],
        model: String,
        systemPrompt: String,
        onToken: @escaping @Sendable (String) async -> Void
    ) async throws {
        guard let apiKey = KeychainService.shared.get(forKey: provider.keychainKey), !apiKey.isEmpty else {
            throw NSError(domain: "LLMService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Missing API Key for \(provider.rawValue). Please add it in Settings."])
        }

        switch provider {
        case .openai:
            try await performOpenAICompatibleStreaming(baseURL: "https://api.openai.com/v1", apiKey: apiKey, messages: messages, model: model, systemPrompt: systemPrompt, onToken: onToken)
        case .mistral:
            try await performOpenAICompatibleStreaming(baseURL: "https://api.mistral.ai/v1", apiKey: apiKey, messages: messages, model: model, systemPrompt: systemPrompt, onToken: onToken)
        case .qwen:
            try await performOpenAICompatibleStreaming(baseURL: "https://dashscope.aliyuncs.com/compatible-mode/v1", apiKey: apiKey, messages: messages, model: model, systemPrompt: systemPrompt, onToken: onToken)
        case .anthropic:
            try await performAnthropicStreaming(apiKey: apiKey, messages: messages, model: model, systemPrompt: systemPrompt, onToken: onToken)
        case .google:
            try await performGeminiStreaming(apiKey: apiKey, messages: messages, model: model, systemPrompt: systemPrompt, onToken: onToken)
        case .openRouter:
            break // Handled in streamChat
        }
    }

    private func performGeminiStreaming(
        apiKey: String,
        messages: [AIMessage],
        model: String,
        systemPrompt: String,
        onToken: @escaping @Sendable (String) async -> Void
    ) async throws {
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):streamGenerateContent?alt=sse&key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var contents: [[String: Any]] = []
        contents.append(["role": "user", "parts": [["text": "System Instruction: \(systemPrompt)"]]])

        for msg in messages {
            let role = msg.role == "assistant" ? "model" : "user"
            contents.append(["role": role, "parts": [["text": msg.content]]])
        }

        let body: [String: Any] = ["contents": contents]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (stream, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "LLMService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])
        }

        if httpResponse.statusCode != 200 {
            var errorBody = ""
            for try await line in stream.lines {
                errorBody += line
                if errorBody.count > 1000 { break }
            }
            throw NSError(domain: "LLMService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Gemini API Error \(httpResponse.statusCode): \(errorBody)"])
        }

        for try await line in stream.lines {
            guard line.hasPrefix("data: ") else { continue }
            let jsonString = String(line.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !jsonString.isEmpty else { continue }

            guard let data = jsonString.data(using: .utf8),
                  let chunk = try? JSONDecoder().decode(GeminiStreamChunk.self, from: data),
                  let token = chunk.candidates?.first?.content?.parts?.first?.text else { continue }

            await onToken(token)
        }
    }

    private func performAnthropicStreaming(
        apiKey: String,
        messages: [AIMessage],
        model: String,
        systemPrompt: String,
        onToken: @escaping @Sendable (String) async -> Void
    ) async throws {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let apiMessages = messages.map { ["role": $0.role, "content": $0.content] }

        let body: [String: Any] = [
            "model": model,
            "system": systemPrompt,
            "messages": apiMessages,
            "max_tokens": 4096,
            "stream": true
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (stream, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "LLMService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])
        }

        if httpResponse.statusCode != 200 {
            var errorBody = ""
            for try await line in stream.lines {
                errorBody += line
                if errorBody.count > 1000 { break }
            }
            throw NSError(domain: "LLMService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Anthropic API Error \(httpResponse.statusCode): \(errorBody)"])
        }

        for try await line in stream.lines {
            guard line.hasPrefix("data: ") else { continue }
            let jsonString = String(line.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !jsonString.isEmpty else { continue }

            guard let data = jsonString.data(using: .utf8),
                  let event = try? JSONDecoder().decode(AnthropicEvent.self, from: data) else { continue }

            if event.type == "content_block_delta", let delta = event.delta, delta.type == "text_delta" {
                await onToken(delta.text ?? "")
            }
        }
    }

    private func performOpenAICompatibleStreaming(
        baseURL: String,
        apiKey: String,
        messages: [AIMessage],
        model: String,
        systemPrompt: String,
        onToken: @escaping @Sendable (String) async -> Void
    ) async throws {
        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var apiMessages: [[String: String]] = [
            ["role": "system", "content": systemPrompt]
        ]
        apiMessages += messages.map { ["role": $0.role, "content": $0.content] }

        let body: [String: Any] = [
            "model": model,
            "messages": apiMessages,
            "stream": true
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (stream, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "LLMService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])
        }

        if httpResponse.statusCode != 200 {
            var errorBody = ""
            for try await line in stream.lines {
                errorBody += line
                if errorBody.count > 1000 { break }
            }
            throw NSError(domain: "LLMService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API Error \(httpResponse.statusCode): \(errorBody)"])
        }

        for try await line in stream.lines {
            guard line.hasPrefix("data: ") else { continue }
            let jsonString = String(line.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
            guard jsonString != "[DONE]" && !jsonString.isEmpty else { break }

            guard let data = jsonString.data(using: .utf8),
                  let chunk = try? JSONDecoder().decode(OpenAIStreamChunk.self, from: data),
                  let token = chunk.choices.first?.delta.content else { continue }

            await onToken(token)
        }
    }
}

private struct OpenAIStreamChunk: Decodable {
    struct Choice: Decodable {
        struct Delta: Decodable {
            let content: String?
        }
        let delta: Delta
    }
    let choices: [Choice]
}

private struct AnthropicEvent: Decodable {
    let type: String
    let delta: AnthropicDelta?

    struct AnthropicDelta: Decodable {
        let type: String?
        let text: String?
    }
}

private struct GeminiStreamChunk: Decodable {
    struct Candidate: Decodable {
        struct Content: Decodable {
            struct Part: Decodable {
                let text: String?
            }
            let parts: [Part]?
        }
        let content: Content?
    }
    let candidates: [Candidate]?
}
