import Foundation

public struct PermissionEvent: Equatable {
    public let actorID: String
    public let title: String
    public let detail: String
    public let notifies: Bool
}

public enum CollaborationRole: String, Codable, CaseIterable {
    case owner
    case admin
    case member
}

@MainActor
public final class PermissionsManager: ObservableObject {
    @Published public private(set) var memberRoles: [String: CollaborationRole] = [:]
    @Published public private(set) var lastEvent: PermissionEvent?

    public init(creatorID: String) {
        self.memberRoles[creatorID] = .owner
    }

    public func restore(memberRoles: [String: CollaborationRole]) {
        self.memberRoles = memberRoles
    }

    public func assignRole(_ role: CollaborationRole, to memberID: String, by actorID: String) -> Bool {
        guard let actorRole = memberRoles[actorID], canManageRoles(actorRole) else { return false }
        if role == .owner && actorRole != .owner { return false }
        memberRoles[memberID] = role
        lastEvent = PermissionEvent(actorID: actorID, title: "Role updated", detail: "\(memberID) is now \(role.rawValue.capitalized).", notifies: true)
        return true
    }

    public func removeMember(_ memberID: String, by actorID: String) -> Bool {
        guard let actorRole = memberRoles[actorID], canManageRoles(actorRole) else { return false }
        guard memberRoles[memberID] != .owner else { return false }
        memberRoles.removeValue(forKey: memberID)
        lastEvent = PermissionEvent(actorID: actorID, title: "Collaborator removed", detail: "\(memberID) removed from project.", notifies: true)
        return true
    }

    public func canManageMembers(actorID: String) -> Bool {
        guard let role = memberRoles[actorID] else { return false }
        return canManageRoles(role)
    }

    public func hasPermission(_ permission: TransferPermission.Scope, for memberID: String, projectPermission: TransferPermission) -> Bool {
        guard let role = memberRoles[memberID] else { return false }
        if role == .owner { return true }
        if role == .admin { return projectPermission.allows(permission) }
        switch permission {
        case .viewFiles:
            return true
        case .editFiles, .createFiles, .deleteFiles, .renameFiles, .commit, .push, .pull, .branchCreateDelete, .merge:
            return projectPermission.allows(permission)
        default:
            return projectPermission.allows(permission)
        }
    }

    private func canManageRoles(_ role: CollaborationRole) -> Bool {
        role == .owner || role == .admin
    }
}
