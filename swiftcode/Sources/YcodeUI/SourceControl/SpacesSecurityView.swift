import Foundation
import SwiftUI
import SpacesEngine

@Observable
@MainActor
final class SpacesSecurityModel {
    let workspace: SpacesWorkspaceModel
    var error: String?
    var notice: String?
    var policy: PolicyEngineOps.RepositoryPolicy?
    var newRuleId = ""
    var newRuleKind = PolicyEngineOps.PolicyRuleKind.protectedBranches
    var newRuleValue = ""
    var checkOperation = PolicyEngineOps.PolicyOperation.commit
    var checkBranch = ""
    var checkMessage = ""
    var violations: [PolicyEngineOps.PolicyViolation] = []
    var secrets: [SecretHistoryOps.SecretFinding] = []
    var classificationRules: DataClassificationOps.ClassificationRuleSet?
    var classifyPath = ""
    var classifyResult: [String] = []
    var repositoryClassification: [DataClassificationOps.ClassificationResult] = []
    var provenanceRev = "HEAD"
    var provenanceChecks: [ProvenanceOps.ProvenanceCheck] = []
    var trustPolicy: ProvenanceOps.TrustPolicy?
    var trustSigners = ""
    var auditOperation = ""
    var auditDetails = ""
    var auditResult = "ok"
    var auditEvents: [AccessAuditOps.AuditEvent] = []
    var permissions: OperationPermissionOps.OperationPermissions?
    var currentRole: OperationPermissionOps.Role?
    var checkPermissionOperation = "push"
    var checkPermissionRole = OperationPermissionOps.Role.reviewer
    var checkPermissionResult: Bool?
    var signRev = "HEAD"
    var verifyRev = "HEAD"
    var signatureValid: Bool?
    var protectedRules: ProtectedHistoryOps.ProtectedHistoryRules?
    var newProtectedPattern = ""
    var protectedAllowForcePush = false
    var protectedAllowDelete = false
    var protectedRequireReview = true
    var protectedCheckRef = "refs/heads/main"
    var protectedCheckOperation = "push"
    var protectedCheckAllowed: Bool?
    var protectedCheckReasons: [String] = []
    var dependencyChanges: [DependencyAuditOps.DependencyChange] = []
    var securityReport: SecurityReportOps.SecurityReport?

    init(workspace: SpacesWorkspaceModel) {
        self.workspace = workspace
    }

    func refreshAll() {
        loadPolicy()
        loadSecrets()
        loadClassificationRules()
        loadTrustPolicy()
        loadAuditEvents()
        loadPermissions()
        loadProtectedRules()
        loadDependencyChanges()
    }

    private func load<T: Sendable>(_ what: String, _ body: @escaping @Sendable (SpacesAPI) throws -> T, assign: @escaping @MainActor @Sendable (T) -> Void) {
        guard let api = workspace.api else { return }
        Task.detached {
            do {
                let value = try body(api)
                await MainActor.run { assign(value) }
            } catch {
                await MainActor.run { self.error = "\(what): \(error.localizedDescription)" }
            }
        }
    }

    private func perform(_ what: String, _ body: @escaping @Sendable (SpacesAPI) throws -> Void) {
        guard let api = workspace.api else { return }
        Task.detached {
            do { try body(api) } catch {
                await MainActor.run { self.error = "\(what): \(error.localizedDescription)" }
            }
            await MainActor.run { self.refreshAll() }
        }
    }

    func loadPolicy() {
        load("repository policy", { try $0.repositoryPolicy() }, assign: { self.policy = $0 })
    }

    func loadSecrets() {
        load("secret history", { try $0.secretHistory(limit: 100) }, assign: { self.secrets = $0 })
    }

    func loadClassificationRules() {
        load("classification rules", { try $0.classificationRules() }, assign: { self.classificationRules = $0 })
    }

    func loadTrustPolicy() {
        load("trust policy", { try $0.trustPolicy() }, assign: { policy in
            self.trustPolicy = policy
            self.trustSigners = policy.trustedSigners.joined(separator: ", ")
        })
    }

