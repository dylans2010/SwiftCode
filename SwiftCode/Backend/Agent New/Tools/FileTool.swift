import Foundation

@MainActor
final class FileTool {
    static let shared = FileTool()
    private init() {}

    func read(path: String) async throws -> String {
        let project = try AgentPermissionAuthority.shared.authorize(scope: .viewFiles, path: path, actor: "FileTool")
        return try await CodeReaderManager.shared.readFileAsync(project: project.name, relativePath: path)
    }

    func write(path: String, content: String) throws -> String {
        let project = try AgentPermissionAuthority.shared.authorize(scope: .allowAgentFileModification, path: path, actor: "FileTool")
        let original = (try? String(contentsOf: project.directoryURL.appendingPathComponent(path))) ?? ""
        try CodingManager.shared.writeFile(content: content, at: path, in: project.directoryURL)
        CodePatchEngine.shared.createPatch(filePath: path, originalContent: original, modifiedContent: content)
        ProjectManager.shared.refreshFileTree(for: project)
        return "Updated \(path)"
    }

    func create(path: String, content: String) throws -> String {
        let project = try AgentPermissionAuthority.shared.authorize(scope: .createFiles, path: path, actor: "FileTool")
        let fileURL = project.directoryURL.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        ProjectManager.shared.refreshFileTree(for: project)
        return "Created \(path)"
    }

    func delete(path: String) throws -> String {
        let project = try AgentPermissionAuthority.shared.authorize(scope: .deleteFiles, path: path, actor: "FileTool")
        try CodingManager.shared.deleteItem(at: path, in: project.directoryURL)
        ProjectManager.shared.refreshFileTree(for: project)
        return "Deleted \(path)"
    }
}
