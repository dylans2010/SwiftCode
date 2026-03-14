import Foundation

enum ModelCheckStatus: String, Codable {
    case success
    case invalid_key
    case model_not_found
    case rate_limited
    case network_error
    case configuration_error
}

struct AgentModelCheckResult: Codable {
    let status: ModelCheckStatus
    let supportedModels: [String]
    let latency: Double
    let modelCapability: String
}

final class AgentModelCheck {
    static let shared = AgentModelCheck()
    private init() {}

    private let providerKeyStorageKey = "ai.selectedProvider"

    func checkModel(provider: String, apiKey: String, model: String) async -> AgentModelCheckResult {
        let startTime = Date()
        let normalizedProvider = provider.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedProvider.isEmpty else {
            return .init(status: .configuration_error, supportedModels: [], latency: 0, modelCapability: "Provider is missing.")
        }

        guard !normalizedModel.isEmpty else {
            return .init(status: .configuration_error, supportedModels: [], latency: 0, modelCapability: "Model is missing.")
        }

        let expectedKey = keychainKey(for: normalizedProvider)
        let storedProvider = UserDefaults.standard.string(forKey: providerKeyStorageKey)

        // If provider changed but key was not updated for that provider, flag it immediately.
        if let storedProvider, storedProvider != normalizedProvider,
           let expectedKey, !KeychainService.shared.contains(key: expectedKey), !normalizedKey.isEmpty {
            return .init(
                status: .configuration_error,
                supportedModels: [],
                latency: Date().timeIntervalSince(startTime),
                modelCapability: "Provider changed from \(storedProvider) to \(normalizedProvider), but no key is saved for the selected provider."
            )
        }

        // If a key exists for selected provider but current input is empty, this is also a config mismatch.
        if normalizedKey.isEmpty,
           let expectedKey,
           KeychainService.shared.contains(key: expectedKey) {
            return .init(
                status: .configuration_error,
                supportedModels: [],
                latency: Date().timeIntervalSince(startTime),
                modelCapability: "An API key is saved for \(normalizedProvider), but no key is currently provided."
            )
        }

        guard !normalizedKey.isEmpty else {
            return .init(
                status: .configuration_error,
                supportedModels: [],
                latency: Date().timeIntervalSince(startTime),
                modelCapability: "API key is missing for \(normalizedProvider)."
            )
        }

        switch normalizedProvider {
        case "OpenRouter":
            return await checkOpenRouter(apiKey: normalizedKey, model: normalizedModel, startTime: startTime)
        case "Anthropic", "OpenAI", "Gemini", "Mistral", "Qwen":
            // Validate config path for providers that are user-managed in this phase.
            return .init(
                status: .success,
                supportedModels: [normalizedModel],
                latency: Date().timeIntervalSince(startTime),
                modelCapability: "Provider configuration is valid. Live model validation is currently available for OpenRouter."
            )
        default:
            return .init(
                status: .configuration_error,
                supportedModels: [],
                latency: Date().timeIntervalSince(startTime),
                modelCapability: "Unknown provider: \(normalizedProvider)"
            )
        }
    }

    private func keychainKey(for provider: String) -> String? {
        switch provider {
        case "OpenRouter": return KeychainService.openRouterAPIKey
        case "Anthropic": return "anthropic_api_key"
        case "OpenAI": return "openai_api_key"
        case "Gemini": return "gemini_api_key"
        case "Mistral": return "mistral_api_key"
        case "Qwen": return "qwen_api_key"
        default: return nil
        }
    }

    private func checkOpenRouter(apiKey: String, model: String, startTime: Date) async -> AgentModelCheckResult {
        let baseURL = URL(string: "https://openrouter.ai/api/v1")!

        var modelsRequest = URLRequest(url: baseURL.appendingPathComponent("models"))
        modelsRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        guard let (modelsData, modelsResponse) = try? await URLSession.shared.data(for: modelsRequest),
              let httpResponse = modelsResponse as? HTTPURLResponse else {
            return AgentModelCheckResult(status: .network_error, supportedModels: [], latency: 0, modelCapability: "Network error")
        }

        if httpResponse.statusCode == 401 {
            return AgentModelCheckResult(status: .invalid_key, supportedModels: [], latency: 0, modelCapability: "Invalid API Key")
        }

        struct ORModelsResponse: Decodable {
            struct ModelData: Decodable { let id: String }
            let data: [ModelData]
        }

        guard let decodedModels = try? JSONDecoder().decode(ORModelsResponse.self, from: modelsData) else {
            return AgentModelCheckResult(status: .network_error, supportedModels: [], latency: 0, modelCapability: "Failed to decode models")
        }

        let supportedModels = decodedModels.data.map { $0.id }
        if !supportedModels.contains(model) {
            return AgentModelCheckResult(status: .model_not_found, supportedModels: supportedModels, latency: 0, modelCapability: "Model \(model) not found in your account.")
        }

        var chatRequest = URLRequest(url: baseURL.appendingPathComponent("chat/completions"))
        chatRequest.httpMethod = "POST"
        chatRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        chatRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "messages": [["role": "user", "content": "hi"]],
            "max_tokens": 5
        ]
        chatRequest.httpBody = try? JSONSerialization.data(withJSONObject: body)

        guard let (chatData, chatResponse) = try? await URLSession.shared.data(for: chatRequest),
              let httpChatResponse = chatResponse as? HTTPURLResponse else {
            return AgentModelCheckResult(status: .network_error, supportedModels: supportedModels, latency: 0, modelCapability: "Chat request failed")
        }

        let latency = Date().timeIntervalSince(startTime)

        if httpChatResponse.statusCode == 429 {
            return AgentModelCheckResult(status: .rate_limited, supportedModels: supportedModels, latency: latency, modelCapability: "Rate limited")
        }

        if httpChatResponse.statusCode != 200 {
            let errorMsg = String(data: chatData, encoding: .utf8) ?? "Unknown API Error"
            return AgentModelCheckResult(status: .network_error, supportedModels: supportedModels, latency: latency, modelCapability: errorMsg)
        }

        return AgentModelCheckResult(
            status: .success,
            supportedModels: supportedModels,
            latency: latency,
            modelCapability: "Selected model is responsive and supports your request."
        )
    }
}
