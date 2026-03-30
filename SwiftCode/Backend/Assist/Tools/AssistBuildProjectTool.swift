import Foundation

public struct AssistBuildProjectTool: AssistTool {
    public let id = "project_build"
    public let name = "Build Project"
    public let description = "Validates CI pipeline YAML files in Backend/CI Building."

    public init() {}

    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        do {
            let validation = try AssistCIFunctions.validateCIPipelines(workspaceRoot: context.workspaceRoot)
            let errors = validation.errors.joined(separator: "\n")

            return .success(
                "CI pipeline validation finished.",
                data: [
                    "pipelinesFound": "\(validation.pipelinesFound)",
                    "valid": "\(validation.valid)",
                    "invalid": "\(validation.invalid)",
                    "errors": errors.isEmpty ? "[]" : errors,
                    "validPipelines": validation.validPipelines.joined(separator: ",")
                ]
            )
        } catch {
            return .failure("CI pipeline validation failed: \(error.localizedDescription)")
        }
    }
}
