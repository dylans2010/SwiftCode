import Foundation

public struct AssistGitDiffTool: AssistTool {
    public let id = "git_diff"
    public let name = "Git Diff"
    public let description = "Shows changes between commits, commit and working tree, etc."

    public init() {}

    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        return .success("Git diff generated (Simulated)", data: ["diff": "No changes."])
    }
}
