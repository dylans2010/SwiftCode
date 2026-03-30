import Foundation

public struct AssistWriteFileTool: AssistTool {
    public let id = "file_write"
    public let name = "Write File"
    public let description = "Writes or overwrites a file with the specified content."

    public init() {}

    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let path = input["path"] as? String, let content = input["content"] as? String else {
            return .failure("Missing required parameters: path or content")
        }

        do {
            let fileURL = context.workspaceRoot.appendingPathComponent(path)
            let isNewFile = !FileManager.default.fileExists(atPath: fileURL.path)

            try AssistFileFunctions.writeFile(at: fileURL, content: content)

            // If it's a new file, we need to ensure the project manager refreshes the file tree.
            // Since AssistContext might not have direct access to MainActor ProjectManager for tree refreshes,
            // we rely on the fact that file writes are real.

            await MainActor.run {
                if let project = ProjectManager.shared.activeProject {
                    ProjectManager.shared.refreshFileTree(for: project)
                }
            }

            return .success("Successfully \(isNewFile ? "created" : "updated") file: \(path)")
        } catch {
            return .failure("Failed to write file at \(path): \(error.localizedDescription)")
        }
    }
}
