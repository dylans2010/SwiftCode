import Foundation

public struct OperationPermissionOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public static let permissionsRelativePath = "security/permissions.json"
    public static let roleRelativePath = "security/role.json"

    public static let guardrailNote = "Operation permissions are a single-user local guardrail, not multi-user access control: there is one local actor (the repository identity) and the current role is a local setting. Enforcement only applies when a permissions file has been configured; with no configured permissions every operation is allowed."

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
                "merge": [.admin, .developer],
                "reset": [.admin, .developer],
                "tag": [.admin, .developer],
                "snapshot": [.admin, .developer, .reviewer, .reader],
                "read": [.admin, .developer, .reviewer, .reader],
            ])
        }
    }

    public func hasConfiguredPermissions() -> Bool {
        let url = repo.metaURL.appendingPathComponent(Self.permissionsRelativePath)
        return FileManager.default.fileExists(atPath: url.path)
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
