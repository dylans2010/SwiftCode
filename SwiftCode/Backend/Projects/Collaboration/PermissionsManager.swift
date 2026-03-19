import Foundation

public enum CollaborationRole: String, Codable, CaseIterable {
    case owner
    case admin
    case member
}

@MainActor
public final class PermissionsManager: ObservableObject {
    @Published public private(set) var memberRoles: [String: CollaborationRole] = [:]

    public init(creatorID: String) {
        self.memberRoles[creatorID] = .owner
    }

    public func assignRole(_ role: CollaborationRole, to memberID: String, by actorID: String) -> Bool {
        guard let actorRole = memberRoles[actorID], canManageRoles(actorRole) else { return false }
        if role == .owner && actorRole != .owner { return false }
        memberRoles[memberID] = role
        return true
    }

    public func removeMember(_ memberID: String, by actorID: String) -> Bool {
        guard let actorRole = memberRoles[actorID], canManageRoles(actorRole) else { return false }
        guard memberRoles[memberID] != .owner else { return false }
        memberRoles.removeValue(forKey: memberID)
        return true
    }

    public func hasPermission(_ permission: TransferPermission.Scope, for memberID: String, projectPermission: TransferPermission) -> Bool {
        guard let role = memberRoles[memberID] else { return false }
        if role == .owner { return true }
        if role == .admin {
            // Admins have elevated but not absolute permissions
            return projectPermission.allows(permission)
        }
        return projectPermission.allows(permission)
    }

    private func canManageRoles(_ role: CollaborationRole) -> Bool {
        return role == .owner || role == .admin
    }
}
