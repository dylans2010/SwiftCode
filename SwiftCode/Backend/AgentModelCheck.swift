import Foundation

/// Backend logic for testing AI model configurations and API keys.
///
/// Provides functionality to validate API keys, detect providers, query supported models,
/// and verify that selected models work correctly with test requests.
final class AgentModelCheck {
    static let shared = AgentModelCheck()
    private init() {}

    // MARK: - Test Result Status

    enum TestStatus: String {
        case success
        case invalid_key
        case model_not_found
        case rate_limited
        case network_error
        case unknown_error
    }

    // MARK: - Test Result

    struct TestResult {
        let status: TestStatus
        let message: String
        let supportedModels: [String]
        let responseLatency: TimeInterval?
        let modelCapabilities: [String: Any]?

        init(
            status: TestStatus,
            message: String,
            supportedModels: [String] = [],
            responseLatency: TimeInterval? = nil,
            modelCapabilities: [String: Any]? = nil
        ) {
            self.status = status
            self.message = message
            self.supportedModels = supportedModels
            self.responseLatency = responseLatency
            self.modelCapabilities = modelCapabilities
        }
    }

    // MARK: - Provider Detection

    enum AIProvider: String, CaseIterable {
        case openRouter = "OpenRouter"
        case anthropic = "Anthropic"
        case openai = "OpenAI"
        case google = "Gemini"

        var baseURL: String {
            switch self {
            case .openRouter: return "https://openrouter.ai/api/v1"
            case .anthropic: return "https://api.anthropic.com/v1"
            case .openai: return "https://api.openai.com/v1"
            case .google: return "https://generativelanguage.googleapis.com/v1"
            }
        }

        var defaultModels: [String] {
            switch self {
            case .openRouter:
                return [
                    "anthropic/claude-3.5-sonnet",
                    "openai/gpt-4o",
                    "google/gemini-pro-1.5",
                    "meta-llama/llama-3.1-70b-instruct",
                    "deepseek/deepseek-coder"
                ]
            case .anthropic:
                return [
                    "claude-3-5-sonnet-20240620",
                    "claude-3-opus-20240229",
                    "claude-3-haiku-20240307"
                ]
            case .openai:
                return [
                    "gpt-4o",
                    "gpt-4-turbo",
                    "gpt-3.5-turbo"
                ]
            case .google:
                return [
                    "gemini-1.5-pro",
                    "gemini-1.5-flash",
                    "gemini-1.0-pro"
                ]
            }
        }
    }

    // MARK: - Validate API Key

    /// Validates an API key for a given provider.
    /// - Parameters:
    ///   - apiKey: The API key to validate
    ///   - provider: The AI provider
    /// - Returns: TestResult indicating validation status
    func validateAPIKey(apiKey: String, provider: AIProvider) async -> TestResult {
        guard !apiKey.isEmpty else {
            return TestResult(
                status: .invalid_key,
                message: "API key is empty"
            )
        }

        // Test the key with a simple request
        let result = await testModel(
            apiKey: apiKey,
            provider: provider,
            model: provider.defaultModels.first ?? ""
        )

        return result
    }

    // MARK: - Fetch Supported Models

    /// Queries which models the API key supports from the provider.
    /// - Parameters:
    ///   - apiKey: The API key
    ///   - provider: The AI provider
    /// - Returns: List of supported model IDs
    func fetchSupportedModels(apiKey: String, provider: AIProvider) async throws -> [String] {
        switch provider {
        case .openRouter:
            return try await fetchOpenRouterModels(apiKey: apiKey)
        case .anthropic:
            // Anthropic doesn't have a models endpoint, return defaults
            return provider.defaultModels
        case .openai:
            return try await fetchOpenAIModels(apiKey: apiKey)
        case .google:
            // Gemini models list endpoint
            return provider.defaultModels
        }
    }

