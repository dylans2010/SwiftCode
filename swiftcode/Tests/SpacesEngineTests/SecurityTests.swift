import Foundation
import Testing
@testable import SpacesEngine

@Suite struct SecurityTests {
    @Test func policyRejectsForbiddenPathAndProtectedBranch() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        let policy = PolicyEngineOps.RepositoryPolicy(rules: [
            PolicyEngineOps.PolicyRule(id: "no-keys", kind: .forbiddenPaths, value: "*.pem"),
            PolicyEngineOps.PolicyRule(id: "protect-main", kind: .protectedBranches, value: "main"),
            PolicyEngineOps.PolicyRule(id: "msg", kind: .requireMessagePattern, value: "^[A-Z]+-[0-9]+ "),
        ])
        try api.setRepositoryPolicy(policy)
        #expect(try api.repositoryPolicy().rules.count == 3)
        let pathViolations = try api.checkPolicy(operation: .commit, details: PolicyEngineOps.PolicyOperationDetails(
            message: "ABC-1 add key", paths: ["keys/id.pem"]))
        #expect(pathViolations.contains { $0.ruleID == "no-keys" })
        let branchCheck = try api.checkProtectedHistory(ref: "main", operation: "force-push")
        #expect(!branchCheck.allowed)
        let deleteCheck = try api.checkPolicy(operation: .branchDelete, details: PolicyEngineOps.PolicyOperationDetails(branch: "main"))
        #expect(deleteCheck.contains { $0.ruleID == "protect-main" })
        let messageViolations = try api.checkPolicy(operation: .commit, details: PolicyEngineOps.PolicyOperationDetails(
            message: "lowercase message", paths: ["ok.txt"]))
        #expect(messageViolations.contains { $0.ruleID == "msg" })
        let clean = try api.checkPolicy(operation: .commit, details: PolicyEngineOps.PolicyOperationDetails(
            message: "ABC-1 clean change", paths: ["ok.txt"]))
        #expect(clean.isEmpty)
    }

    @Test func secretHistoryFindsPlantedKey() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["notes.txt": "key is AKIA1111111111111111 do not share"],
                                              message: "leak")
        let findings = try api.secretHistory(limit: 10)
        #expect(findings.contains { $0.path == "notes.txt" && $0.patternName == "aws-access-key" })
        #expect(findings.allSatisfy { !$0.commit.isEmpty })
    }

    @Test func classificationDetectsSensitiveFiles() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        let rules = DataClassificationOps.ClassificationRuleSet(categories: [
            DataClassificationOps.ClassificationCategory(
                name: "credentials", pathPatterns: ["*.pem"],
                contentPatterns: [#"(?i)password\s*[:=]"#]),
            DataClassificationOps.ClassificationCategory(
                name: "secrets-content", pathPatterns: [],
                contentPatterns: ["AKIA[0-9A-Z]{16}"]),
        ])
        try api.setClassificationRules(rules)
        _ = try SpacesTestSupport.commitFiles(api, [
            "keys/id.pem": "-----BEGIN PRIVATE KEY-----\nabc\n",
            "app.txt": "password: hunter2\n",
            "plain.txt": "hello world\n",
        ], message: "add files")
        let direct = try DataClassificationOps(repo: api.repo).classify(
            path: "keys/id.pem", content: "nothing sensitive")
        #expect(direct == ["credentials"])
        let repoResults = try api.classifyRepository()
        #expect(repoResults.contains { $0.path == "keys/id.pem" && $0.categories.contains("credentials") })
        #expect(repoResults.contains { $0.path == "app.txt" && $0.categories.contains("credentials") })
        #expect(!repoResults.contains { $0.path == "plain.txt" })
        #expect(try api.classifyPath("plain.txt").isEmpty)
    }

    @Test func unsignedCommitFailsProvenanceWhenSigningRequired() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        let policy = PolicyEngineOps.RepositoryPolicy(rules: [
            PolicyEngineOps.PolicyRule(id: "sign", kind: .requireSignedCommits, value: "true"),
        ])
        try api.setRepositoryPolicy(policy)
        try api.setTrustPolicy(ProvenanceOps.TrustPolicy(trustedSigners: ["test@example.com"]))
        let oid = try SpacesTestSupport.commitFiles(api, ["f.txt": "1"], message: "c1")
        let checks = try api.verifyProvenance(rev: oid.hex)
        #expect(checks.contains { $0.name == "commit-exists" && $0.passed })
        #expect(checks.contains { $0.name == "ancestry-intact" && $0.passed })
        #expect(checks.contains { $0.name == "signature" && !$0.passed })
        #expect(checks.contains { $0.name == "author-trusted" && $0.passed })
        let violations = try api.checkPolicy(operation: .commit, details: PolicyEngineOps.PolicyOperationDetails(
            message: "c1", paths: ["f.txt"], signed: false))
        #expect(violations.contains { $0.ruleID == "sign" })
    }

    @Test func accessAuditPersistsEvents() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        try api.recordAuditEvent(operation: "push", details: "refs/heads/main", result: "allowed")
        try api.recordAuditEvent(operation: "commit", details: "c1", result: "denied")
        let events = try api.auditEvents(limit: 10)
        #expect(events.count == 2)
        #expect(events[0].operation == "commit")
        #expect(events[0].actor.contains("test@example.com"))
        #expect(events[1].operation == "push")
    }

    @Test func operationPermissionsEnforceRoles() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        #expect(try api.currentRole() == .developer)
        #expect(try api.checkOperationPermission(operation: "commit", role: .developer))
        #expect(try !api.checkOperationPermission(operation: "branch-delete", role: .developer))
        #expect(try api.checkOperationPermission(operation: "branch-delete", role: .admin))
        #expect(try !api.checkOperationPermission(operation: "branch-delete", role: .reader))
        try api.setRole(.reviewer)
        #expect(try api.currentRole() == .reviewer)
        try api.setOperationPermissions(OperationPermissionOps.OperationPermissions(operations: [
            "commit": [.admin],
        ]))
        #expect(try !api.checkOperationPermission(operation: "commit", role: .developer))
        #expect(try api.checkOperationPermission(operation: "commit", role: .admin))
    }

    @Test func signedSnapshotVerifies() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f.txt": "1"], message: "base")
        let snap = try api.snapshot(message: "checkpoint")
        #expect(try !api.verifySnapshotSignature(snap.hex))
        let signature = try api.signSnapshot(snap.hex)
        #expect(!signature.isEmpty)
        #expect(try api.verifySnapshotSignature(snap.hex))
        let other = try api.snapshot(message: "second")
        #expect(try !api.verifySnapshotSignature(other.hex))
    }

    @Test func protectedHistoryRulesGateOperations() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        let rules = ProtectedHistoryOps.ProtectedHistoryRules(refs: [
            ProtectedHistoryOps.ProtectedRefRule(pattern: "main", allowForcePush: false, allowDelete: false, requireReview: true),
        ])
        try api.setProtectedHistoryRules(rules)
        #expect(try api.protectedHistoryRules().refs.count == 1)
        let force = try api.checkProtectedHistory(ref: "main", operation: "force-push")
        #expect(!force.allowed)
        #expect(!force.reasons.isEmpty)
        let delete = try api.checkProtectedHistory(ref: "refs/heads/main", operation: "delete")
        #expect(!delete.allowed)
        let rewrite = try api.checkProtectedHistory(ref: "main", operation: "rewrite")
        #expect(!rewrite.allowed)
        let free = try api.checkProtectedHistory(ref: "feature", operation: "force-push")
        #expect(free.allowed)
    }

    @Test func dependencyChangeAuditTracksLockfiles() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, [
            "Package.swift": "let package = 1\n",
            "Package.resolved": "{}\n",
        ], message: "deps together")
        _ = try SpacesTestSupport.commitFiles(api, [
            "Package.swift": "let package = 2\n",
        ], message: "manifest alone")
        _ = try SpacesTestSupport.commitFiles(api, ["README.md": "docs\n"], message: "unrelated")
        let audit = try api.dependencyChangeAudit(limit: 10)
        #expect(audit.count == 2)
        #expect(audit.contains { $0.manifestsChangedWithLockfile && $0.manifests.contains("Package.swift") && $0.lockfiles.contains("Package.resolved") })
        #expect(audit.contains { !$0.manifestsChangedWithLockfile && $0.summary == "manifest alone" })
    }

    @Test func securityReportAggregatesRealEvidence() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["notes.txt": "AKIA2222222222222222"], message: "leak")
        try api.setClassificationRules(DataClassificationOps.ClassificationRuleSet(categories: [
            DataClassificationOps.ClassificationCategory(name: "leaked", pathPatterns: [], contentPatterns: ["AKIA[0-9A-Z]{16}"]),
        ]))
        try api.recordAuditEvent(operation: "commit", details: "leak", result: "allowed")
        let report = try api.generateSecurityReport()
        #expect(report.secretFindingCount >= 1)
        #expect(report.classificationSummary["leaked"] == 1)
        #expect(report.auditEventCount == 1)
        #expect(report.auditEventsByOperation["commit"] == 1)
        #expect(report.provenance.count == 1)
        #expect(report.provenance[0].checks.contains { $0.name == "commit-exists" && $0.passed })
    }
}
