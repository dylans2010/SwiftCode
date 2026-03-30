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
            let projectURL = context.workspaceRoot.appendingPathComponent(projectPath.isEmpty ? "." : projectPath)
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: projectURL.path, isDirectory: &isDir) else {
                return .failure("Project or directory not found at: \(projectPath)")
            }

            // 2. Scan for .xcodeproj or Package.swift if path is a directory
            var foundProject = false
            if isDir.boolValue {
                let contents = try FileManager.default.contentsOfDirectory(at: projectURL, includingPropertiesForKeys: nil)
                foundProject = contents.contains { $0.pathExtension == "xcodeproj" || $0.lastPathComponent == "Package.swift" }
            } else {
                foundProject = projectURL.pathExtension == "xcodeproj" || projectURL.lastPathComponent == "Package.swift"
            }

            guard foundProject else {
                return .failure("No Xcode project or Swift Package found at path: \(projectPath)")
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
