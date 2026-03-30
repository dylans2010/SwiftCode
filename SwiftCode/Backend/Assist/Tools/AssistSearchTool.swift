import Foundation

public struct AssistSearchTool: AssistTool {
    public let id = "search_text"
    public let name = "Search Text"
    public let description = "Searches for a string within the project files."

    public init() {}

    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let query = input["query"] as? String else {
            return .failure("Missing required parameter: query")
        }

        let fileManager = FileManager.default
        var results: [String] = []

        func search(at url: URL) {
            if let contents = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) {
                for item in contents {
                    var isDir: ObjCBool = false
                    if fileManager.fileExists(atPath: item.path, isDirectory: &isDir), isDir.boolValue {
                        search(at: item)
                    } else if let content = try? String(contentsOf: item, encoding: .utf8), content.contains(query) {
                        results.append(item.path.replacingOccurrences(of: context.workspaceRoot.path, with: ""))
                    }
                }
            }
        }

        search(at: context.workspaceRoot)

        return .success("Search completed for '\(query)'", data: ["results": results.joined(separator: "\n")])
    }
}
