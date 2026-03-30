import Foundation

public struct AssistGitAddTool: AssistTool {
    public let id = "git_add"
    public let name = "Git Add"
    public let description = "Adds file contents to the index."

    public init() {}

    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let path = input["path"] as? String else {
            return .failure("Missing required parameter: path")
        }
        return .success("Added \(path) to git index (Simulated)")
    }
}
