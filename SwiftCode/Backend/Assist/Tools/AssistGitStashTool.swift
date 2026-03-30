import Foundation

public struct AssistGitStashTool: AssistTool {
    public let id = "git_stash"
    public let name = "Git Stash"
    public let description = "Stashes the changes in a dirty working directory away."

    public init() {}

    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let action = input["action"] as? String ?? "push"
        return .success("Git stash \(action) completed (Simulated)")
    }
}
