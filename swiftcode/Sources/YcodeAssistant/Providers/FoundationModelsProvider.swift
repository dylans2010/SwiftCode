import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

public struct FoundationModelsProvider: AssistantProvider {
    public let kind = ProviderKind.foundationModels

    public static let modelID = "AFM 3 Core"
    public static let modelDisplayName = "Apple AFM 3 Core (On-Device)"

    public init() {}

    public static var unavailableHint: String {
        "Apple Foundation Models is not available on this device. It needs macOS 26 or later on an Apple Intelligence-capable Mac, with Apple Intelligence turned on."
    }

    public func availability() async -> ProviderAvailability {
#if canImport(FoundationModels)
        if #available(macOS 26.0, iOS 26.0, *) {
            return await realAvailability()
        }
        return .notInstalled(hint: Self.unavailableHint)
#else
        return .notInstalled(hint: Self.unavailableHint)
#endif
    }

    public func contextWindow(model: String) async -> Int? {
        guard model == Self.modelID else { return nil }
#if canImport(FoundationModels)
        if #available(macOS 26.0, iOS 26.0, *) {
            guard SystemLanguageModel.default.isAvailable else { return nil }
            return await SystemLanguageModel.default.contextSize
        }
#endif
        return nil
    }

    public func send(_ request: ChatRequest) -> AsyncThrowingStream<ChatEvent, Error> {
        eventStream { out in
            let prompt = Self.promptText(request)
            guard !prompt.isEmpty else { throw AssistantError.failed("There is no message to send.") }
#if canImport(FoundationModels)
            if #available(macOS 26.0, iOS 26.0, *) {
                try await Self.stream(request: request, prompt: prompt, out: out)
                return
            }
            throw AssistantError.failed(Self.unavailableHint)
#else
            throw AssistantError.failed(Self.unavailableHint)
#endif
        }
    }

    static func promptText(_ request: ChatRequest) -> String {
        var parts: [String] = []
        for message in request.messages.dropLast() {
            parts.append("<\(message.role.rawValue)>\n\(message.content)\n</\(message.role.rawValue)>")
        }
        if let last = request.messages.last {
            parts.append(last.content)
        }
        return parts.joined(separator: "\n\n")
    }

    static func delta(_ snapshot: String, after previous: String) -> String? {
        if snapshot == previous { return nil }
        if snapshot.hasPrefix(previous) {
            let d = String(snapshot.dropFirst(previous.count))
            return d.isEmpty ? nil : d
        }
        return snapshot
    }