    private func fetchOpenRouterModels(apiKey: String) async throws -> [String] {
        guard let url = URL(string: "https://openrouter.ai/api/v1/models") else {
            throw NSError(domain: "AgentModelCheck", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "AgentModelCheck", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        guard httpResponse.statusCode == 200 else {
            throw NSError(domain: "AgentModelCheck", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API returned status code \(httpResponse.statusCode)"])
        }

        struct ModelsResponse: Decodable {
            struct ModelData: Decodable {
                let id: String
            }
            let data: [ModelData]
        }

        let decoded = try JSONDecoder().decode(ModelsResponse.self, from: data)
        return decoded.data.map { $0.id }
    }

    private func fetchOpenAIModels(apiKey: String) async throws -> [String] {
        guard let url = URL(string: "https://api.openai.com/v1/models") else {
            throw NSError(domain: "AgentModelCheck", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "AgentModelCheck", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        guard httpResponse.statusCode == 200 else {
            throw NSError(domain: "AgentModelCheck", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API returned status code \(httpResponse.statusCode)"])
        }

        struct ModelsResponse: Decodable {
            struct ModelData: Decodable {
                let id: String
            }
            let data: [ModelData]
        }

        let decoded = try JSONDecoder().decode(ModelsResponse.self, from: data)
        return decoded.data.map { $0.id }
    }

    // MARK: - Test Model

    /// Sends a small test request to verify the model works correctly.
    /// - Parameters:
    ///   - apiKey: The API key
    ///   - provider: The AI provider
    ///   - model: The model ID to test
    /// - Returns: TestResult with status, latency, and capabilities
    func testModel(apiKey: String, provider: AIProvider, model: String) async -> TestResult {
        let startTime = Date()

        do {
            let response: String

            switch provider {
            case .openRouter:
                response = try await testOpenRouterModel(apiKey: apiKey, model: model)
            case .anthropic:
                response = try await testAnthropicModel(apiKey: apiKey, model: model)
            case .openai:
                response = try await testOpenAIModel(apiKey: apiKey, model: model)
            case .google:
                response = try await testGeminiModel(apiKey: apiKey, model: model)
            }

            let latency = Date().timeIntervalSince(startTime)

            // Check if the response is valid
            guard !response.isEmpty else {
                return TestResult(
                    status: .unknown_error,
                    message: "Model returned empty response",
                    responseLatency: latency
                )
            }

            return TestResult(
                status: .success,
                message: "Model test successful. Response received in \(String(format: "%.2f", latency))s",
                supportedModels: [model],
                responseLatency: latency,
                modelCapabilities: [
                    "responseTime": latency,
                    "testPassed": true
                ]
            )

        } catch let error as NSError {
            let latency = Date().timeIntervalSince(startTime)

            // Determine the specific error type
            let status: TestStatus
            let message: String

            if let urlError = error as? URLError {
                status = .network_error
                message = "Network error: \(urlError.localizedDescription)"
            } else if error.domain == "AgentModelCheck" {
                // Check for specific status codes
                switch error.code {
                case 401, 403:
                    status = .invalid_key
                    message = "Invalid API key or unauthorized access"
                case 404:
                    status = .model_not_found
                    message = "Model '\(model)' not found or not available"
                case 429:
                    status = .rate_limited
                    message = "Rate limit exceeded. Please wait and try again"
                default:
                    status = .unknown_error
                    message = error.localizedDescription
                }
            } else {
                status = .unknown_error
                message = error.localizedDescription
            }

            return TestResult(
                status: status,
                message: message,
                responseLatency: latency
            )
        }
    }

    // MARK: - Provider-Specific Test Implementations

    private func testOpenRouterModel(apiKey: String, model: String) async throws -> String {
        guard let url = URL(string: "https://openrouter.ai/api/v1/chat/completions") else {
            throw NSError(domain: "AgentModelCheck", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("SwiftCode iOS App", forHTTPHeaderField: "X-Title")

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": "Say 'test successful' in 2 words"]
            ],
            "max_tokens": 10
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "AgentModelCheck", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        guard httpResponse.statusCode == 200 else {
            throw NSError(domain: "AgentModelCheck", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API returned status code \(httpResponse.statusCode)"])
        }

        struct Response: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable {
                    let content: String
                }
                let message: Message
            }
            let choices: [Choice]
        }

        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return decoded.choices.first?.message.content ?? ""
    }

    private func testAnthropicModel(apiKey: String, model: String) async throws -> String {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw NSError(domain: "AgentModelCheck", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": "Say 'test successful' in 2 words"]
            ],
            "max_tokens": 10
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "AgentModelCheck", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        guard httpResponse.statusCode == 200 else {
            throw NSError(domain: "AgentModelCheck", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API returned status code \(httpResponse.statusCode)"])
        }

        struct Response: Decodable {
            struct Content: Decodable {
                let text: String
            }
            let content: [Content]
        }

        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return decoded.content.first?.text ?? ""
    }

    private func testOpenAIModel(apiKey: String, model: String) async throws -> String {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw NSError(domain: "AgentModelCheck", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": "Say 'test successful' in 2 words"]
            ],
            "max_tokens": 10
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "AgentModelCheck", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        guard httpResponse.statusCode == 200 else {
            throw NSError(domain: "AgentModelCheck", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API returned status code \(httpResponse.statusCode)"])
        }

        struct Response: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable {
                    let content: String
                }
                let message: Message
            }
            let choices: [Choice]
        }

        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return decoded.choices.first?.message.content ?? ""
    }

    private func testGeminiModel(apiKey: String, model: String) async throws -> String {
        // Gemini uses a different URL structure with the model in the path
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1/models/\(model):generateContent?key=\(apiKey)") else {
            throw NSError(domain: "AgentModelCheck", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": "Say 'test successful' in 2 words"]
                    ]
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "AgentModelCheck", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        guard httpResponse.statusCode == 200 else {
            throw NSError(domain: "AgentModelCheck", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API returned status code \(httpResponse.statusCode)"])
        }

        struct Response: Decodable {
            struct Candidate: Decodable {
                struct Content: Decodable {
                    struct Part: Decodable {
                        let text: String
                    }
                    let parts: [Part]
                }
                let content: Content
            }
            let candidates: [Candidate]
        }

        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return decoded.candidates.first?.content.parts.first?.text ?? ""
    }
}
