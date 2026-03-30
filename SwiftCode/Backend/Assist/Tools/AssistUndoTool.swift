import Foundation

public struct AssistUndoTool: AssistTool {
    public let id = "safe_undo"
    public let name = "Undo Last Action"
    public let description = "Reverts the last modification made by the agent."

    public init() {}

    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        return .success("Last action undone (Simulated)")
    }
}
