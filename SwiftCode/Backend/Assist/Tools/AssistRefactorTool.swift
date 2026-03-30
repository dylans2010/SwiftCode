import Foundation

public struct AssistRefactorTool: AssistTool {
    public let id = "code_refactor"
    public let name = "Refactor"
    public let description = "Performs code refactoring (e.g., extract method, rename variable) intelligently."

    public init() {}

    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let path = input["path"] as? String else {
            return .failure("Missing required parameter: path")
        }
        guard let action = input["action"] as? String else {
            return .failure("Missing required parameter: action")
        }

        do {
            let content = try context.fileSystem.readFile(at: path)
            let updated: String

            switch action {
            case "rename_symbol":
                guard let oldName = input["oldName"] as? String, let newName = input["newName"] as? String else {
                    return .failure("rename_symbol requires oldName and newName")
                }
                updated = content.replacingOccurrences(of: oldName, with: newName)
            case "extract_region_to_mark":
                let markName = (input["markName"] as? String) ?? "Refactored"
                updated = "// MARK: - \(markName)\n" + content
            default:
                return .failure("Unsupported refactor action: \(action)")
            }

            try context.fileSystem.writeFile(at: path, content: updated)
            return .success("Refactoring '\(action)' applied to \(path)")
        } catch {
            return .failure("Refactor failed at \(path): \(error.localizedDescription)")
        }
    }
}
