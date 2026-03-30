import Foundation

public struct AssistRunScriptTool: AssistTool {
    public let id = "env_run_script"
    public let name = "Run Script"
    public let description = "Runs a script file (e.g., .sh, .py, .js) from the project."

    public init() {}

    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let path = input["path"] as? String else {
            return .failure("Missing required parameter: path")
        }

        return .success("Script \(path) executed (Simulated)")
    }
}
