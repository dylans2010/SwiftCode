import Foundation

public enum CollaborationCapability: String, Codable, CaseIterable {
    case editFiles
    case commit
    case push
    case pull
    case merge
    case branchCreateDelete
    case manageMembers
    case viewActivity
    case comment
    case codeReview
}

public final class CollaborationRolesManager {
    public static func capabilities(for role: CollaborationRole) -> Set<CollaborationCapability> {
        switch role {
        case .owner:
            return Set(CollaborationCapability.allCases)
        case .admin:
            return Set(CollaborationCapability.allCases).subtracting([.manageMembers]) // Simplification: admin can't delete owner
        case .editor:
            return [.editFiles, .commit, .push, .pull, .viewActivity, .comment, .codeReview]
        case .viewer:
            return [.pull, .viewActivity, .comment]
        case .member:
            return [.pull, .viewActivity, .comment, .editFiles]
        }
    }

    public static func hasCapability(_ capability: CollaborationCapability, role: CollaborationRole) -> Bool {
        capabilities(for: role).contains(capability)
    }
}