#if canImport(FoundationModels)
    @available(macOS 26.0, iOS 26.0, *)
    struct AssistFoundationModelsTool: Tool, Sendable {
        let name = "swiftcode_tool"
        let description = "Invoke any registered SwiftCode native tool by its exact tool id. Use this whenever the task needs workspace files, code, builds, tests, diagnostics, or any other capability listed in the tool catalog. Pass the tool id in toolName and a JSON object of its arguments in argumentsJSON."
        let workspaceRoot: URL
        let sessionId: UUID

        @Generable
        struct Arguments {
            @Guide(description: "The exact registered SwiftCode tool id to invoke, for example file_read.")
            var toolName: String
            @Guide(description: "A JSON object string holding the arguments for the named tool.")
            var argumentsJSON: String
        }

        func call(arguments: Arguments) async throws -> String {
            await Self.execute(toolName: arguments.toolName, argumentsJSON: arguments.argumentsJSON, workspaceRoot: workspaceRoot, sessionId: sessionId)
        }

        @MainActor
        static func execute(toolName: String, argumentsJSON: String, workspaceRoot: URL, sessionId: UUID) async -> String {
            let registry = AssistToolRegistry.shared
            guard let data = argumentsJSON.data(using: .utf8),
                  let arguments = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return "Tool call rejected: arguments were not a JSON object. Pass the tool arguments as a JSON object string."
            }
            guard let tool = registry.resolve(toolId: toolName) else {
                return "Tool '\(toolName)' is not registered in SwiftCode Assist. Pick a tool id from the tool catalog."
            }
            guard AssistToolRegistry.allowsExecution(toolId: tool.id) else {
                return AssistToolRegistry.executionRefusal(toolId: tool.id)
            }
            let validation = registry.validate(toolId: tool.id, arguments: arguments)
            guard validation.isValid else {
                return "Tool '\(tool.id)' failed validation: \(validation.issue ?? "invalid arguments"). Nothing was executed."
            }
            let builder = AssistContextBuilder(
                logger: AssistLogger(),
                permissions: AssistPermissionsManager(),
                memory: AssistMemoryGraph(),
                fileSystem: AssistFileSystem(workspaceRoot: workspaceRoot),
                git: AssistGitManager(project: ProjectSessionStore.shared.activeProject)
            )
            let context = builder.buildContext(sessionId: sessionId)
            let result: AssistToolResult
            do {
                result = try await tool.execute(input: validation.correctedInput ?? arguments, context: context)
            } catch {
                return "Tool '\(tool.id)' failed: \(error.localizedDescription)"
            }
            if result.success {
                registry.markUsed(tool.id)
            } else {
                registry.markError(tool.id, error: result.error ?? result.output)
            }
            return AssistToolResultFormatter.modelFacingPayload(toolId: tool.id, result: result)
        }
    }

    @available(macOS 26.0, iOS 26.0, *)
    private func realAvailability() async -> ProviderAvailability {
        switch SystemLanguageModel.default.availability {
        case .available:
            let window = await SystemLanguageModel.default.contextSize
            return .ready([ModelInfo(id: Self.modelID, displayName: Self.modelDisplayName, contextWindow: window)])
        case .unavailable(let reason):
            if case .deviceNotEligible = reason {
                return .notInstalled(hint: "This device cannot run Apple Foundation Models. It needs an Apple Intelligence-capable Mac.")
            }
            return .failed(Self.unavailableMessage(for: reason))
        @unknown default:
            return .failed("Apple Foundation Models reported an unknown availability state.")
        }
    }

    @available(macOS 26.0, iOS 26.0, *)
    private static func unavailableMessage(for reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        if case .appleIntelligenceNotEnabled = reason {
            return "Apple Intelligence is turned off. Turn it on in System Settings to use Apple Foundation Models."
        }
        if case .modelNotReady = reason {
            return "The Apple Foundation Models on-device model is still downloading. Try again later."
        }
        if case .deviceNotEligible = reason {
            return "This device cannot run Apple Foundation Models. It needs an Apple Intelligence-capable Mac."
        }
        return "Apple Foundation Models is unavailable on this device."
    }

    @available(macOS 26.0, iOS 26.0, *)
    private static func stream(
        request: ChatRequest,
        prompt: String,
        out: AsyncThrowingStream<ChatEvent, Error>.Continuation
    ) async throws {
        guard SystemLanguageModel.default.isAvailable else {
            if case .unavailable(let reason) = SystemLanguageModel.default.availability {
                throw AssistantError.failed(Self.unavailableMessage(for: reason))
            }
            throw AssistantError.failed(Self.unavailableHint)
        }
        let workspaceRoot = await MainActor.run {
            request.workingDirectory
                ?? ProjectSessionStore.shared.activeProject?.directoryURL
                ?? FileManager.default.homeDirectoryForCurrentUser
        }
        let toolCatalog = await MainActor.run { AssistToolRegistry.shared.formattedToolCatalog() }
        let toolProtocol = """
        You have a native tool named swiftcode_tool that invokes any registered SwiftCode tool. To use a tool, call swiftcode_tool with the exact tool id from the catalog below in toolName and a JSON object of its arguments in argumentsJSON. Never claim you have no tools. The full registered tool catalog follows:

        \(toolCatalog)
        """
        let combinedInstructions = request.instructions.isEmpty
            ? toolProtocol
            : "\(request.instructions)\n\n\(toolProtocol)"
        let instructions: Instructions? = Instructions(combinedInstructions)
        let tool = AssistFoundationModelsTool(workspaceRoot: workspaceRoot, sessionId: UUID())
        let session = LanguageModelSession(model: SystemLanguageModel.default, tools: [tool], instructions: instructions)
        var emitted = ""
        do {
            for try await snapshot in session.streamResponse(to: prompt) {
                try Task.checkCancellation()
                let text = snapshot.content
                if let d = Self.delta(text, after: emitted) {
                    out.yield(.text(d))
                }
                emitted = text
            }
        } catch let error as LanguageModelSession.GenerationError {
            throw Self.mapGenerationError(error)
        } catch is LanguageModelSession.ToolCallError {
            throw AssistantError.failed("Apple Foundation Models failed while calling a SwiftCode tool. The tool itself reported the failure in the conversation; retry the request or pick a different tool.")
        }
        out.yield(.finished(nil))
    }

    @available(macOS 26.0, iOS 26.0, *)
    private static func mapGenerationError(_ error: LanguageModelSession.GenerationError) -> AssistantError {
        if case .exceededContextWindowSize = error {
            return .failed("The conversation is too long for the Apple Foundation Models on-device model. Start a new conversation or shorten the request.")
        }
        if case .rateLimited = error {
            return .temporarilyUnavailable("Apple Foundation Models is busy right now. Try again shortly.")
        }
        if case .guardrailViolation = error {
            return .failed("Apple Foundation Models declined this request.")
        }
        return .failed(error.localizedDescription)
    }
#endif
}