    func loadAuditEvents() {
        load("audit events", { try $0.auditEvents(limit: 100) }, assign: { self.auditEvents = $0 })
    }

    func loadPermissions() {
        load("operation permissions", { try $0.operationPermissions() }, assign: { self.permissions = $0 })
        load("current role", { try $0.currentRole() }, assign: { self.currentRole = $0 })
    }

    func loadProtectedRules() {
        load("protected history rules", { try $0.protectedHistoryRules() }, assign: { self.protectedRules = $0 })
    }

    func loadDependencyChanges() {
        load("dependency change audit", { try $0.dependencyChangeAudit(limit: 100) }, assign: { self.dependencyChanges = $0 })
    }

    func addPolicyRule() {
        guard !newRuleId.isEmpty, !newRuleValue.isEmpty else {
            error = "policy rule: id and value are both required"
            return
        }
        var rules = policy?.rules ?? []
        rules.append(PolicyEngineOps.PolicyRule(id: newRuleId, kind: newRuleKind, value: newRuleValue, enabled: true))
        let updated = PolicyEngineOps.RepositoryPolicy(rules: rules)
        perform("save repository policy") { try $0.setRepositoryPolicy(updated) }
        newRuleId = ""
        newRuleValue = ""
    }

    func togglePolicyRule(_ rule: PolicyEngineOps.PolicyRule) {
        var rules = policy?.rules ?? []
        guard let index = rules.firstIndex(where: { $0.id == rule.id }) else { return }
        rules[index] = PolicyEngineOps.PolicyRule(id: rule.id, kind: rule.kind, value: rule.value, enabled: !rule.enabled)
        let updated = PolicyEngineOps.RepositoryPolicy(rules: rules)
        perform("save repository policy") { try $0.setRepositoryPolicy(updated) }
    }

    func runPolicyCheck() {
        let operation = checkOperation
        let details = PolicyEngineOps.PolicyOperationDetails(message: checkMessage.isEmpty ? nil : checkMessage, paths: [], branch: checkBranch.isEmpty ? nil : checkBranch, fileSizes: [:], signed: false)
        load("check policy", { try $0.checkPolicy(operation: operation, details: details) }, assign: { self.violations = $0 })
    }

    func runClassifyPath() {
        let path = classifyPath
        guard !path.isEmpty else {
            error = "classify path: enter a file path first"
            return
        }
        load("classify path", { try $0.classifyPath(path) }, assign: { self.classifyResult = $0 })
    }

    func runClassifyRepository() {
        load("classify repository", { try $0.classifyRepository() }, assign: { self.repositoryClassification = $0 })
    }

    func runVerifyProvenance() {
        let rev = provenanceRev
        load("verify provenance", { try $0.verifyProvenance(rev: rev) }, assign: { self.provenanceChecks = $0 })
    }

    func saveTrustPolicy() {
        let signers = trustSigners.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let policy = ProvenanceOps.TrustPolicy(trustedSigners: signers)
        perform("save trust policy") { try $0.setTrustPolicy(policy) }
    }

    func recordAuditEvent() {
        let operation = auditOperation
        let details = auditDetails
        let result = auditResult
        guard !operation.isEmpty else {
            error = "audit event: enter an operation first"
            return
        }
        perform("record audit event") { try $0.recordAuditEvent(operation: operation, details: details, result: result) }
        auditOperation = ""
        auditDetails = ""
    }

    func setRole(_ role: OperationPermissionOps.Role) {
        perform("set role") { try $0.setRole(role) }
    }

    func runCheckPermission() {
        let operation = checkPermissionOperation
        let role = checkPermissionRole
        load("check operation permission", { try $0.checkOperationPermission(operation: operation, role: role) }, assign: { self.checkPermissionResult = $0 })
    }

    func runSignSnapshot() {
        let rev = signRev
        guard let api = workspace.api else { return }
        Task.detached {
            do {
                let signature = try api.signSnapshot(rev)
                await MainActor.run { self.notice = "Snapshot \(rev) signed: \(signature)" }
            } catch {
                await MainActor.run { self.error = "sign snapshot: \(error.localizedDescription)" }
            }
        }
    }

