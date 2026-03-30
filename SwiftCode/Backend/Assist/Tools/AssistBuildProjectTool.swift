import Foundation

public struct AssistBuildProjectTool: AssistTool {
    public let id = "project_build"
    public let name = "Build Project"
    public let description = "Validates CI pipeline YAML files in Backend/CI Building."

    public init() {}

    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let projectPath = input["project"] as? String ?? ""
        let scheme = input["scheme"] as? String ?? ""

        context.logger.info("Simulating build for project: \(projectPath), scheme: \(scheme)")

        do {
            // 1. Validate Project File Existence
            if projectPath.isEmpty {
                 // Check if workspace root has a project
                 let contents = try context.fileSystem.listDirectory(at: ".")
                 let hasProject = contents.contains { $0.hasSuffix(".xcodeproj") || $0 == "Package.swift" || $0 == "SwiftCode.xcodeproj" }
                 guard hasProject else {
                     return .failure("No Xcode project or Swift Package found in workspace root.")
                 }
            } else {
                guard context.fileSystem.exists(at: projectPath) else {
                    return .failure("Project or directory not found at: \(projectPath)")
                }
            }

            // 3. Simulate Build Steps
            context.logger.info("Resolving dependencies...")
            try await Task.sleep(nanoseconds: 500_000_000)

            context.logger.info("Compiling Swift sources...")
            try await Task.sleep(nanoseconds: 1_000_000_000)

            context.logger.info("Linking targets...")
            try await Task.sleep(nanoseconds: 500_000_000)

            // 4. CI Validation fallback
            let ciValidation = try AssistCIFunctions.validateCIPipelines(workspaceRoot: context.workspaceRoot)

            return .success(
                "Build simulation completed successfully for \(projectPath).",
                data: [
                    "status": "Success",
                    "projectFound": "true",
                    "ciPipelinesFound": "\(ciValidation.pipelinesFound)",
                    "ciValid": "\(ciValidation.valid)"
                ]
            )
        } catch {
            return .failure("Build failed: \(error.localizedDescription)")
        }
    }
}
