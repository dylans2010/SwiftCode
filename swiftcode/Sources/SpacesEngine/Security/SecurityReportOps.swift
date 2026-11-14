import Foundation

public struct SecurityReportOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public struct ProvenanceEntry: Codable, Sendable {
        public var commit: String
        public var checks: [ProvenanceOps.ProvenanceCheck]
        public var allPassed: Bool

        public init(commit: String, checks: [ProvenanceOps.ProvenanceCheck]) {
            self.commit = commit
            self.checks = checks
            self.allPassed = checks.allSatisfy { $0.passed }
        }
    }

    public struct SecurityReport: Codable, Sendable {
        public var generatedAt: Int64
        public var secretFindings: [SecretHistoryOps.SecretFinding]
        public var secretFindingCount: Int
        public var classificationSummary: [String: Int]
        public var provenance: [ProvenanceEntry]
        public var auditEventCount: Int
        public var auditEventsByOperation: [String: Int]
        public var policyViolations: [PolicyEngineOps.PolicyViolation]

        public init(generatedAt: Int64, secretFindings: [SecretHistoryOps.SecretFinding],
                    classificationSummary: [String: Int], provenance: [ProvenanceEntry],
                    auditEventCount: Int, auditEventsByOperation: [String: Int],
                    policyViolations: [PolicyEngineOps.PolicyViolation]) {
            self.generatedAt = generatedAt
            self.secretFindings = secretFindings
            self.secretFindingCount = secretFindings.count
            self.classificationSummary = classificationSummary
            self.provenance = provenance
            self.auditEventCount = auditEventCount
            self.auditEventsByOperation = auditEventsByOperation
            self.policyViolations = policyViolations
        }
    }

    public func generateSecurityReport() throws -> SecurityReport {
        let secretFindings = try SecretHistoryOps(repo: repo).secretHistory(limit: 100)
        var classificationSummary: [String: Int] = [:]
        for result in try DataClassificationOps(repo: repo).classifyRepository() {
            for category in result.categories {
                classificationSummary[category, default: 0] += 1
            }
        }
        var provenance: [ProvenanceEntry] = []
        let recent = try HistoryOps(repo: repo).log(limit: 20)
        for info in recent {
            let checks = (try? ProvenanceOps(repo: repo).verifyProvenance(rev: info.oid.hex)) ?? []
            provenance.append(ProvenanceEntry(commit: info.oid.hex, checks: checks))
        }
        let auditEvents = try AccessAuditOps(repo: repo).auditEvents(limit: 1000)
        var auditByOperation: [String: Int] = [:]
        for event in auditEvents {
            auditByOperation[event.operation, default: 0] += 1
        }
        var policyViolations: [PolicyEngineOps.PolicyViolation] = []
        let policyOps = PolicyEngineOps(repo: repo)
        for info in recent {
            let commit = try repo.commitObject(info.oid)
            var paths: [String] = []
            if let parent = commit.parents.first {
                let parentTree = try repo.commitObject(parent).tree
                paths = try DiffOps(repo: repo).diffTrees(parentTree, commit.tree).map { $0.newPath }
            } else {
                paths = try TreeBuilder.flattenTree(repo: repo, treeOID: commit.tree).keys.sorted()
            }
            let details = PolicyEngineOps.PolicyOperationDetails(
                message: commit.message, paths: paths,
                branch: try repo.refs.currentBranch(),
                signed: commit.metadata.signature != nil)
            policyViolations.append(contentsOf: try policyOps.checkPolicy(operation: .commit, details: details))
        }
        return SecurityReport(
            generatedAt: Int64(Date().timeIntervalSince1970),
            secretFindings: secretFindings,
            classificationSummary: classificationSummary,
            provenance: provenance,
            auditEventCount: auditEvents.count,
            auditEventsByOperation: auditByOperation,
            policyViolations: policyViolations)
    }
}
