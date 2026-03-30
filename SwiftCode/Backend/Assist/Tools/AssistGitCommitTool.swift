import Foundation

public struct AssistGitCommitTool: AssistTool {
    public let id = "git_commit"
    public let name = "Git Commit"
    public let description = "Records changes to the repository."

    public init() {}

    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let message = input["message"] as? String else {
            return .failure("Missing required parameter: message")
        }

        do {
            try context.git.commit(message: message)
            return .success("Committed with message: \(message)")
        } catch {
            return .failure("Failed to commit: \(error.localizedDescription)")
        }
    }
}
