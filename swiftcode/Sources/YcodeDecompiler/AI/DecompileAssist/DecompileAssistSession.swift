import Foundation
import Observation
import YcodeAssistant

/// A chat message in a Decompile Assist conversation.
public struct DecompileAssistMessage: Identifiable, Sendable {
    public enum Role: String, Sendable {
        case user, assistant, system
    }
    public let id: String
    public let role: Role
    public var content: String
    public let date: Date

    public init(id: String = UUID().uuidString, role: Role, content: String, date: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.date = date
    }
}

/// A tool invocation observed while the assistant works.
public struct DecompileAssistToolEvent: Identifiable, Sendable {
    public enum State: String, Sendable {
        case started, completed, failed
    }
    public let id: String
    public let toolName: String
    public let state: State
    public let detail: String
    public let date: Date

    public init(id: String = UUID().uuidString, toolName: String, state: State,
                detail: String = "", date: Date = Date()) {
        self.id = id
        self.toolName = toolName
        self.state = state
        self.detail = detail
        self.date = date
    }
}

/// Decompile Assist session: owns the conversation, the Antigravity SDK
/// session, the system prompt assembled from bundled assets, and the tool
/// dispatcher that routes the model's tool calls into `YcodeDecompiler`'s
/// analysis store.
@MainActor
@Observable
public final class DecompileAssistSession {

    /// SDK session id — carries the `decompile-assist-` prefix so the shared
    /// runtime's tool dispatcher can route requests to this session.
    public let sdkSessionId: String
    public let decompilerSession: DecompilerSession

    public private(set) var id: String
    public private(set) var conversation: [DecompileAssistMessage] = []
    public private(set) var isProcessing = false
    public private(set) var lastError: String?
    public private(set) var currentSDKSession: GoogleCloudSDKSession?
    public private(set) var toolEvents: [DecompileAssistToolEvent] = []

    private let registry = DecompileAssistToolRegistry()
    private let assetLoader = DecompileAssistAssetLoader()
    private var eventTask: Task<Void, Never>?
    private var installedDispatcher = false

    public init(decompilerSession: DecompilerSession,
                id: String = DecompileAssistIdentity.sessionIDPrefix + UUID().uuidString) {
        self.decompilerSession = decompilerSession
        self.id = id
        self.sdkSessionId = id.hasPrefix(DecompileAssistIdentity.sessionIDPrefix)
            ? id
            : DecompileAssistIdentity.sessionIDPrefix + id
    }

    // MARK: - Sending

