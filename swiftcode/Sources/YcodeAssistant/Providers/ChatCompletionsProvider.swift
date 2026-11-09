import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct ChatCompletionsProvider: AssistantProvider {
    public var kind: ProviderKind
    public var baseURL: String
    public var apiKey: String?
    /// Version prefix prepended to the OpenAI-compatible endpoints
    /// (`models`, `chat/completions`). `llama-server` and Mistral use `v1`;
    /// Gemini's OpenAI-compatible surface lives directly under
    /// `/v1beta/openai`, so it uses an empty prefix.
    public var apiPrefix: String
    /// Name used in user-facing hints (defaults to llama-server wording).
    public var serviceName: String
    public static let defaultBaseURL = "http://127.0.0.1:9931"

    public init(baseURL: String = Self.defaultBaseURL, apiKey: String? = nil,
                apiPrefix: String = "v1", serviceName: String = "llama-server",
                kind: ProviderKind = .llamaCpp) {
        self.kind = kind
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.apiPrefix = apiPrefix
        self.serviceName = serviceName
    }

    var notRunningHint: String {
        "Start it and set its address in Settings ▸ Assist."
    }

    func prefixed(_ path: String) -> String {
        apiPrefix.isEmpty ? path : "\(apiPrefix)/\(path)"
    }

    func request(_ path: String) -> URLRequest? {
        guard let url = HTTP.url(baseURL, path) else { return nil }
        var r = URLRequest(url: url)
        if let apiKey, !apiKey.isEmpty { r.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }
        return r
    }

    public func availability() async -> ProviderAvailability {
        guard let req = request(prefixed("models")) else { return .failed("The \(serviceName) address “\(baseURL)” is not a valid URL.") }
        // Local servers (llama.cpp) answer in milliseconds; remote APIs
        // (Gemini, Mistral) need a realistic network timeout.
        let isLoopback = ["127.0.0.1", "localhost", "::1"].contains { baseURL.contains($0) }
        do {
            let r = try await HTTP.send(req, timeout: isLoopback ? 3 : 15)
            if r.status == 503 { return .notRunning(hint: "\(serviceName) is still loading its model. Try again in a moment.") }
            if r.status == 401 { return .signedOut(hint: "\(serviceName) needs an API key. Enter the key it was started with in Settings ▸ Assist.") }
            guard r.status == 200 else { return .failed("\(serviceName) answered HTTP \(r.status): \(HTTP.errorMessage(r.body).message)") }
            let models = Self.parseModels(r.body)
            return models.isEmpty ? .noModels(hint: "\(serviceName) lists no model.") : .ready(models)
        } catch {
            return HTTP.isUnreachable(error) ? .notRunning(hint: "\(serviceName) is not reachable at \(baseURL). " + notRunningHint)
                                             : .failed(error.localizedDescription)
        }
    }

    static func parseModels(_ body: Data) -> [ModelInfo] {
        guard let o = JSON.object(body), let list = o["data"] as? [[String: Any]] else { return [] }
        return list.compactMap { m in
            guard let id = m["id"] as? String else { return nil }
            let ctx = (m["meta"] as? [String: Any]).flatMap { JSON.int($0["n_ctx_train"]) }
            return ModelInfo(id: id, displayName: URL(fileURLWithPath: id).lastPathComponent, contextWindow: ctx)
        }
    }

    public func contextWindow(model: String) async -> Int? {
        guard let req = request("props"), let r = try? await HTTP.send(req, timeout: 3), r.status == 200,
              let o = JSON.object(r.body), let settings = o["default_generation_settings"] as? [String: Any] else { return nil }
        return JSON.int(settings["n_ctx"])
    }

    
    
    
    static func messageContent(_ message: ChatMessage) -> Any {
        guard let images = message.images, !images.isEmpty else { return message.content }
        var parts: [[String: Any]] = [["type": "text", "text": message.content]]
        for image in images {
            parts.append([
                "type": "image_url",
                "image_url": ["url": "data:\(image.mimeType);base64,\(image.data.base64EncodedString())"]
            ])
        }
        return parts
    }

    static func chatBody(_ request: ChatRequest) -> [String: Any] {
        var messages: [[String: Any]] = [["role": "system", "content": request.instructions]]
        messages += request.messages.map { ["role": $0.role.rawValue, "content": messageContent($0)] }
        var body: [String: Any] = ["messages": messages, "stream": true, "stream_options": ["include_usage": true]]
        if let m = request.model, !m.isEmpty { body["model"] = m }
        let g = request.generation
        if let n = g.maxOutputTokens { body["max_tokens"] = n }
        if let t = g.temperature { body["temperature"] = t }
        if let p = g.topP { body["top_p"] = p }
        if let k = g.topK { body["top_k"] = k }
        if let r = g.repeatPenalty { body["repeat_penalty"] = r }
        return body
    }

    public func send(_ request: ChatRequest) -> AsyncThrowingStream<ChatEvent, Error> {
        let provider = self
        return eventStream { out in
            guard var req = provider.request(provider.prefixed("chat/completions")) else { throw AssistantError.failed("The \(provider.serviceName) address is not a valid URL.") }
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
            req.httpBody = try JSONSerialization.data(withJSONObject: Self.chatBody(request), options: [.sortedKeys])
            var sse = SSEDecoder()
            var finished = false
            var usage: TokenUsage?
            var truncated = false
            func handle(_ e: SSEDecoder.Event) throws -> Bool {
                for c in try Self.parseChunk(e.data) {
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
                    AssistantError.http(status: status, message: HTTP.errorMessage(body).message)
                }) { line in
                    guard let e = sse.push(line: line) else { return false }
                    return try handle(e)
                }
                if !finished, let e = sse.finish() { _ = try handle(e) }
            } catch where HTTP.isUnreachable(error) {
                throw AssistantError.unreachable(service: provider.serviceName, url: provider.baseURL, hint: provider.notRunningHint)
            }
            if !finished { throw AssistantError.incomplete("the server closed the stream") }
            if truncated { out.yield(.truncated) }
            out.yield(.finished(usage))
        }
    }

    enum Chunk: Equatable { case text(String), usage(TokenUsage), length, finish, done, none }

    static func parseChunk(_ data: String) throws -> [Chunk] {
        let d = data.trimmingCharacters(in: .whitespaces)
        if d == "[DONE]" { return [.done] }
        guard let o = JSON.object(d) else { throw AssistantError.malformed("The server sent an event that is not JSON.") }
        if o["error"] != nil {
            throw AssistantError.failed(HTTP.errorMessage(Data(d.utf8)).message)
        }
        var out: [Chunk] = []
        if let first = (o["choices"] as? [[String: Any]])?.first {
            if let delta = first["delta"] as? [String: Any], let c = delta["content"] as? String, !c.isEmpty { out.append(.text(c)) }
            if let fr = first["finish_reason"] as? String, !fr.isEmpty {
                if fr == "length" { out.append(.length) }
                out.append(.finish)
            }
        }
        if let u = o["usage"] as? [String: Any] {
            out.append(.usage(TokenUsage(inputTokens: JSON.int(u["prompt_tokens"]), outputTokens: JSON.int(u["completion_tokens"]))))
        }
        return out.isEmpty ? [.none] : out
    }
}