    func runVerifySignature() {
        let rev = verifyRev
        load("verify snapshot signature", { try $0.verifySnapshotSignature(rev) }, assign: { self.signatureValid = $0 })
    }

    func addProtectedRule() {
        guard !newProtectedPattern.isEmpty else {
            error = "protected history rule: enter a ref pattern first"
            return
        }
        var refs = protectedRules?.refs ?? []
        refs.append(ProtectedHistoryOps.ProtectedRefRule(pattern: newProtectedPattern, allowForcePush: protectedAllowForcePush, allowDelete: protectedAllowDelete, requireReview: protectedRequireReview))
        let updated = ProtectedHistoryOps.ProtectedHistoryRules(refs: refs)
        perform("save protected history rules") { try $0.setProtectedHistoryRules(updated) }
        newProtectedPattern = ""
    }

    func runProtectedCheck() {
        let ref = protectedCheckRef
        let operation = protectedCheckOperation
        load("check protected history", { try $0.checkProtectedHistory(ref: ref, operation: operation) }, assign: { check in
            self.protectedCheckAllowed = check.allowed
            self.protectedCheckReasons = check.reasons
        })
    }

    func runSecurityReport() {
        load("security report", { try $0.generateSecurityReport() }, assign: { self.securityReport = $0 })
    }

    static func dateString(_ timestamp: Int64) -> String {
        Date(timeIntervalSince1970: TimeInterval(timestamp)).formatted(date: .abbreviated, time: .shortened)
    }
}

struct SpacesSecurityView: View {
    @State private var model: SpacesSecurityModel

    init(workspace: SpacesWorkspaceModel) {
        _model = State(initialValue: SpacesSecurityModel(workspace: workspace))
    }

