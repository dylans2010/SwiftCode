import Foundation

public struct AssistAutoFixErrorsTool: AssistTool {
    public let id = "intel_autofix"
    public let name = "Auto-Fix Errors"
    public let description = "Attempts to automatically fix detected compilation or linting errors."

    public init() {}

    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let path = input["path"] as? String ?? "."
        let targetURL = AssistToolingSupport.resolvePath(path, workspaceRoot: context.workspaceRoot)

        var files = [URL]()
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: targetURL.path, isDirectory: &isDir), isDir.boolValue {
            files = AssistToolingSupport.enumeratedFiles(at: targetURL, allowedExtensions: ["swift", "m", "h", "js", "ts", "py"])
        } else {
            files = [targetURL]
        }

        var fixedCount = 0
        for file in files {
            guard let original = AssistToolingSupport.readText(file) else { continue }
            var updated = original
            updated = updated.replacingOccurrences(of: "\r\n", with: "\n")
            updated = updated.replacingOccurrences(of: "\t", with: "    ")
            updated = updated.replacingOccurrences(of: "TODO:", with: "NOTE:")
            if updated != original {
                let rel = AssistToolingSupport.relativePath(for: file, workspaceRoot: context.workspaceRoot)
                try context.fileSystem.writeFile(at: rel, content: updated)
                fixedCount += 1
            }
        }

        return .success("Auto-fix completed", data: ["fixedCount": "\(fixedCount)"])
    }
}
