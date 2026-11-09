import Foundation





@MainActor
public struct WorkerMessageTool: AssistTool {
    public let id = "worker_message"
    public let name = "Message Workers"
    public let description = """
    Send a message to Assist Workers or report back to the parent agent.
    Use 'to' = a worker name to reach one worker, 'broadcast' to reach all
    workers, or 'parent' to leave a message for the orchestrator. Messages
    are queued and delivered to a worker the next time it is scheduled.
    """

    public var parametersSchema: JSONSchema {
        JSONSchema(
            type: "object",
            description: "Send a message through the Worker mailbox.",
            properties: [
                "to": JSONSchema(
                    type: "string",
                    description: "Recipient: a worker name, 'broadcast', or 'parent'."
                ),
                "message": JSONSchema(
                    type: "string",
                    description: "The message text (max ~1000 characters)."
                )
            ],
            required: ["to", "message"]
        )
    }

    public var capability: ToolCapability { .planning }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }

    public init() {}

    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let to = (input["to"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !to.isEmpty else {
            return .failure("Missing required parameter 'to' (worker name, 'broadcast', or 'parent').")
        }
        guard let raw = (input["message"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return .failure("Missing required parameter 'message'.")
        }
        let message = raw.count > 1000 ? String(raw.prefix(997)) + "..." : raw
        let sender = "parent(\(context.sessionId.uuidString.prefix(8)))"
        guard let sent = WorkerMailbox.shared.send(from: sender, to: to, text: message) else {
            return .failure("The message was empty.")
        }

        let workers = WorkerRuntimeState.shared.allWorkers
        var roster = ""
        if !workers.isEmpty {
            roster = "\n\nCurrent workers:\n" + workers.map {
                "- \($0.name) (\($0.status.rawValue))"
            }.joined(separator: "\n")
        }
        return .success("Message queued: \(sent.summary)\(roster)", data: [
            "recipient": to,
            "workerCount": "\(workers.count)"
        ])
    }
}
