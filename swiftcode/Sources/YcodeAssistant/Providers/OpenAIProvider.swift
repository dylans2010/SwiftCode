import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct OpenAIProvider: AssistantProvider {
    public enum Credential: Sendable {
        case apiKey(String)
        case account(OpenAIAccount)
        case none
    }

    public let kind = ProviderKind.openAI
    public var baseURL: String
    public var credential: Credential
    public static let defaultBaseURL = "https://api.openai.com/v1"

    public init(baseURL: String = Self.defaultBaseURL, credential: Credential) {
        self.baseURL = baseURL
        self.credential = credential
    }

    static let signedOutHint = "Sign in with ChatGPT or enter an OpenAI API key in Settings ▸ Assist."

    func bearer(forceRefresh: Bool = false) async throws -> String {
        switch credential {
        case .apiKey(let k) where !k.isEmpty: return k
        case .account(let a): return try await a.accessToken(forceRefresh: forceRefresh)
        default:
            if let envKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !envKey.isEmpty {
                return envKey
            }
            if let kc = KeychainService.shared.get(forKey: "openai_api_key"), !kc.isEmpty {
                return kc
            }
            throw AssistantError.notSignedIn(hint: Self.signedOutHint)
        }
    }

    var usesPlan: Bool { if case .account = credential { true } else { false } }

    public func availability() async -> ProviderAvailability {
        if case .account(let a) = credential, case .signedIn(_, let plan) = await a.status, !plan {
            return .failed(AssistantError.planUsageNotEnabled.errorDescription! + " " + AssistantError.planUsageNotEnabled.recoverySuggestion!)
        }
        do {
            let models = try await listModels()
            return models.isEmpty ? .noModels(hint: "The account lists no models.") : .ready(models)
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

    public func listModels() async throws -> [ModelInfo] {
        guard let url = HTTP.url(baseURL, "models") else { throw AssistantError.failed("The OpenAI address is not valid.") }
        for attempt in 0..<2 {
            var r = URLRequest(url: url)
            r.setValue("Bearer \(try await bearer(forceRefresh: attempt > 0))", forHTTPHeaderField: "Authorization")
            let response: HTTP.Response
            do {
                response = try await HTTP.send(r, timeout: 2.0)
            } catch where HTTP.isUnreachable(error) {
                throw AssistantError.unreachable(service: "OpenAI", url: baseURL, hint: "Check the network connection.")
            }
            if response.status == 401 && usesPlan && attempt == 0 { continue }
            guard response.status == 200 else { throw Self.mapError(status: response.status, body: response.body, plan: usesPlan) }
            return Self.parseModels(response.body)
        }
        throw AssistantError.notSignedIn(hint: Self.signedOutHint)
    }

    static func parseModels(_ body: Data) -> [ModelInfo] {
        guard let o = JSON.object(body) else { return [] }
        if let list = o["models"] as? [[String: Any]] {
            return list.compactMap { m in
                guard let slug = m["slug"] as? String, (m["visibility"] as? String).map({ $0 == "list" }) ?? true else { return nil }
                return ModelInfo(id: slug, displayName: (m["display_name"] as? String) ?? slug, contextWindow: JSON.int(m["context_window"]))
            }
        }
        guard let data = o["data"] as? [[String: Any]] else { return [] }
        let ids = data.compactMap { $0["id"] as? String }
        let chat = ids.filter { id in
            if id.hasPrefix("gpt-") || id.hasPrefix("chatgpt-") { return true }
            for prefix in ["o1", "o3", "o4"] where id == prefix || id.hasPrefix(prefix + "-") { return true }
            return false
        }
        return (chat.isEmpty ? ids : chat).sorted { a, b in
            let ga = a.hasPrefix("gpt-"), gb = b.hasPrefix("gpt-")
            return ga != gb ? ga : a.compare(b, options: .numeric) == .orderedDescending
        }.map { ModelInfo(id: $0) }
    }

    
    
    public static func canonicalModelID(_ raw: String?) -> String {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return "gpt-4o"
        }
        let lower = raw.lowercased()
        if lower == "gpt-4" || lower == "gpt-4-turbo" { return "gpt-4o" }
        if lower == "o3" { return "o3-mini" }
        if lower == "o1" { return "o1" }
        return raw
    }

    static func isReasoningModel(_ model: String) -> Bool {
        let lower = model.lowercased()
        return lower.hasPrefix("o1") || lower.hasPrefix("o3") || lower.hasPrefix("o4")
    }

    static func responseContent(_ message: ChatMessage) -> Any {
        guard let images = message.images, !images.isEmpty else { return message.content }
        var parts: [[String: Any]] = [["type": "text", "text": message.content]]
        for image in images {
            parts.append(["type": "image_url", "image_url": ["url": "data:\(image.mimeType);base64,\(image.data.base64EncodedString())"]])
        }
        return parts
    }

    static func responsesBody(_ request: ChatRequest) -> [String: Any] {
        let model = canonicalModelID(request.model)
        let isReasoning = isReasoningModel(model)
        let input: [[String: Any]] = request.messages.map {
            ["role": $0.role == .system ? (isReasoning ? "developer" : "system") : $0.role.rawValue, "content": responseContent($0)]
        }
        var body: [String: Any] = ["model": model, "instructions": request.instructions, "input": input, "store": false, "stream": true]
        let g = request.generation
        if let n = g.maxOutputTokens { body["max_output_tokens"] = n }
        if !isReasoning {
            if let t = g.temperature { body["temperature"] = t }
            if let p = g.topP { body["top_p"] = p }
        }
        return body
    }

    static func chatCompletionsBody(_ request: ChatRequest) -> [String: Any] {
        let model = canonicalModelID(request.model)
        let isReasoning = isReasoningModel(model)
        var messages: [[String: Any]] = []
        if !request.instructions.isEmpty {
            messages.append(["role": isReasoning ? "developer" : "system", "content": request.instructions])
        }
        for msg in request.messages {
            let role = (msg.role == .system && isReasoning) ? "developer" : msg.role.rawValue
            messages.append(["role": role, "content": responseContent(msg)])
        }
        var body: [String: Any] = [
            "model": model,
            "messages": messages,
            "stream": true,
            "stream_options": ["include_usage": true]
        ]
        let g = request.generation
        if let n = g.maxOutputTokens {
            if isReasoning {
                body["max_completion_tokens"] = n
            } else {
                body["max_tokens"] = n
            }
        }
        if !isReasoning {
            if let t = g.temperature { body["temperature"] = t }
            if let p = g.topP { body["top_p"] = p }
        }
        return body
    }

    public func send(_ request: ChatRequest) -> AsyncThrowingStream<ChatEvent, Error> {
        let provider = self
        return eventStream { out in
            let useChatCompletions = !provider.usesPlan
            let endpoint = useChatCompletions ? "chat/completions" : "responses"
            guard let url = HTTP.url(provider.baseURL, endpoint) else { throw AssistantError.failed("The OpenAI address is not valid.") }
            let bodyDict = useChatCompletions ? Self.chatCompletionsBody(request) : Self.responsesBody(request)
            let body = try JSONSerialization.data(withJSONObject: bodyDict, options: [.sortedKeys])
            var attempt = 0
            while true {
                var req = URLRequest(url: url)
                req.httpMethod = "POST"
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                req.setValue("Bearer \(try await provider.bearer(forceRefresh: attempt > 0))", forHTTPHeaderField: "Authorization")
                req.httpBody = body
                var sse = SSEDecoder()
                var finished = false
                var truncated = false
                var usage: TokenUsage?
                do {
                    try await HTTP.streamLines(req, error: { status, body in
                        RetryableAuth(status: status, body: body)
                    }) { line in
                        guard let e = sse.push(line: line) else { return false }
                        for ev in try Self.parseEvent(e.data, plan: provider.usesPlan) {
                            out.yield(ev)
                            if case .finished(let u) = ev {
                                finished = true
                                if let u { usage = u }
                            } else if case .truncated = ev {
                                truncated = true
                            }
                        }
                        return finished
                    }
                    if !finished, let e = sse.finish() {
                        for ev in try Self.parseEvent(e.data, plan: provider.usesPlan) {
                            out.yield(ev)
                            if case .finished(let u) = ev {
                                finished = true
                                if let u { usage = u }
                            } else if case .truncated = ev {
                                truncated = true
                            }
                        }
                    }
                } catch let r as RetryableAuth {
                    if r.status == 401 && provider.usesPlan && attempt == 0 { attempt += 1; continue }
                    throw Self.mapError(status: r.status, body: r.body, plan: provider.usesPlan)
                } catch where HTTP.isUnreachable(error) {
                    throw AssistantError.unreachable(service: "OpenAI", url: provider.baseURL, hint: "Check the network connection.")
                }
                if !finished {
                    if truncated {
                        out.yield(.truncated)
                    }
                    out.yield(.finished(usage))
                    return
                }
                return
            }
        }
    }

    struct RetryableAuth: Error { var status: Int; var body: Data }

    static func parseEvent(_ data: String, plan: Bool) throws -> [ChatEvent] {
        let d = data.trimmingCharacters(in: .whitespaces)
        if d.isEmpty || d == "[DONE]" { return [] }
        guard let o = JSON.object(d) else { throw AssistantError.malformed("OpenAI sent an event that is not JSON.") }
        
        
        if let errObj = o["error"] as? [String: Any] {
            let msg = (errObj["message"] as? String) ?? "The request failed."
            let code = errObj["code"] as? String
            throw mapCode(code, message: msg, status: nil, plan: plan)
        }

        
        if let choices = o["choices"] as? [[String: Any]] {
            var events: [ChatEvent] = []
            if let first = choices.first {
                if let delta = first["delta"] as? [String: Any] {
                    if let content = delta["content"] as? String, !content.isEmpty {
                        events.append(.text(content))
                    } else if let reasoning = delta["reasoning_content"] as? String, !reasoning.isEmpty {
                        events.append(.text(reasoning))
                    }
                }
                if let finishReason = first["finish_reason"] as? String {
                    if finishReason == "length" {
                        events.append(.truncated)
                    }
                    if finishReason == "stop" || finishReason == "tool_calls" || finishReason == "length" {
                        let u = o["usage"] as? [String: Any]
                        let tokenUsage = u.map { TokenUsage(inputTokens: JSON.int($0["prompt_tokens"]), outputTokens: JSON.int($0["completion_tokens"])) }
                        events.append(.finished(tokenUsage))
                    }
                }
            }
            if let u = o["usage"] as? [String: Any], !events.contains(where: { if case .finished = $0 { return true }; return false }) {
                events.append(.finished(TokenUsage(inputTokens: JSON.int(u["prompt_tokens"]), outputTokens: JSON.int(u["completion_tokens"]))))
            }
            if !events.isEmpty { return events }
        }

        
        switch o["type"] as? String {
        case "response.output_text.delta":
            if let t = o["delta"] as? String, !t.isEmpty { return [.text(t)] }
            return []
        case "response.completed":
            let u = (o["response"] as? [String: Any])?["usage"] as? [String: Any]
            return [.finished(u.map { TokenUsage(inputTokens: JSON.int($0["input_tokens"]), outputTokens: JSON.int($0["output_tokens"])) })]
        case "response.failed":
            let e = ((o["response"] as? [String: Any])?["error"] as? [String: Any]) ?? [:]
            throw mapCode(e["code"] as? String, message: (e["message"] as? String) ?? "The response failed.", status: nil, plan: plan)
        case "response.incomplete":
            let r = o["response"] as? [String: Any]
            let reason = ((r?["incomplete_details"] as? [String: Any])?["reason"] as? String) ?? "incomplete"
            if reason == "max_output_tokens" {
                let u = r?["usage"] as? [String: Any]
                return [.truncated, .finished(u.map { TokenUsage(inputTokens: JSON.int($0["input_tokens"]), outputTokens: JSON.int($0["output_tokens"])) })]
            }
            throw AssistantError.incomplete(reason)
        case "error":
            let e = (o["error"] as? [String: Any]) ?? o
            throw mapCode(e["code"] as? String, message: (e["message"] as? String) ?? "The request failed.", status: nil, plan: plan)
        default:
            return []
        }
    }

    static func mapError(status: Int, body: Data, plan: Bool) -> AssistantError {
        let (message, code) = HTTP.errorMessage(body)
        return mapCode(code, message: message, status: status, plan: plan)
    }

    static func mapCode(_ code: String?, message: String, status: Int?, plan: Bool) -> AssistantError {
        switch code {
        case "subscription_sharing_usage_limit_exceeded":
            return .usageLimit("You've reached a usage limit. Check your usage in ChatGPT settings.")
        case "subscription_sharing_usage_unavailable", "subscription_sharing_user_unavailable":
            return .temporarilyUnavailable("Usage status can't be checked right now. Try again shortly.")
        case "subscription_sharing_user_not_eligible":
            return .failed("ChatGPT plan usage isn't available for this account or workspace.")
        case "subscription_sharing_unsupported_capability":
            return .unsupported("This request uses a feature that isn't supported with ChatGPT plan usage.")
        case "subscription_sharing_route_not_supported":
            return .failed("This request route isn't supported for ChatGPT plan usage.")
        case "subscription_sharing_invalid_user":
            return .notSignedIn(hint: "Your ChatGPT session needs to be renewed. " + OpenAIAccount.signInHint)
        case "chatpass_v2_scope_not_authorized", "chatpass_v2_invalid_authorization_context":
            return .failed("This app isn't authorized for that action. Check the sign-in in Settings ▸ Assist.")
        case "model_not_found":
            return .modelNotFound(model: "", hint: "Choose another model in Assist's model menu.")
        default: break
        }
        switch status {
        case 401?: return .notSignedIn(hint: plan ? "Your ChatGPT session was not accepted. " + OpenAIAccount.signInHint
                                                  : "The API key was not accepted. Check it in Settings ▸ Assist.")
        case 403?: return .failed(message.isEmpty ? "The request was refused (HTTP 403)." : message)
        case 429?: return .usageLimit(message.isEmpty ? "Rate or usage limit reached." : message)
        case 503?: return .temporarilyUnavailable(message.isEmpty ? "The service is unavailable. Try again shortly." : message)
        case let s?: return .http(status: s, message: message)
        case nil: return .failed(message)
        }
    }
}
