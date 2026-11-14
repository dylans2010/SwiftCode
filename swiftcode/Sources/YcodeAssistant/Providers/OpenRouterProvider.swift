import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct OpenRouterProvider: AssistantProvider {
    public let kind = ProviderKind.openRouter
    public var baseURL: String
    public var apiKey: String?
    public static let defaultBaseURL = "https://openrouter.ai/api/v1"

    static let signedOutHint = "Enter an OpenRouter API key in Settings ▸ Assist."

    public static let modelCacheTTL: TimeInterval = 3600

    private let cache = OpenRouterModelCache()

    public init(baseURL: String = Self.defaultBaseURL, apiKey: String? = nil) {
        self.baseURL = baseURL
        self.apiKey = apiKey
    }

    public func availability() async -> ProviderAvailability {
        do {
            let models = try await listModels()
            return models.isEmpty ? .noModels(hint: "OpenRouter lists no models.") : .ready(models)
        } catch let e as AssistantError {
            switch e {
            case .notSignedIn(let hint): return .signedOut(hint: hint)
            case .unreachable(_, _, let hint): return .notRunning(hint: hint)
            default: return .failed(e.errorDescription ?? "\(e)")
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    public func listModels(forceRefresh: Bool = false) async throws -> [ModelInfo] {
        if !forceRefresh, let cached = cache.cached() { return cached }
        let models = Self.parseModels(try await fetchModelsData())
        cache.store(models)
        return models
    }

    public func refreshModels() async throws -> [ModelInfo] {
        try await listModels(forceRefresh: true)
    }

    public func testConnection() async throws -> String {
        let models = try await listModels(forceRefresh: true)
        return "Connected to OpenRouter (\(models.count) models available)."
    }

    public func validateModel(_ modelID: String) async throws -> OpenRouterToolCallingSupport {
        let trimmed = modelID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains("/") else {
            throw AssistantError.failed("“\(trimmed)” is not an OpenRouter model identifier (expected provider/model form).")
        }
        let data = try await fetchModelsData()
        guard let support = Self.toolCallingSupport(for: trimmed, in: data) else {
            throw AssistantError.modelNotFound(model: trimmed, hint: "Choose another model from the discovered list in Settings ▸ Assist.")
        }
        return support
    }

    public func contextWindow(model: String) async -> Int? {
        (try? await listModels())?.first { $0.id == model }?.contextWindow
    }

    private func resolvedKey() async -> String? {
        if let apiKey, !apiKey.isEmpty { return apiKey }
        let resolved = await MainActor.run { OpenRouterClient.resolveOpenRouterAPIKey() }
        if !resolved.isEmpty { return resolved }
        if let envKey = ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"], !envKey.isEmpty { return envKey }
        if let kc = KeychainService.shared.get(forKey: KeychainService.openRouterAPIKey), !kc.isEmpty { return kc }
        return nil
    }

    private func fetchModelsData() async throws -> Data {
        guard let key = await resolvedKey(), !key.isEmpty else { throw AssistantError.notSignedIn(hint: Self.signedOutHint) }
        guard let url = HTTP.url(baseURL, "models") else { throw AssistantError.failed("The OpenRouter address is not valid.") }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        let response: HTTP.Response
        do {
            response = try await HTTP.send(request, timeout: 2.0)
        } catch where HTTP.isUnreachable(error) {
            throw AssistantError.unreachable(service: "OpenRouter", url: baseURL, hint: "Check the network connection.")
        }
        guard response.status == 200 else { throw Self.mapError(status: response.status, body: response.body, model: "") }
        return response.body
    }

    static func parseModels(_ body: Data) -> [ModelInfo] {
        guard let o = JSON.object(body), let list = o["data"] as? [[String: Any]] else { return [] }
        return list.compactMap { m in
            guard let id = m["id"] as? String else { return nil }
            let name = m["name"] as? String
            var pricing: ModelInfo.ModelPricing?
            if let rawPricing = m["pricing"] as? [String: Any] {
                let prompt = rawPricing["prompt"] as? String
                let completion = rawPricing["completion"] as? String
                if prompt != nil || completion != nil {
                    pricing = ModelInfo.ModelPricing(prompt: prompt, completion: completion)
                }
            }
            return ModelInfo(id: id, displayName: (name?.isEmpty == false) ? name : id,
                             contextWindow: JSON.int(m["context_length"]),
                             description: m["description"] as? String,
                             pricing: pricing)
        }
    }

    static func toolCallingSupport(for modelID: String, in body: Data) -> OpenRouterToolCallingSupport? {
        guard let o = JSON.object(body), let list = o["data"] as? [[String: Any]],
              let entry = list.first(where: { ($0["id"] as? String) == modelID }) else { return nil }
        guard let supported = entry["supported_parameters"] as? [String] else { return .unknown }
        return supported.contains("tools") ? .supports : .doesNotSupport
    }

    public static func canonicalModelID(_ raw: String?) -> String {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return "anthropic/claude-3.5-sonnet"
        }
        if raw.contains("/") { return raw }
        let lower = raw.lowercased()
        if lower.contains("claude") {
            if lower.contains("3-7") || lower.contains("3.7") { return "anthropic/claude-3.7-sonnet" }
            if lower.contains("haiku") { return "anthropic/claude-3.5-haiku" }
            return "anthropic/claude-3.5-sonnet"
        }
        if lower.contains("gpt-4o-mini") { return "openai/gpt-4o-mini" }
        if lower.contains("gpt-4o") || lower.contains("gpt-4") { return "openai/gpt-4o" }
        if lower.contains("o1") { return "openai/o1" }
        if lower.contains("o3") { return "openai/o3-mini" }
        if lower.contains("deepseek-r1") { return "deepseek/deepseek-r1" }
        if lower.contains("deepseek") { return "deepseek/deepseek-chat" }
        return raw
    }

    static func chatBody(_ request: ChatRequest) -> [String: Any] {
        let model = canonicalModelID(request.model)
        var messages: [[String: Any]] = [["role": "system", "content": request.instructions]]
        messages += request.messages.map { ["role": $0.role.rawValue, "content": ChatCompletionsProvider.messageContent($0)] }
        var body: [String: Any] = ["messages": messages, "stream": true, "stream_options": ["include_usage": true]]
        body["model"] = model
        let g = request.generation
        if let n = g.maxOutputTokens { body["max_tokens"] = n }
        let isReasoning = model.contains("o1") || model.contains("o3") || model.contains("r1")
        if !isReasoning {
            if let t = g.temperature { body["temperature"] = t }
            if let p = g.topP { body["top_p"] = p }
        }
        return body
    }

    public func send(_ request: ChatRequest) -> AsyncThrowingStream<ChatEvent, Error> {
        let provider = self
        return eventStream { out in
            guard let key = await provider.resolvedKey(), !key.isEmpty else { throw AssistantError.notSignedIn(hint: Self.signedOutHint) }
            guard let url = HTTP.url(provider.baseURL, "chat/completions") else { throw AssistantError.failed("The OpenRouter address is not valid.") }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
            req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            req.httpBody = try JSONSerialization.data(withJSONObject: Self.chatBody(request), options: [.sortedKeys])
            var sse = SSEDecoder()
            var finished = false
            var usage: TokenUsage?
            var truncated = false
            func handle(_ e: SSEDecoder.Event) throws -> Bool {
                for c in try ChatCompletionsProvider.parseChunk(e.data) {
                    switch c {
                    case .text(let t): out.yield(.text(t))
                    case .usage(let u): usage = u
                    case .length: truncated = true
                    case .finish: finished = true
                    case .done: finished = true; return true
                    case .none: break
                    }
                }
                return false
            }
            do {
                try await HTTP.streamLines(req, error: { status, body in
                    Self.mapError(status: status, body: body, model: request.model ?? "")
                }) { line in
                    guard let e = sse.push(line: line) else { return false }
                    return try handle(e)
                }
                if !finished, let e = sse.finish() { _ = try handle(e) }
            } catch where HTTP.isUnreachable(error) {
                throw AssistantError.unreachable(service: "OpenRouter", url: provider.baseURL, hint: "Check the network connection.")
            }
            if !finished { throw AssistantError.incomplete("the server closed the stream") }
            if truncated { out.yield(.truncated) }
            out.yield(.finished(usage))
        }
    }

    static func mapError(status: Int, body: Data, model: String) -> AssistantError {
        let (message, _) = HTTP.errorMessage(body)
        switch status {
        case 401:
            return .notSignedIn(hint: "The OpenRouter API key was not accepted. Check it in Settings ▸ Assist.")
        case 402:
            return .failed(message.isEmpty
                ? "OpenRouter reports insufficient credits (402) for this account. Add credits on openrouter.ai; the selected model was not changed."
                : message)
        case 404 where !model.isEmpty && message.contains(model):
            return .modelNotFound(model: model, hint: "Choose another model from the discovered list in Settings ▸ Assist.")
        case 429:
            return .usageLimit(message.isEmpty ? "OpenRouter rate-limited this request (429). Wait briefly and try again." : message)
        case 502, 503, 504:
            return .temporarilyUnavailable("OpenRouter upstream provider error (HTTP \(status)): \(message.isEmpty ? "The upstream model provider is temporarily unavailable." : message)")
        default:
            return .http(status: status, message: message)
        }
    }
}

public enum OpenRouterToolCallingSupport: Sendable, Equatable {
    case supports
    case doesNotSupport
    case unknown
}

private final class OpenRouterModelCache: @unchecked Sendable {
    private let lock = NSLock()
    private var models: [ModelInfo]?
    private var fetchedAt: Date?

    func cached() -> [ModelInfo]? {
        lock.lock(); defer { lock.unlock() }
        guard let models, let fetchedAt, Date().timeIntervalSince(fetchedAt) < OpenRouterProvider.modelCacheTTL else { return nil }
        return models
    }

    func store(_ models: [ModelInfo]) {
        lock.lock(); fetchedAt = Date(); self.models = models; lock.unlock()
    }
}
