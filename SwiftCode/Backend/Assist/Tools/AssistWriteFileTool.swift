import Foundation

public struct AssistWriteFileTool: AssistTool {
    public let id = "file_write"
    public let name = "Write File"
    public let description = "Writes content to a file at the specified path, overwriting if it exists."

    public init() {}

    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let path = input["path"] as? String else {
            return .failure("Missing required parameter: path")
        }
        guard let content = input["content"] as? String else {
            return .failure("Missing required parameter: content")
        }

        do {
            try context.fileSystem.writeFile(at: path, content: content)
            return .success("Successfully wrote to file: \(path)")
        } catch {
            return .failure("Failed to write to file at \(path): \(error.localizedDescription)")
        }
    }
}
