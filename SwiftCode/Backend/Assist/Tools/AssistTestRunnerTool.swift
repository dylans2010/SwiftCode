import Foundation

public struct AssistTestRunnerTool: AssistTool {
    public let id = "project_test"
    public let name = "Run Tests"
    public let description = "Runs project test discovery and validation tasks from the functions layer."

    public init() {}

    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        do {
            let output = try await AssistExecutionFunctions.executeTask(id: id, context: context)
            return .success("Project test validation finished.", data: ["results": output])
        } catch {
            return .failure("Project test validation failed: \(error.localizedDescription)")
        }
    }
}