    var body: some View {
        Form {
            if let error = model.error {
                Section {
                    HStack {
                        Text(error).foregroundStyle(.red)
                        Spacer()
                        Button("Dismiss") { model.error = nil }
                    }
                }
            }
            if let notice = model.notice {
                Section {
                    HStack {
                        Text(notice)
                        Spacer()
                        Button("Dismiss") { model.notice = nil }
                    }
                }
            }
            Section("Repository Policy") {
                if let policy = model.policy, !policy.rules.isEmpty {
                    ForEach(Array(policy.rules.enumerated()), id: \.offset) { _, rule in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(rule.id).font(.subheadline)
                                Text("\(rule.kind.rawValue) = \(rule.value)").font(.caption.monospaced()).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(rule.enabled ? "enabled" : "disabled").font(.caption).foregroundStyle(.secondary)
                            Button(rule.enabled ? "Disable" : "Enable") { model.togglePolicyRule(rule) }
                                .controlSize(.small)
                        }
                    }
                } else {
                    Text("No policy rules configured.").font(.caption).foregroundStyle(.secondary)
                }
                TextField("Rule id", text: $model.newRuleId)
                HStack {
                    Picker("Kind", selection: $model.newRuleKind) {
                        ForEach([PolicyEngineOps.PolicyRuleKind.protectedBranches, .maxFileSizeBytes, .requireSignedCommits, .forbiddenPaths, .requireMessagePattern], id: \.self) { kind in
                            Text(kind.rawValue).tag(kind)
                        }
                    }
                    .pickerStyle(.menu)
                    TextField("Value", text: $model.newRuleValue)
                    Button("Add Rule") { model.addPolicyRule() }
                        .disabled(model.newRuleId.isEmpty)
                }
                HStack {
                    Picker("Operation", selection: $model.checkOperation) {
                        ForEach([PolicyEngineOps.PolicyOperation.commit, .branchCreate, .branchDelete, .push, .tag], id: \.self) { operation in
                            Text(operation.rawValue).tag(operation)
                        }
                    }
                    .pickerStyle(.menu)
                    TextField("Branch", text: $model.checkBranch)
                    TextField("Message", text: $model.checkMessage)
                    Button("Check Policy") { model.runPolicyCheck() }
                }
                ForEach(Array(model.violations.enumerated()), id: \.offset) { _, violation in
                    Text("\(violation.ruleID): \(violation.message)").font(.caption).foregroundStyle(.orange)
                }
            }
            Section("Secret History") {
                Button("Refresh Secret History") { model.loadSecrets() }
                if model.secrets.isEmpty {
                    Text("No secrets found across history.").font(.caption).foregroundStyle(.secondary)
                }
                ForEach(Array(model.secrets.enumerated()), id: \.offset) { _, finding in
                    HStack {
                        Text(finding.patternName).font(.subheadline)
                        Spacer()
                        Text("\(finding.path) @ \(finding.commit)").font(.caption.monospaced()).foregroundStyle(.secondary)
                    }
                }
            }
            Section("Data Classification") {
                if let rules = model.classificationRules {
                    ForEach(Array(rules.categories.enumerated()), id: \.offset) { _, category in
                        Text("\(category.name): \(category.pathPatterns.joined(separator: ", "))").font(.callout.monospaced())
                    }
                }
                HStack {
                    TextField("Path to classify", text: $model.classifyPath)
                    Button("Classify Path") { model.runClassifyPath() }
                        .disabled(model.classifyPath.isEmpty)
                    Button("Classify Repository") { model.runClassifyRepository() }
                }
                if !model.classifyResult.isEmpty {
                    Text("Categories: \(model.classifyResult.joined(separator: ", "))").font(.caption)
                }
                ForEach(Array(model.repositoryClassification.enumerated()), id: \.offset) { _, result in
                    Text("\(result.path): \(result.categories.joined(separator: ", "))").font(.caption.monospaced())
                }
            }
            Section("Provenance and Trust") {
                HStack {
                    TextField("Revision", text: $model.provenanceRev)
                    Button("Verify Provenance") { model.runVerifyProvenance() }
                        .disabled(model.provenanceRev.isEmpty)
                }
                ForEach(Array(model.provenanceChecks.enumerated()), id: \.offset) { _, check in
                    HStack {
                        Text(check.name).font(.subheadline)
                        Spacer()
                        Text(check.passed ? "passed" : "failed").foregroundStyle(check.passed ? .green : .red).font(.caption)
                        Text(check.detail).font(.caption).foregroundStyle(.secondary)
                    }
                }
                HStack {
                    TextField("Trusted signers (comma separated)", text: $model.trustSigners)
                    Button("Save Trust Policy") { model.saveTrustPolicy() }
                }
            }
            Section("Access Audit") {
                HStack {
                    TextField("Operation", text: $model.auditOperation)
                    TextField("Details", text: $model.auditDetails)
                    TextField("Result", text: $model.auditResult)
                    Button("Record Event") { model.recordAuditEvent() }
                        .disabled(model.auditOperation.isEmpty)
                }
                Button("Refresh Audit Events") { model.loadAuditEvents() }
                ForEach(Array(model.auditEvents.enumerated()), id: \.offset) { _, event in
                    HStack {
                        VStack(alignment: .leading) {
                            Text("\(event.operation) — \(event.result)").font(.subheadline)
                            Text("\(event.actor): \(event.details)").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(SpacesSecurityModel.dateString(event.timestamp)).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Section("Operation Permissions and Role") {
                HStack {
                    Text("Current role: \(model.currentRole?.rawValue ?? "unknown")")
                    Spacer()
                    Picker("Set role", selection: Binding(get: { model.currentRole ?? .reader }, set: { model.setRole($0) })) {
                        ForEach(OperationPermissionOps.Role.allCases, id: \.self) { role in
                            Text(role.rawValue).tag(role)
                        }
                    }
                    .pickerStyle(.menu)
                }
                if let permissions = model.permissions {
                    ForEach(Array(permissions.operations.keys.sorted().enumerated()), id: \.offset) { _, operation in
                        Text("\(operation): \((permissions.operations[operation] ?? []).map { $0.rawValue }.joined(separator: ", "))")
                            .font(.caption.monospaced())
                    }
                }
                HStack {
                    TextField("Operation", text: $model.checkPermissionOperation)
                    Picker("Role", selection: $model.checkPermissionRole) {
                        ForEach(OperationPermissionOps.Role.allCases, id: \.self) { role in
                            Text(role.rawValue).tag(role)
                        }
                    }
                    .pickerStyle(.menu)
                    Button("Check Permission") { model.runCheckPermission() }
                    if let allowed = model.checkPermissionResult {
                        Text(allowed ? "allowed" : "denied").foregroundStyle(allowed ? .green : .red)
                    }
                }
            }
            Section("Signed Snapshots") {
                HStack {
                    TextField("Revision to sign", text: $model.signRev)
                    Button("Sign Snapshot") { model.runSignSnapshot() }
                        .disabled(model.signRev.isEmpty)
                }
                HStack {
                    TextField("Revision to verify", text: $model.verifyRev)
                    Button("Verify Signature") { model.runVerifySignature() }
                        .disabled(model.verifyRev.isEmpty)
                    if let valid = model.signatureValid {
                        Text(valid ? "signature valid" : "signature invalid").foregroundStyle(valid ? .green : .red)
                    }
                }
            }
            Section("Protected History") {
                if let rules = model.protectedRules {
                    ForEach(Array(rules.refs.enumerated()), id: \.offset) { _, rule in
                        Text("\(rule.pattern) — force-push: \(rule.allowForcePush ? "allowed" : "blocked"), delete: \(rule.allowDelete ? "allowed" : "blocked"), review: \(rule.requireReview ? "required" : "not required")")
                            .font(.caption.monospaced())
                    }
                }
                TextField("Ref pattern", text: $model.newProtectedPattern)
                HStack {
                    Toggle("Allow force-push", isOn: $model.protectedAllowForcePush).controlSize(.small)
                    Toggle("Allow delete", isOn: $model.protectedAllowDelete).controlSize(.small)
                    Toggle("Require review", isOn: $model.protectedRequireReview).controlSize(.small)
                    Button("Add Protected Ref") { model.addProtectedRule() }
                        .disabled(model.newProtectedPattern.isEmpty)
                }
                HStack {
                    TextField("Ref", text: $model.protectedCheckRef)
                    TextField("Operation", text: $model.protectedCheckOperation)
                    Button("Check") { model.runProtectedCheck() }
                    if let allowed = model.protectedCheckAllowed {
                        Text(allowed ? "allowed" : "blocked").foregroundStyle(allowed ? .green : .red)
                    }
                }
                ForEach(Array(model.protectedCheckReasons.enumerated()), id: \.offset) { _, reason in
                    Text(reason).font(.caption).foregroundStyle(.secondary)
                }
            }
            Section("Dependency Change Audit") {
                Button("Refresh Dependency Audit") { model.loadDependencyChanges() }
                ForEach(Array(model.dependencyChanges.enumerated()), id: \.offset) { _, change in
                    VStack(alignment: .leading) {
                        Text(change.summary).font(.subheadline)
                        Text("Commit \(change.commit) • manifests: \(change.manifests.joined(separator: ", ")) • lockfiles: \(change.lockfiles.joined(separator: ", "))")
                            .font(.caption).foregroundStyle(.secondary)
                        if change.manifestsChangedWithLockfile {
                            Text("Manifest changed without a lockfile update").font(.caption).foregroundStyle(.orange)
                        }
                    }
                }
            }
            Section("Security Report") {
                Button("Generate Security Report") { model.runSecurityReport() }
                if let report = model.securityReport {
                    Text("Generated \(SpacesSecurityModel.dateString(report.generatedAt))").font(.caption)
                    Text("\(report.secretFindingCount) secret findings • \(report.auditEventCount) audit events").font(.subheadline)
                    ForEach(Array(report.classificationSummary.keys.sorted().enumerated()), id: \.offset) { _, key in
                        Text("\(key): \(report.classificationSummary[key] ?? 0) files").font(.caption)
                    }
                    ForEach(Array(report.provenance.enumerated()), id: \.offset) { _, entry in
                        Text("\(entry.commit): \(entry.allPassed ? "all provenance checks passed" : "provenance checks failed")")
                            .font(.caption)
                    }
                    ForEach(Array(report.policyViolations.enumerated()), id: \.offset) { _, violation in
                        Text("\(violation.ruleID): \(violation.message)").font(.caption).foregroundStyle(.orange)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { model.refreshAll() }
    }
}
