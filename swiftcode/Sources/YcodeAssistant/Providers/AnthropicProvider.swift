import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct AnthropicProvider: AssistantProvider {
    public let kind = ProviderKind.anthropic
    public static let defaultBaseURL = "https://api.anthropic.com/v1"
    public static let anthropicVersion = "2023-06-01"

    public var baseURL: String
    public var apiKey: String?

    public init(baseURL: String = Self.defaultBaseURL, apiKey: String? = nil) {
        self.baseURL = baseURL
        self.apiKey = apiKey
    }

    private func resolvedKey() -> String? {
        if let apiKey, !apiKey.isEmpty { return apiKey }
        return defaultSecretStore().readString(SecretAccount.anthropicKey)
    }

    public func availability() async -> ProviderAvailability {
        guard let key = resolvedKey(), !key.isEmpty else {
            return .signedOut(hint: "No Anthropic API key is stored. Add one in Settings ▸ Assist.")
        }
        guard let url = HTTP.url(baseURL, "models") else {
            return .failed("The Anthropic address “\(baseURL)” is not a valid URL.")
        }
        var request = URLRequest(url: url)
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue(Self.anthropicVersion, forHTTPHeaderField: "anthropic-version")
        do {
            let response = try await HTTP.send(request, timeout: 10)
            if response.status == 401 { return .signedOut(hint: "The Anthropic API key was rejected (401).") }
            guard response.status == 200 else {
                return .failed("Anthropic answered HTTP \(response.status): \(HTTP.errorMessage(response.body).message)")
            }
            let models = Self.parseModels(response.body)
            return models.isEmpty ? .noModels(hint: "Anthropic listed no models.") : .ready(models)
        } catch {
            return HTTP.isUnreachable(error)
                ? .failed("Anthropic is unreachable: \(error.localizedDescription)")
                : .failed(error.localizedDescription)
        }
    }

    static func parseModels(_ body: Data) -> [ModelInfo] {
        guard let object = JSON.object(body), let list = object["data"] as? [[String: Any]] else { return [] }
        return list.compactMap { entry in
            guard let id = entry["id"] as? String else { return nil }
            return ModelInfo(id: id, displayName: id)
        }
    }

    static func requestBody(model: String, instructions: String, messages: [ChatMessage], stream: Bool,
                            generation: GenerationOptions = GenerationOptions()) -> [String: Any] {
        var systemParts = instructions.isEmpty ? [] : [instructions]
        var convo: [(role: String, blocks: [[String: Any]])] = []
        for message in messages {
            if message.role == .system {
                if !message.content.isEmpty { systemParts.append(message.content) }
                continue
            }
            var blocks: [[String: Any]] = []
            if !message.content.isEmpty {
                blocks.append(["type": "text", "text": message.content])
            }
            for image in message.images ?? [] {
                blocks.append([
                    "type": "image",
                    "source": [
                        "type": "base64",
                        "media_type": image.mimeType,
                        "data": image.data.base64EncodedString()
                    ]
                ])
            }
            if blocks.isEmpty { blocks.append(["type": "text", "text": " "]) }
            let role = message.role == .assistant ? "assistant" : "user"
            if let last = convo.indices.last, convo[last].role == role {
                convo[last].blocks.append(contentsOf: blocks)
            } else {
                convo.append((role: role, blocks: blocks))
            }
        }
        if convo.isEmpty {
            convo.append((role: "user", blocks: [["type": "text", "text": " "]]))
        } else if convo.first?.role == "assistant" {
            convo.insert((role: "user", blocks: [["type": "text", "text": " "]]), at: 0)
        }
        var body: [String: Any] = [
            "model": model,
            "max_tokens": generation.maxOutputTokens.flatMap { $0 > 0 ? $0 : nil } ?? 4096,
            "stream": stream,
            "messages": convo.map { ["role": $0.role, "content": $0.blocks] }
        ]
        if let t = generation.temperature { body["temperature"] = t }
        if let p = generation.topP { body["top_p"] = p }
        if let k = generation.topK { body["top_k"] = k }
        let system = systemParts.joined(separator: "\n\n")
        if !system.isEmpty { body["system"] = system }
        return body
    }

    public func send(_ request: ChatRequest) -> AsyncThrowingStream<ChatEvent, Error> {
        let provider = self
        return eventStream { out in
            guard let key = provider.resolvedKey(), !key.isEmpty else {
                throw AssistantError.notSignedIn(hint: "No Anthropic API key is stored.")
            }
            guard let url = HTTP.url(provider.baseURL, "messages") else {
                throw AssistantError.failed("The Anthropic address is not a valid URL.")
            }
            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "POST"
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.setValue(key, forHTTPHeaderField: "x-api-key")
            urlRequest.setValue(Self.anthropicVersion, forHTTPHeaderField: "anthropic-version")
            let model = request.model ?? "claude-sonnet-4-5"
            urlRequest.httpBody = try JSONSerialization.data(
                withJSONObject: Self.requestBody(model: model, instructions: request.instructions, messages: request.messages,
                                                 stream: true, generation: request.generation),
                options: [.sortedKeys])
            var decoder = SSEDecoder()
            var finished = false
            var usage: TokenUsage?
            func handle(_ event: SSEDecoder.Event) throws -> Bool {
                for chunk in try Self.parseEvent(event.data) {
                    switch chunk {
                    case .text(let text): out.yield(.text(text))
                    case .usage(let tokens): usage = tokens
                    case .done: finished = true; return true
                    case .none: break
                    }
                }
                return false
            }
            do {
                try await HTTP.streamLines(urlRequest, error: { status, body in
                    AssistantError.http(status: status, message: HTTP.errorMessage(body).message)
                }) { line in
                    guard let event = decoder.push(line: line) else { return false }
                    return try handle(event)
                }
                if !finished, let event = decoder.finish() { _ = try handle(event) }
            } catch where HTTP.isUnreachable(error) {
                throw AssistantError.unreachable(service: "Anthropic", url: provider.baseURL, hint: "Check the network connection.")
            }
            if !finished { throw AssistantError.incomplete("Anthropic closed the stream") }
            out.yield(.finished(usage))
        }
    }

    enum AnthropicChunk: Equatable {
        case text(String)
        case usage(TokenUsage)
        case done
        case none
    }

    static func parseEvent(_ data: String) throws -> [AnthropicChunk] {
        let trimmed = data.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return [.none] }
        guard let object = JSON.object(trimmed) else {
            throw AssistantError.malformed("Anthropic sent an event that is not JSON.")
        }
        if object["error"] != nil {
            throw AssistantError.failed(HTTP.errorMessage(Data(trimmed.utf8)).message)
        }
        guard let type = object["type"] as? String else { return [.none] }
        switch type {
        case "content_block_delta":
            if let delta = object["delta"] as? [String: Any],
               let text = delta["text"] as? String, !text.isEmpty {
                return [.text(text)]
            }
            return [.none]
        case "message_delta":
            if let usage = object["usage"] as? [String: Any] {
                return [.usage(TokenUsage(inputTokens: JSON.int(usage["input_tokens"]),
                                         outputTokens: JSON.int(usage["output_tokens"])))]
            }
            return [.none]
        case "message_stop":
            return [.done]
        default:
            return [.none]
        }
    }
}