    /// Send a user message. `context` is the current analysis snapshot; it is
    /// serialized as JSON and prepended to the outbound text so every turn
    /// carries fresh focus information.
    public func send(_ text: String, context: DecompileAssistContext) async {
        guard !isProcessing else {
            lastError = "Decompile Assist is already processing a request."
            return
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isProcessing = true
        lastError = nil
        conversation.append(DecompileAssistMessage(role: .user, content: trimmed))

        // Placeholder assistant message filled in by stream events.
        let assistantIndex = conversation.count
        conversation.append(DecompileAssistMessage(role: .assistant, content: ""))

        do {
            try await ensureSDKSession(context: context)
            guard let sdk = currentSDKSession else {
                throw DecompilerError.engineUnavailable("Antigravity session unavailable")
            }
            let outbound = """
            ## Current Analysis Context
            ```json
            \(context.jsonBlock())
            ```

            \(trimmed)
            """
            try await sdk.sendMessage(outbound)
        } catch {
            conversation.remove(at: assistantIndex)
            lastError = error.localizedDescription
            isProcessing = false
        }
    }

    /// Ensure the Antigravity SDK session exists, with the system prompt and
    /// tool declarations installed, and the tool dispatcher chained.
    private func ensureSDKSession(context: DecompileAssistContext) async throws {
        if currentSDKSession != nil { return }

        let runtime = GoogleCloudSDKRuntime.shared
        try await runtime.ensureStarted()

        // Provider policy: Antigravity only — OAuth or Gemini API key.
        var config = try await DecompileAssistProviderPolicy.resolveConfiguration(objective: "decompile")

        let mode = await decompilerSession.mode
        let image = await decompilerSession.binary()
        config.systemInstructions = try assetLoader.corePrompt(
            mode: mode,
            architecture: image?.architecture,
            format: image?.format
        )
        config.tools = registry.toolSchemas()

        let session = try await runtime.createSession(id: sdkSessionId, config: config)
        currentSDKSession = session
        await installToolDispatcherIfNeeded()
        startEventSubscription(for: session)
    }

    // MARK: - Tool dispatch

    /// Chain into the shared runtime's tool-execution handler.
    ///
    /// `GoogleCloudSDKRuntime.toolExecutionHandler` is a single global slot.
    /// We capture whatever handler was installed before us; requests whose
    /// `sessionId` is not ours are forwarded to it unchanged. Our own requests
    /// (matched by the `decompile-assist-` session id) run through the
    /// Decompile Assist registry against this session's `DecompilerSession`.
    /// The chained handler is intentionally left installed — it is a no-op
    /// for other session ids and preserves any previously registered handler.
    private func installToolDispatcherIfNeeded() async {
        guard !installedDispatcher else { return }
        installedDispatcher = true

        let runtime = GoogleCloudSDKRuntime.shared
        let previous = runtime.toolExecutionHandler
        let registry = self.registry
        let decompilerSession = self.decompilerSession
        let sdkId = self.sdkSessionId

        let handler: @Sendable (GoogleCloudSDKToolExecutionRequest) async -> (success: Bool, result: String?, error: String?) = { request in
            guard request.sessionId == sdkId else {
                if let previous {
                    return await previous(request)
                }
                return (false, nil, "no tool execution handler for session \(request.sessionId)")
            }
            let result = await registry.execute(
                name: request.toolName,
                arguments: request.arguments,
                session: decompilerSession
            )
            // Determine success by parsing the structured payload.
            if let data = result.data(using: .utf8),
               let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let ok = obj["ok"] as? Bool {
                if ok { return (true, result, nil) }
                return (false, result, obj["error"] as? String ?? "tool error")
            }
            return (true, result, nil)
        }

        await runtime.setToolExecutionHandler(handler)
    }

    // MARK: - Events

    private func startEventSubscription(for session: GoogleCloudSDKSession) {
        eventTask?.cancel()
        let sdkId = session.id
        eventTask = Task { @MainActor [weak self] in
            let stream = await session.subscribeEvents()
            for await event in stream {
                guard let self else { return }
                self.handle(event: event, sdkSessionId: sdkId)
            }
        }
    }

    private func handle(event: GoogleCloudSDKEvent, sdkSessionId: String) {
        switch event {
        case .agentProgress(let sid, let delta, _):
            guard sid == sdkSessionId else { return }
            if let delta, !delta.isEmpty {
                appendToAssistant(delta)
            }

        case .agentCompleted(let sid, let response, _, _):
            guard sid == sdkSessionId else { return }
            if !response.isEmpty,
               let idx = conversation.indices.last, conversation[idx].role == .assistant,
               conversation[idx].content.isEmpty {
                // Stream produced nothing — use the authoritative final text.
                conversation[idx].content = response
            }
            isProcessing = false

        case .agentFailed(let sid, let error):
            guard sid == sdkSessionId else { return }
            lastError = error
            isProcessing = false
            if let idx = conversation.indices.last, conversation[idx].role == .assistant,
               conversation[idx].content.isEmpty {
                conversation.remove(at: idx)
            }

        case .toolStarted(let tool):
            guard tool.sessionId == sdkSessionId else { return }
            toolEvents.append(DecompileAssistToolEvent(toolName: tool.name, state: .started, detail: tool.rawArgs))

        case .toolCompleted(let result):
            guard result.sessionId == sdkSessionId else { return }
            toolEvents.append(DecompileAssistToolEvent(
                toolName: result.name,
                state: result.success ? .completed : .failed,
                detail: result.error ?? result.result
            ))
            trimToolEvents()

        case .toolFailed(_, let name, let error):
            toolEvents.append(DecompileAssistToolEvent(toolName: name, state: .failed, detail: error))
            trimToolEvents()

        case .error(let message):
            lastError = message

        default:
            break
        }
    }

    private func appendToAssistant(_ delta: String) {
        guard let idx = conversation.indices.last, conversation[idx].role == .assistant else { return }
        conversation[idx].content += delta
    }

    private func trimToolEvents() {
        if toolEvents.count > 500 {
            toolEvents.removeFirst(toolEvents.count - 500)
        }
    }

    // MARK: - Controls

    /// Clear the displayed error without touching the conversation. The next
    /// `send` also clears `lastError`.
    public func dismissError() {
        lastError = nil
    }

    /// Cancel the in-flight agent turn.
    public func cancel() async {
        guard let sdk = currentSDKSession else { return }
        try? await sdk.cancel()
        isProcessing = false
    }

    /// Clear the conversation and tool events, and close the SDK session so
    /// the next message starts with fresh context.
    public func clear() async {
        eventTask?.cancel()
        eventTask = nil
        if let sdk = currentSDKSession {
            try? await sdk.close()
            await GoogleCloudSDKRuntime.shared.closeSession(id: sdk.id)
        }
        currentSDKSession = nil
        conversation.removeAll()
        toolEvents.removeAll()
        lastError = nil
        isProcessing = false
    }
}
