import Foundation

extension SpacesAPI {
    public func repositoryPolicy() throws -> PolicyEngineOps.RepositoryPolicy {
        try PolicyEngineOps(repo: repo).repositoryPolicy()
    }

    public func setRepositoryPolicy(_ policy: PolicyEngineOps.RepositoryPolicy) throws {
        try PolicyEngineOps(repo: repo).setRepositoryPolicy(policy)
    }

    public func checkPolicy(operation: PolicyEngineOps.PolicyOperation,
                            details: PolicyEngineOps.PolicyOperationDetails = PolicyEngineOps.PolicyOperationDetails()) throws -> [PolicyEngineOps.PolicyViolation] {
        try PolicyEngineOps(repo: repo).checkPolicy(operation: operation, details: details)
    }

    public func secretHistory(limit: Int = 100) throws -> [SecretHistoryOps.SecretFinding] {
        try SecretHistoryOps(repo: repo).secretHistory(limit: limit)
    }

    public func classificationRules() throws -> DataClassificationOps.ClassificationRuleSet {
        try DataClassificationOps(repo: repo).classificationRules()
    }

    public func setClassificationRules(_ rules: DataClassificationOps.ClassificationRuleSet) throws {
        try DataClassificationOps(repo: repo).setClassificationRules(rules)
    }

    public func classifyPath(_ path: String) throws -> [String] {
        let content: String
        let worktreeFile = try repo.worktreeURL(forRelativePath: path)
        if FileManager.default.fileExists(atPath: worktreeFile.path) {
            content = try String(contentsOf: worktreeFile, encoding: .utf8)
        } else {
            let index = try repo.index()
            guard let entry = index.entries[path] else { throw SpacesError.pathNotFound(path) }
            let data = try repo.blobData(entry.oid)
            guard let text = String(data: data, encoding: .utf8) else {
                throw SpacesError.invalidArgument("file \(path) is not readable as text")
            }
            content = text
        }
        return try DataClassificationOps(repo: repo).classify(path: path, content: content)
    }

    public func classifyRepository() throws -> [DataClassificationOps.ClassificationResult] {
        try DataClassificationOps(repo: repo).classifyRepository()
    }

    public func verifyProvenance(rev: String) throws -> [ProvenanceOps.ProvenanceCheck] {
        try ProvenanceOps(repo: repo).verifyProvenance(rev: rev)
    }

    public func trustPolicy() throws -> ProvenanceOps.TrustPolicy {
        try ProvenanceOps(repo: repo).trustPolicy()
    }

    public func setTrustPolicy(_ policy: ProvenanceOps.TrustPolicy) throws {
        try ProvenanceOps(repo: repo).setTrustPolicy(policy)
    }

    public func recordAuditEvent(operation: String, details: String, result: String) throws {
        try AccessAuditOps(repo: repo).recordAuditEvent(operation: operation, details: details, result: result)
    }

    public func auditEvents(limit: Int = 100) throws -> [AccessAuditOps.AuditEvent] {
        try AccessAuditOps(repo: repo).auditEvents(limit: limit)
    }

    public func operationPermissions() throws -> OperationPermissionOps.OperationPermissions {
        try OperationPermissionOps(repo: repo).operationPermissions()
    }

    public func operationPermissionNote() -> String {
        OperationPermissionOps.guardrailNote
    }

    public func setOperationPermissions(_ permissions: OperationPermissionOps.OperationPermissions) throws {
        try OperationPermissionOps(repo: repo).setOperationPermissions(permissions)
        try? AccessAuditOps(repo: repo).recordAuditEvent(
            operation: "permissions-change", details: "", result: "success")
    }

    public func checkOperationPermission(operation: String, role: OperationPermissionOps.Role) throws -> Bool {
        try OperationPermissionOps(repo: repo).checkOperationPermission(operation: operation, role: role)
    }

    public func currentRole() throws -> OperationPermissionOps.Role {
        try OperationPermissionOps(repo: repo).currentRole()
    }

    public func setRole(_ role: OperationPermissionOps.Role) throws {
        let previous = try OperationPermissionOps(repo: repo).currentRole()
        try OperationPermissionOps(repo: repo).setRole(role)
        try? AccessAuditOps(repo: repo).recordAuditEvent(
            operation: "role-change",
            details: "\(previous.rawValue) -> \(role.rawValue)", result: "success")
    }

    @discardableResult
    public func signSnapshot(_ rev: String) throws -> String {
        try SignedSnapshotOps(repo: repo).signSnapshot(rev: rev)
    }

    public func signedSnapshotInfo(_ rev: String) throws -> SignedSnapshotOps.SnapshotSignatureInfo {
        try SignedSnapshotOps(repo: repo).snapshotSignatureInfo(rev: rev)
    }

    public func verifySnapshotSignature(_ rev: String) throws -> Bool {
        try SignedSnapshotOps(repo: repo).verifySnapshotSignature(rev: rev)
    }

    public func protectedHistoryRules() throws -> ProtectedHistoryOps.ProtectedHistoryRules {
        try ProtectedHistoryOps(repo: repo).protectedHistoryRules()
    }

    public func setProtectedHistoryRules(_ rules: ProtectedHistoryOps.ProtectedHistoryRules) throws {
        try ProtectedHistoryOps(repo: repo).setProtectedHistoryRules(rules)
    }

    public func checkProtectedHistory(ref: String, operation: String) throws -> (allowed: Bool, reasons: [String]) {
        try ProtectedHistoryOps(repo: repo).checkProtectedHistory(ref: ref, operation: operation)
    }

    public func dependencyChangeAudit(limit: Int = 100) throws -> [DependencyAuditOps.DependencyChange] {
        try DependencyAuditOps(repo: repo).dependencyChangeAudit(limit: limit)
    }

    public func generateSecurityReport() throws -> SecurityReportOps.SecurityReport {
        try SecurityReportOps(repo: repo).generateSecurityReport()
    }
}
