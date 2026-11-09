import Foundation
import os

@available(*, deprecated, renamed: "AssistAgentSession")
public actor AgentOrchestrator {
    private let pipelineLogger = Logger(subsystem: "com.swiftcode.app", category: "AgentPipeline")
    private var isCancelled = false

    public init() {}

    public func runTurn(session: AgentSession, userMessage: String, attachments: [AgentAttachment] = []) async throws {
        isCancelled = false
        pipelineLogger.info("[runTurn] Starting turn. User message: \(userMessage, privacy: .public). Attachments count: \(attachments.count).")

        await MainActor.run {
            session.turnState = .awaitingModel
        }

        var contents: [AgentMessageContent] = [.text(userMessage)]

        let message = AgentMessage(role: .user, content: contents)
        await MainActor.run {
            session.messages.append(message)
            session.turnState = .idle
        }
    }

    public func resumeTurn(session: AgentSession, result: String, toolCallId: String) async throws {
        pipelineLogger.info("[resumeTurn] Resuming turn for toolCallId: \(toolCallId, privacy: .public).")
        let toolResultMessage = AgentMessage(role: .assistant, content: [.toolResult(AgentToolResult(toolCallId: toolCallId, content: result))])
        await MainActor.run {
            session.messages.append(toolResultMessage)
            session.turnState = .idle
        }
    }

    public func cancel() {
        pipelineLogger.info("[cancel] Cancelling active turn.")
        isCancelled = true
    }
}
