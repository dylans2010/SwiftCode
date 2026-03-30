import Foundation

public struct AssistGitCheckoutTool: AssistTool {
    public let id = "git_checkout"
    public let name = "Git Checkout"
    public let description = "Switches branches or restores working tree files."

    public init() {}

    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let target = input["target"] as? String else {
            return .failure("Missing required parameter: target")
        }
        return .success("Switched to \(target) (Simulated)")
    }
}
