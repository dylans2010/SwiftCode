import Foundation

public struct AssistGitMergeTool: AssistTool {
    public let id = "git_merge"
    public let name = "Git Merge"
    public let description = "Joins two or more development histories together."

    public init() {}

    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let branch = input["branch"] as? String else {
            return .failure("Missing required parameter: branch")
        }
        return .success("Merged \(branch) (Simulated)")
    }
}
