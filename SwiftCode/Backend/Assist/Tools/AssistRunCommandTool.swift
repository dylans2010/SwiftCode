import Foundation

public struct AssistRunCommandTool: AssistTool {
    public let id = "env_run_command"
    public let name = "Run Shell Command"
    public let description = "Executes a shell command in the project environment."

    public init() {}

    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let command = input["command"] as? String else {
            return .failure("Missing required parameter: command")
        }

        return .success("Command '\(command)' executed (Simulated)", data: ["output": "Simulation output."])
    }
}
