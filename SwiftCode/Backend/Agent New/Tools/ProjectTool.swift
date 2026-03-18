import Foundation

@MainActor
final class ProjectTool {
    static let shared = ProjectTool()
    private init() {}

    func renameProject(to name: String) throws -> String {
        let project = try AgentPermissionAuthority.shared.authorize(scope: .renameProject, actor: "ProjectTool")
        try ProjectManager.shared.renameProject(project, to: name)
        return "Project renamed to \(name)"
    }

    func updateMetadata(description: String) throws -> String {
        let project = try AgentPermissionAuthority.shared.authorize(scope: .editMetadata, actor: "ProjectTool")
        ProjectManager.shared.updateDescription(description, for: project)
        return "Project metadata updated"
    }
}
