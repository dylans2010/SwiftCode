import Foundation

public struct OperationPermissionOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public static let permissionsRelativePath = "security/permissions.json"
    public static let roleRelativePath = "security/role.json"

    public enum Role: String, Codable, Sendable, CaseIterable {
        case admin
        case developer
        case reviewer
        case reader
    }

    public struct OperationPermissions: Codable, Sendable {
        public var operations: [String: [Role]]

        public init(operations: [String: [Role]] = [:]) {
            self.operations = operations
        }

        public static func defaultPermissions() -> OperationPermissions {
            OperationPermissions(operations: [
                "commit": [.admin, .developer],
                "push": [.admin, .developer],
                "branch-create": [.admin, .developer],
                "branch-delete": [.admin],
                "tag": [.admin, .developer],
                "merge": [.admin, .developer],
                "snapshot": [.admin, .developer, .reviewer, .reader],
                "read": [.admin, .developer, .reviewer, .reader],
            ])
        }
    }

    public struct RoleRecord: Codable, Sendable {
        public var role: Role

        public init(role: Role) {
            self.role = role
        }
    }

    public func operationPermissions() throws -> OperationPermissions {
        try SecurityFileStore.load(repo: repo, relativePath: Self.permissionsRelativePath)
            ?? OperationPermissions.defaultPermissions()
    }

    public func setOperationPermissions(_ permissions: OperationPermissions) throws {
        try repo.withLock {
            try SecurityFileStore.save(repo: repo, relativePath: Self.permissionsRelativePath, value: permissions)
        }
    }

    public func currentRole() throws -> Role {
        let record: RoleRecord? = try SecurityFileStore.load(repo: repo, relativePath: Self.roleRelativePath)
        return record?.role ?? .developer
    }

    public func setRole(_ role: Role) throws {
        try repo.withLock {
            try SecurityFileStore.save(repo: repo, relativePath: Self.roleRelativePath, value: RoleRecord(role: role))
        }
    }

    public func checkOperationPermission(operation: String, role: Role) throws -> Bool {
        let permissions = try operationPermissions()
        guard let allowed = permissions.operations[operation] else { return false }
        return allowed.contains(role)
    }
}
