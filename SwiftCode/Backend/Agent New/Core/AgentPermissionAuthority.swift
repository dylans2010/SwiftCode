import Foundation

enum AgentPermissionError: LocalizedError {
    case noActiveProject
    case denied(scope: TransferPermission.Scope, reason: String)

    var errorDescription: String? {
        switch self {
        case .noActiveProject:
            return "No active project is open."
        case .denied(let scope, let reason):
            return "Permission denied for \(scope.rawValue): \(reason)"
        }
    }
}

@MainActor
final class AgentPermissionAuthority {
    static let shared = AgentPermissionAuthority()
    private init() {}

    func authorize(scope: TransferPermission.Scope, path: String? = nil, actor: String = "agent") throws -> Project {
        guard let project = ProjectManager.shared.activeProject else { throw AgentPermissionError.noActiveProject }
        let permission = project.transferConfiguration?.permission ?? .owner
        let allowed = permission.allows(scope, path: path)
        ProjectManager.shared.recordTransferAudit(for: project, actor: actor, action: scope.rawValue, path: path, allowed: allowed, detail: allowed ? "Authorized" : "Denied by transfer permission")
        guard allowed else {
            throw AgentPermissionError.denied(scope: scope, reason: permission.isExpired ? "Permission expired" : "Project policy blocked this action")
        }
        return project
    }
}
