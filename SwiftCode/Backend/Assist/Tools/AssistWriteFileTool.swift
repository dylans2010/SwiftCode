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
            try AssistFileFunctions.writeFile(at: context.workspaceRoot.appendingPathComponent(path), content: content)
            return .success("Successfully wrote file: \(path)")
        } catch {
            return .failure("Failed to write file at \(path): \(error.localizedDescription)")
        }
    }
}
