import Foundation

public struct AssistGitStatusTool: AssistTool {
    public let id = "git_status"
    public let name = "Git Status"
    public let description = "Shows the working tree status."

    public init() {}

    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        do {
            let status = try context.git.status()
            return .success("Git status: \(status)", data: ["status": status])
        } catch {
            return .failure("Failed to get git status: \(error.localizedDescription)")
        }
    }
}
