import Crypto
import Foundation



public final class SpacesAPI: @unchecked Sendable {
    public let repo: Repository

    public init(repo: Repository) {
        self.repo = repo
    }

    public static func open(at path: String? = nil) throws -> SpacesAPI {
        let url = path.map { URL(fileURLWithPath: $0) }
        return SpacesAPI(repo: try Repository.open(at: url))
    }

    

    public func info() throws -> RepoInfo {
        let status = try WorktreeScanner(repo: repo).status()
        let storage = try MaintenanceOps(repo: repo).storage()
        let counts = try MaintenanceOps(repo: repo).countObjects()
        return RepoInfo(
            path: repo.worktreeURL.path,
            formatVersion: repo.config.version,
            branch: status.branch,
            headOID: status.headOID?.hex,
            isMerge: status.inMerge,
            isRebase: status.inRebase,
            objectCount: counts.total,
            storageBytes: storage.total,
            defaultBranch: repo.config.core.defaultBranch)
    }

    public struct RepoInfo: Sendable, Codable {
        public var path: String
        public var formatVersion: Int
        public var branch: String?
        public var headOID: String?
        public var isMerge: Bool
        public var isRebase: Bool
        public var objectCount: Int
        public var storageBytes: Int64
        public var defaultBranch: String
    }

    public func validate() -> [String] { repo.validate() }
    public func diagnose() throws -> [MaintenanceOps.Diagnostic] {
        try MaintenanceOps(repo: repo).diagnose()
    }
    public func health() throws -> (score: Int, issues: [MaintenanceOps.Diagnostic]) {
        try MaintenanceOps(repo: repo).healthScore()
    }

    

    public func status() throws -> WorktreeScanner.StatusReport {
        _ = try? ContinuousSnapshotOps(repo: repo).captureIfDue()
        return try WorktreeScanner(repo: repo).status()
    }

    public func add(_ path: String, all: Bool = false) throws -> [String] {
        try repo.performTransaction { try StagingOps(repo: repo).add(path, all: all) }
    }

    public func stageAll() throws -> [String] {
        try add(".", all: true)
    }

    public func remove(_ path: String) throws {
        try repo.performTransaction { try StagingOps(repo: repo).remove(path) }
    }

    public func move(_ old: String, _ new: String) throws {
        try repo.performTransaction { try StagingOps(repo: repo).move(old, new) }
    }

    public func unstage(_ path: String) throws {
        try repo.performTransaction { try StagingOps(repo: repo).unstage(path) }
    }

    public func restore(_ path: String, staged: Bool = false) throws {
        if !staged {
            _ = try RecoveryCheckpointOps(repo: repo).createCheckpointBefore(operation: "restore \(path)")
        }
        try repo.performTransaction {
            if staged { try StagingOps(repo: repo).unstage(path) }
            else { try StagingOps(repo: repo).restoreWorktree(path) }
        }
    }

    public func clean(dryRun: Bool = false) throws -> [String] {
        try StagingOps(repo: repo).clean(dryRun: dryRun)
    }

    

    @discardableResult
    public func commit(message: String, amend: Bool = false,
                       trailers: [String: String] = [:]) throws -> StagingOps.CommitResult {
        try enforceOperationPermission("commit")
        try enforceRepositoryPolicy(operation: .commit, details: PolicyEngineOps.PolicyOperationDetails(
            message: message, paths: (try? status().staged.map { $0.path }) ?? []))
        try validateCommitPolicies(message: message)
        let result = try StagingOps(repo: repo).commit(message: message, amend: amend, trailers: trailers)
        try? AccessAuditOps(repo: repo).recordAuditEvent(operation: "commit", details: message, result: "success")
        _ = try? AutomationOps(repo: repo).runAutomation(event: .postCommit)
        return result
    }

    public func log(limit: Int = 100, all: Bool = false,
                    firstParentOnly: Bool = false) throws -> [HistoryOps.CommitInfo] {
        try HistoryOps(repo: repo).log(firstParentOnly: firstParentOnly, limit: limit, all: all)
    }

    public func show(_ rev: String = "HEAD") throws -> HistoryOps.ShowResult {
        try HistoryOps(repo: repo).show(rev)
    }

    public func describe() throws -> String { try HistoryOps(repo: repo).describe() }

    public func blame(_ path: String, rev: String = "HEAD") throws -> [HistoryOps.BlameLine] {
        try HistoryOps(repo: repo).blame(path, rev: rev)
    }

    public func reflog(refName: String = "HEAD", limit: Int = 50) throws -> [ReflogEntry] {
        try repo.readReflog(refName: refName, limit: limit)
    }

    

    public func branches() throws -> [BranchOps.BranchInfo] {
        try BranchOps(repo: repo).list()
    }

    @discardableResult
    public func createBranch(_ name: String, at: String = "HEAD") throws -> ObjectID {
        try repo.performTransaction { try BranchOps(repo: repo).create(name, at: at) }
    }

    public func deleteBranch(_ name: String, force: Bool = false) throws {
        try enforceOperationPermission("branch-delete")
        let check = try ProtectedHistoryOps(repo: repo).checkProtectedHistory(ref: "refs/heads/" + name, operation: "delete")
        if !check.allowed {
            try? AccessAuditOps(repo: repo).recordAuditEvent(operation: "branch-delete", details: name, result: "denied: \(check.reasons.joined(separator: "; "))")
            throw SpacesError.invalidArgument(check.reasons.joined(separator: "; "))
        }
        try repo.performTransaction { try BranchOps(repo: repo).delete(name, force: force) }
        try? AccessAuditOps(repo: repo).recordAuditEvent(operation: "branch-delete", details: name, result: "success")
    }

    public func renameBranch(_ old: String, to new: String) throws {
        try repo.performTransaction { try BranchOps(repo: repo).rename(old, to: new) }
    }

    public func switchTo(_ target: String, create: Bool = false, force: Bool = false) throws {
        try BranchOps(repo: repo).switchTo(target, force: force, create: create)
    }

    public func reset(to rev: String, mode: BranchOps.ResetMode) throws {
        try enforceOperationPermission("reset")
        if mode == .hard {
            _ = try RecoveryCheckpointOps(repo: repo).createCheckpointBefore(operation: "reset --hard \(rev)")
        }
        try BranchOps(repo: repo).reset(to: rev, mode: mode)
        try? AccessAuditOps(repo: repo).recordAuditEvent(operation: "reset", details: rev, result: "success")
    }

    

    @discardableResult
    public func merge(_ target: String) throws -> MergeEngine.MergeOutcome {
        try enforceOperationPermission("merge")
        try enforceReviewMergePolicy(target: target)
        try enforceRepositoryPolicy(operation: .merge, details: PolicyEngineOps.PolicyOperationDetails(
            branch: try repo.refs.currentBranch()))
        _ = try RecoveryCheckpointOps(repo: repo).createCheckpointBefore(operation: "merge \(target)")
        let outcome = try MergeEngine(repo: repo).merge(target)
        let result = outcome.commitOID == nil && !outcome.conflicts.isEmpty ? "conflicted" : "success"
        try? AccessAuditOps(repo: repo).recordAuditEvent(operation: "merge", details: target, result: result)
        let completed: Bool
        switch outcome.result {
        case .upToDate, .fastForward: completed = true
        case .merged: completed = outcome.commitOID != nil
        }
        if completed {
            _ = try? AutomationOps(repo: repo).runAutomation(event: .postMerge)
        }
        return outcome
    }

    public func mergeContinue() throws -> ObjectID {
        try MergeEngine(repo: repo).mergeContinue()
    }

    public func mergeAbort() throws {
        try MergeEngine(repo: repo).mergeAbort()
    }

    public func mergeStrategies() -> [MergeEngine.MergeStrategyInfo] {
        MergeEngine(repo: repo).supportedMergeStrategies()
    }

    public func mergeStrategy(named name: String) throws -> MergeEngine.MergeStrategyInfo {
        try MergeEngine(repo: repo).strategy(named: name)
    }

    public func defaultMergeStrategy() -> MergeEngine.MergeStrategyInfo {
        MergeEngine(repo: repo).defaultMergeStrategy()
    }

    @discardableResult
    public func cherryPick(_ rev: String) throws -> ObjectID? {
        _ = try RecoveryCheckpointOps(repo: repo).createCheckpointBefore(operation: "cherry-pick \(rev)")
        return try MergeEngine(repo: repo).cherryPick(rev)
    }

    @discardableResult
    public func revert(_ rev: String) throws -> ObjectID? {
        _ = try RecoveryCheckpointOps(repo: repo).createCheckpointBefore(operation: "revert \(rev)")
        return try MergeEngine(repo: repo).cherryPick(rev, revert: true)
    }

    public func cherryPickContinue() throws -> ObjectID? {
        try MergeEngine(repo: repo).cherryPickContinue()
    }

    public func cherryPickAbort() throws {
        try MergeEngine(repo: repo).cherryPickAbort()
    }

    @discardableResult
    public func rebase(onto: String, todo: [String]? = nil) throws -> RebaseOps.RebaseState? {
        _ = try RecoveryCheckpointOps(repo: repo).createCheckpointBefore(operation: "rebase onto \(onto)")
        let state = try RebaseOps(repo: repo).start(onto: onto, todo: todo)
        try? AccessAuditOps(repo: repo).recordAuditEvent(operation: "rebase", details: onto, result: "success")
        return state
    }

    public func rebaseContinue() throws -> RebaseOps.RebaseState? {
        try RebaseOps(repo: repo).continueRebase()
    }

    public func rebaseSkip() throws -> RebaseOps.RebaseState? {
        try RebaseOps(repo: repo).skip()
    }

    public func rebaseAbort() throws {
        try RebaseOps(repo: repo).abort()
    }

    public func graph(limit: Int = 200) throws -> [BranchOps.GraphNode] {
        try BranchOps(repo: repo).graph(limit: limit)
    }

    public func mergeBase(_ a: String, _ b: String) throws -> ObjectID? {
        try HistoryOps(repo: repo).mergeBase(
            repo.resolveRevision(a), repo.resolveRevision(b))
    }

    

    public func tags() throws -> [TagOps.TagInfo] { try TagOps(repo: repo).list() }

    @discardableResult
    public func createTag(_ name: String, at: String = "HEAD",
                          annotated: Bool = false, message: String = "") throws -> ObjectID {
        let oid = try repo.performTransaction {
            try TagOps(repo: repo).create(name, at: at, annotated: annotated, message: message)
        }
        try? AccessAuditOps(repo: repo).recordAuditEvent(operation: "tag", details: name, result: "success")
        return oid
    }

    public func deleteTag(_ name: String) throws {
        try repo.performTransaction { try TagOps(repo: repo).delete(name) }
        try? AccessAuditOps(repo: repo).recordAuditEvent(operation: "tag-delete", details: name, result: "success")
    }

    public func verifyTag(_ name: String) throws -> Bool {
        try TagOps(repo: repo).verify(name)
    }

    

    public func stashes() throws -> [StashOps.StashEntry] {
        try StashOps(repo: repo).list()
    }

    @discardableResult
    public func stash(message: String? = nil) throws -> StashOps.StashEntry? {
        let entry = try StashOps(repo: repo).create(message: message)
        try? AccessAuditOps(repo: repo).recordAuditEvent(operation: "stash", details: message ?? "", result: "success")
        return entry
    }

    public func stashApply(_ id: String, pop: Bool = false) throws {
        if pop {
            _ = try RecoveryCheckpointOps(repo: repo).createCheckpointBefore(operation: "stash pop \(id)")
        }
        try StashOps(repo: repo).apply(id, drop: pop)
        try? AccessAuditOps(repo: repo).recordAuditEvent(operation: pop ? "stash-pop" : "stash-apply", details: id, result: "success")
    }

    public func stashDrop(_ id: String) throws {
        try StashOps(repo: repo).drop(id)
        try? AccessAuditOps(repo: repo).recordAuditEvent(operation: "stash-drop", details: id, result: "success")
    }

    

    @discardableResult
    public func snapshot(message: String, kind: SnapshotOps.Kind = .manual) throws -> ObjectID {
        try SnapshotOps(repo: repo).create(message: message, kind: kind)
    }

    public func snapshots() throws -> [SnapshotOps.SnapshotInfo] {
        try SnapshotOps(repo: repo).list()
    }

    public func timeline(limit: Int = 100) throws -> [SnapshotOps.TimelineEntry] {
        try SnapshotOps(repo: repo).timeline(limit: limit)
    }

    public func restoreSnapshot(_ rev: String) throws {
        try SnapshotOps(repo: repo).restore(rev)
    }

    

    public func remotes() -> [RemoteOps.RemoteInfo] {
        RemoteOps(repo: repo).list()
    }

    public func addRemote(_ name: String, url: String) throws {
        try RemoteOps(repo: repo).add(name, url: url)
    }

    public func removeRemote(_ name: String) throws {
        try RemoteOps(repo: repo).remove(name)
    }

    public func fetch(_ remote: String) throws -> RemoteOps.FetchReport {
        let report = try RemoteOps(repo: repo).fetch(remote)
        try? AccessAuditOps(repo: repo).recordAuditEvent(operation: "fetch", details: remote, result: "success")
        return report
    }

    public func pull(_ remote: String, branch: String? = nil) throws -> MergeEngine.MergeOutcome? {
        let outcome = try RemoteOps(repo: repo).pull(remote, branch: branch)
        try? AccessAuditOps(repo: repo).recordAuditEvent(operation: "pull", details: remote, result: "success")
        return outcome
    }

    public func push(_ remote: String, refspec: String) throws -> RemoteOps.PushReport {
        try enforceOperationPermission("push")
        try enforceRepositoryPolicy(operation: .push, details: PolicyEngineOps.PolicyOperationDetails(
            branch: Self.branchName(fromRefspec: refspec)))
        let report = try RemoteOps(repo: repo).push(remote, refspec: refspec)
        try? AccessAuditOps(repo: repo).recordAuditEvent(operation: "push", details: "\(remote) \(refspec)", result: "success")
        _ = try? AutomationOps(repo: repo).runAutomation(event: .postPush)
        return report
    }

    public func push(_ remote: String, refspec: String, force: Bool) throws -> RemoteOps.PushReport {
        try enforceOperationPermission("push")
        try enforceRepositoryPolicy(operation: .push, details: PolicyEngineOps.PolicyOperationDetails(
            branch: Self.branchName(fromRefspec: refspec)))
        let report = try RemoteOps(repo: repo).push(remote, refspec: refspec, force: force)
        try? AccessAuditOps(repo: repo).recordAuditEvent(operation: "push", details: "\(remote) \(refspec)", result: "success")
        _ = try? AutomationOps(repo: repo).runAutomation(event: .postPush)
        return report
    }

    @discardableResult
    public func cloneRepository(url: String, into dest: URL? = nil) throws -> SpacesAPI {
        let cloned = try CloneOps.clone(url: url, into: dest, repo: repo)
        let api = SpacesAPI(repo: cloned)
        try? AccessAuditOps(repo: cloned).recordAuditEvent(operation: "clone", details: url, result: "success")
        return api
    }

    

    public func diff(stagedOnly: Bool = false) throws -> [DiffOps.FileDiff] {
        try DiffOps(repo: repo).workingDiff(stagedOnly: stagedOnly)
    }

    public func diff(_ from: String, _ to: String = "HEAD") throws -> [DiffOps.FileDiff] {
        try DiffOps(repo: repo).commitDiff(from, to)
    }

    

    public func search(_ query: SearchOps.Query) throws -> [SearchOps.Result] {
        try SearchOps(repo: repo).search(query)
    }

    

    public func fsck() throws -> [MaintenanceOps.FSCKIssue] {
        try MaintenanceOps(repo: repo).fsck()
    }

    @discardableResult
    public func gc() throws -> (pruned: Int, reachable: Int) {
        try MaintenanceOps(repo: repo).gc()
    }

    public func countObjects() throws -> (blobs: Int, trees: Int, commits: Int,
                                          tags: Int, snapshots: Int, total: Int) {
        try MaintenanceOps(repo: repo).countObjects()
    }

    public func storage() throws -> (objects: Int64, index: Int64, total: Int64, fileCount: Int) {
        let result = try MaintenanceOps(repo: repo).storage()
        _ = try? PredictiveStorageOps(repo: repo).recordStorageSample()
        return result
    }

    @discardableResult
    public func repair() throws -> [String] {
        try MaintenanceOps(repo: repo).repair()
    }

    @discardableResult
    public func rebuildIndex() throws -> Int {
        try MaintenanceOps(repo: repo).rebuildIndex()
    }

    

    @discardableResult
    public func importGit(at path: String) throws -> GitMigration.ImportReport {
        try GitMigration(repo: repo).importGit(at: path)
    }

    @discardableResult
    public func exportGit(to path: String) throws -> GitMigration.ExportReport {
        try GitMigration(repo: repo).exportGit(to: path)
    }

    

    public func worktrees() throws -> [WorktreeOps.WorktreeInfo] {
        try WorktreeOps(repo: repo).list()
    }

    public func addWorktree(path: String, branch: String? = nil, newBranch: String? = nil) throws -> WorktreeOps.WorktreeInfo {
        try WorktreeOps(repo: repo).add(path: path, branch: branch, newBranch: newBranch)
    }

    public func removeWorktree(_ name: String) throws {
        try WorktreeOps(repo: repo).remove(name)
    }

    public func resolveWorktree(_ target: String) throws -> WorktreeOps.ResolvedWorktree {
        try WorktreeOps(repo: repo).resolve(target)
    }

    

    
    
    
    public func events() -> AsyncStream<SpacesEvent> {
        SpacesEventHub.shared.subscribe(worktree: repo.worktreeURL)
    }
}

extension SpacesAPI {
    public struct CommitComparison: Sendable {
        public var from: ObjectID
        public var to: ObjectID
        public var diffs: [DiffOps.FileDiff]
        public var metadataDifferences: [String]
    }

    public struct ExpiredBranch: Sendable {
        public var branch: String
        public var expiresAt: Int64
        public var tipCommitTimestamp: Int64
    }

    public struct BranchActivity: Sendable {
        public var branch: String
        public var commitCount: Int
        public var reflogEntries: Int
        public var lastCommitTimestamp: Int64
    }

    public struct BranchSyncReport: Sendable {
        public var branch: String
        public var hasUpstream: Bool
        public var upstream: String?
        public var ahead: Int
        public var behind: Int
    }

    private func enforceOperationPermission(_ operation: String) throws {
        let permissions = OperationPermissionOps(repo: repo)
        guard permissions.hasConfiguredPermissions() else { return }
        let role = try permissions.currentRole()
        guard try permissions.checkOperationPermission(operation: operation, role: role) else {
            try? AccessAuditOps(repo: repo).recordAuditEvent(
                operation: operation, details: "role \(role.rawValue)", result: "denied: permission")
            throw SpacesError.invalidArgument(
                "operation \(operation) is not permitted for role \(role.rawValue)")
        }
    }

    private func enforceRepositoryPolicy(operation: PolicyEngineOps.PolicyOperation,
                                         details: PolicyEngineOps.PolicyOperationDetails = PolicyEngineOps.PolicyOperationDetails()) throws {
        let violations = try PolicyEngineOps(repo: repo).checkPolicy(operation: operation, details: details)
        guard !violations.isEmpty else { return }
        let message = violations.map { $0.message }.joined(separator: "; ")
        try? AccessAuditOps(repo: repo).recordAuditEvent(
            operation: operation.rawValue,
            details: details.branch ?? details.message ?? "",
            result: "denied: \(message)")
        throw SpacesError.invalidArgument(
            "operation \(operation.rawValue) refused by repository policy: \(message)")
    }

    private func enforceReviewMergePolicy(target: String) throws {
        let check = try ReviewPolicyOps(repo: repo).reviewMergeCheckForTarget(target)
        guard check.allowed else {
            let message = check.reasons.joined(separator: "; ")
            try? AccessAuditOps(repo: repo).recordAuditEvent(
                operation: "merge", details: target, result: "denied: \(message)")
            throw SpacesError.invalidArgument("merge refused by review policy: \(message)")
        }
    }

    static func branchName(fromRefspec refspec: String) -> String? {
        let trimmed = refspec.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let destination = trimmed.split(separator: ":").last.map(String.init) ?? trimmed
        if destination.hasPrefix("refs/heads/") {
            return String(destination.dropFirst("refs/heads/".count))
        }
        if destination.hasPrefix("refs/") { return nil }
        return destination.isEmpty ? nil : destination
    }

    private func validateCommitPolicies(message: String) throws {
        let rules = try ValidationPolicyOps(repo: repo).commitPolicies()
        guard !rules.isEmpty else { return }
        let staged = try status().staged.map { $0.path }
        let violations = try ValidationPolicyOps(repo: repo).validateCommit(message: message, stagedPaths: staged)
        guard violations.isEmpty else {
            throw SpacesError.invalidArgument("commit blocked by policy: \(violations.map { $0.message }.joined(separator: "; "))")
        }
    }

    @discardableResult
    public func commitWithMetadata(message: String, metadata: CommitMetadata) throws -> StagingOps.CommitResult {
        try enforceOperationPermission("commit")
        try enforceRepositoryPolicy(operation: .commit, details: PolicyEngineOps.PolicyOperationDetails(
            message: message, paths: (try? status().staged.map { $0.path }) ?? []))
        try validateCommitPolicies(message: message)
        let result = try StagingOps(repo: repo).commitWithMetadata(message: message, metadata: metadata)
        try? AccessAuditOps(repo: repo).recordAuditEvent(operation: "commit", details: message, result: "success")
        _ = try? AutomationOps(repo: repo).runAutomation(event: .postCommit)
        return result
    }

    @discardableResult
    public func addAnnotation(rev: String, annotation: String) throws -> ObjectID {
        let oldOID = try repo.resolveRevision(rev)
        return try repo.performTransaction(steps: ["annotate"]) {
            var payload = try repo.commitObject(oldOID)
            payload.metadata.annotations.append(annotation)
            let newOID = try repo.objects.write(.commit, value: payload)
            try rewriteRefs(from: oldOID, to: newOID, message: "annotate commit")
            return newOID
        }
    }

    public func compareCommits(from: String, to: String) throws -> CommitComparison {
        let fromOID = try repo.resolveRevision(from)
        let toOID = try repo.resolveRevision(to)
        let fromPayload = try repo.commitObject(fromOID)
        let toPayload = try repo.commitObject(toOID)
        let diffs = try DiffOps(repo: repo).commitDiff(from, to)
        var differences: [String] = []
        if fromPayload.author != toPayload.author { differences.append("author differs") }
        if fromPayload.committer != toPayload.committer { differences.append("committer differs") }
        if fromPayload.message != toPayload.message { differences.append("message differs") }
        if fromPayload.metadata.category != toPayload.metadata.category { differences.append("category differs") }
        let allTrailerKeys = Set(fromPayload.metadata.trailers.keys).union(toPayload.metadata.trailers.keys)
        for key in allTrailerKeys.sorted() where fromPayload.metadata.trailers[key] != toPayload.metadata.trailers[key] {
            differences.append("trailer \(key) differs")
        }
        for annotation in Set(fromPayload.metadata.annotations).subtracting(toPayload.metadata.annotations).sorted() {
            differences.append("annotation removed: \(annotation)")
        }
        for annotation in Set(toPayload.metadata.annotations).subtracting(fromPayload.metadata.annotations).sorted() {
            differences.append("annotation added: \(annotation)")
        }
        if (fromPayload.metadata.signature != nil) != (toPayload.metadata.signature != nil) {
            differences.append("signature presence differs")
        }
        return CommitComparison(from: fromOID, to: toOID, diffs: diffs, metadataDifferences: differences)
    }

    public func signingIdentities() throws -> [String] {
        var identities = ["default"]
        let files = (try? FileManager.default.contentsOfDirectory(atPath: repo.metaURL.path)) ?? []
        for file in files where file.hasPrefix("signing-") && file.hasSuffix(".key") {
            let name = String(file.dropFirst("signing-".count).dropLast(".key".count))
            if !name.isEmpty && name != "default" { identities.append(name) }
        }
        return identities.sorted()
    }

    @discardableResult
    public func signCommit(rev: String, identity: String = "default") throws -> (oid: ObjectID, signature: String) {
        let oldOID = try repo.resolveRevision(rev)
        let payload = try repo.commitObject(oldOID)
        let canonical = canonicalCommitString(payload)
        let signature: String
        if identity == "default" {
            signature = try SigningOps(repo: repo).sign(type: .commit, object: canonical)
        } else {
            signature = try signWithIdentity(identity: identity, object: canonical)
        }
        let newOID = try repo.performTransaction(steps: ["sign-commit"]) {
            var rewritten = payload
            rewritten.metadata.signature = signature
            var trailers = rewritten.metadata.trailers
            trailers["signing-identity"] = identity
            rewritten.metadata.trailers = trailers
            let oid = try repo.objects.write(.commit, value: rewritten)
            try rewriteRefs(from: oldOID, to: oid, message: "sign commit")
            return oid
        }
        return (newOID, signature)
    }

    public func verifyCommitSignature(rev: String) throws -> Bool {
        let oid = try repo.resolveRevision(rev)
        let payload = try repo.commitObject(oid)
        guard let signature = payload.metadata.signature else { return false }
        let identity = payload.metadata.trailers["signing-identity"] ?? "default"
        let canonical = canonicalCommitString(payload)
        if identity == "default" {
            return try SigningOps(repo: repo).verify(type: .commit, object: canonical, signature: signature)
        }
        return (try? signWithIdentity(identity: identity, object: canonical)) == signature
    }

    private func canonicalCommitString(_ payload: CommitPayload) -> String {
        let parents = payload.parents.map { $0.hex }.joined(separator: ",")
        return "\(payload.tree.hex)\n\(parents)\n\(payload.author.name) <\(payload.author.email)> \(payload.author.timestamp)\n\(payload.committer.name) <\(payload.committer.email)> \(payload.committer.timestamp)\n\(payload.message)"
    }

    private func signWithIdentity(identity: String, object: String) throws -> String {
        guard !identity.isEmpty, !identity.contains("/"), !identity.contains("\\"),
              identity != ".", identity != ".." else {
            throw SpacesError.invalidArgument("invalid signing identity: \(identity)")
        }
        let keyURL = repo.metaURL.appendingPathComponent("signing-" + identity + ".key")
        let keyData: Data
        if let existing = try? Data(contentsOf: keyURL), existing.count >= 32 {
            keyData = existing
        } else {
            let generated = SymmetricKey(size: .bits256)
            let data = generated.withUnsafeBytes { Data($0) }
            try data.write(to: keyURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: keyURL.path)
            keyData = data
        }
        let mac = HMAC<SHA256>.authenticationCode(
            for: Data("spaces-sign-v1\ncommit\n\(object)".utf8),
            using: SymmetricKey(data: keyData))
        return mac.map { String(format: "%02x", $0) }.joined()
    }

    private func rewriteRefs(from oldOID: ObjectID, to newOID: ObjectID, message: String) throws {
        for ref in try repo.refs.allRefs() where ref.oid == oldOID {
            let old = try repo.refs.updateRef(ref.name, to: newOID)
            try repo.appendReflog(refName: ref.name, old: old, new: newOID, message: message)
        }
    }

    private func branchStoreURL(_ file: String) -> URL {
        repo.metaURL.appendingPathComponent("branches").appendingPathComponent(file)
    }

    private func loadBranchJSON<T: Decodable>(_ file: String) -> T? {
        guard let data = try? Data(contentsOf: branchStoreURL(file)) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func saveBranchJSON<T: Encodable>(_ file: String, value: T) throws {
        let dir = repo.metaURL.appendingPathComponent("branches")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        try repo.refs.atomicWrite(branchStoreURL(file), contents: encoder.encode(value))
    }

    public func setBranchOwner(branch: String, owner: String) throws {
        try repo.withLock {
            var owners: [String: String] = loadBranchJSON("owners.json") ?? [:]
            owners[branch] = owner
            try saveBranchJSON("owners.json", value: owners)
        }
    }

    public func branchOwner(branch: String) throws -> String? {
        let owners: [String: String] = loadBranchJSON("owners.json") ?? [:]
        return owners[branch]
    }

    public func setBranchExpiration(branch: String, date: Date) throws {
        try repo.withLock {
            var expirations: [String: Int64] = loadBranchJSON("expirations.json") ?? [:]
            expirations[branch] = Int64(date.timeIntervalSince1970)
            try saveBranchJSON("expirations.json", value: expirations)
        }
    }

    public func expiredBranches() throws -> [ExpiredBranch] {
        let expirations: [String: Int64] = loadBranchJSON("expirations.json") ?? [:]
        let now = Int64(Date().timeIntervalSince1970)
        var result: [ExpiredBranch] = []
        for (branch, expiresAt) in expirations where now >= expiresAt {
            var tipTimestamp: Int64 = 0
            if let tip = try repo.refs.readRef("refs/heads/" + branch),
               let commit = try? repo.commitObject(tip) {
                tipTimestamp = commit.committer.timestamp
            }
            result.append(ExpiredBranch(branch: branch, expiresAt: expiresAt, tipCommitTimestamp: tipTimestamp))
        }
        return result.sorted { $0.branch < $1.branch }
    }

    public func protectBranch(branch: String, rules: [ProtectedHistoryOps.ProtectedRefRule]) throws {
        try repo.withLock {
            var stored: [String: [ProtectedHistoryOps.ProtectedRefRule]] = loadBranchJSON("protection.json") ?? [:]
            stored[branch] = rules
            try saveBranchJSON("protection.json", value: stored)
            var history = try ProtectedHistoryOps(repo: repo).protectedHistoryRules()
            history.refs.removeAll { $0.pattern == branch || $0.pattern == "refs/heads/" + branch }
            history.refs.append(contentsOf: rules)
            try ProtectedHistoryOps(repo: repo).setProtectedHistoryRules(history)
        }
    }

    public func branchProtection(branch: String) throws -> [ProtectedHistoryOps.ProtectedRefRule] {
        let stored: [String: [ProtectedHistoryOps.ProtectedRefRule]] = loadBranchJSON("protection.json") ?? [:]
        return stored[branch] ?? []
    }

    public func branchActivity(branch: String) throws -> BranchActivity {
        guard let tip = try repo.refs.readRef("refs/heads/" + branch) else {
            throw SpacesError.branchNotFound(branch)
        }
        let commits = try HistoryOps(repo: repo).walk(start: tip)
        let entries = try repo.readReflog(refName: "refs/heads/" + branch, limit: 1000)
        return BranchActivity(branch: branch, commitCount: commits.count,
                              reflogEntries: entries.count,
                              lastCommitTimestamp: commits.first?.timestamp ?? 0)
    }

    public func branchSyncReport(branch: String) throws -> BranchSyncReport {
        guard let tip = try repo.refs.readRef("refs/heads/" + branch) else {
            throw SpacesError.branchNotFound(branch)
        }
        guard let upstream = repo.config.branchTracking[branch] else {
            return BranchSyncReport(branch: branch, hasUpstream: false, upstream: nil, ahead: 0, behind: 0)
        }
        guard let upstreamOID = try repo.refs.readRef("refs/remotes/" + upstream) else {
            return BranchSyncReport(branch: branch, hasUpstream: false, upstream: upstream, ahead: 0, behind: 0)
        }
        let counts = try WorktreeScanner(repo: repo).countAheadBehind(head: tip, upstream: upstreamOID)
        return BranchSyncReport(branch: branch, hasUpstream: true, upstream: upstream,
                                ahead: counts.ahead, behind: counts.behind)
    }
}

extension SpacesAPI {
    public func compareRevisions(from: String, to: String = "HEAD") throws -> [DiffOps.FileDiff] {
        try DiffOps(repo: repo).compareRevisions(from: from, to: to)
    }

    public func compareDirectories(from: ObjectID, to: ObjectID) throws -> [DiffOps.DirectoryComparison] {
        try DiffOps(repo: repo).compareDirectories(from: from, to: to)
    }

    public func conflictProvenance() throws -> [MergeEngine.ConflictProvenance] {
        try MergeEngine(repo: repo).conflictProvenance()
    }

    public func conflictHistory() throws -> [MergeEngine.ConflictHistoryEntry] {
        try MergeEngine(repo: repo).conflictHistory()
    }

    public func setResolutionPolicy(path: String, resolution: MergeEngine.ResolutionAction) throws {
        try MergeEngine(repo: repo).setResolutionPolicy(path: path, resolution: resolution)
    }

    public func resolutionPolicies() throws -> [MergeEngine.MergeResolutionPolicy] {
        try MergeEngine(repo: repo).resolutionPolicies()
    }

    public func removeResolutionPolicy(path: String) throws {
        try MergeEngine(repo: repo).removeResolutionPolicy(path: path)
    }

    public func resumeFetch(_ remote: String) throws -> RemoteOps.TransferReport {
        try RemoteOps(repo: repo).resumeFetch(remote)
    }

    public func resumePush(_ remote: String, refspec: String) throws -> RemoteOps.TransferReport {
        try RemoteOps(repo: repo).resumePush(remote, refspec: refspec)
    }

    public func lastTransferReport(_ remote: String) throws -> RemoteOps.TransferReport? {
        try RemoteOps(repo: repo).lastTransferReport(remote)
    }

    public func remoteHealth(_ remote: String) throws -> RemoteOps.RemoteHealth {
        try RemoteOps(repo: repo).remoteHealth(remote)
    }

    public func cancelRemoteTransfer(_ remote: String) throws {
        try RemoteOps(repo: repo).cancelRemoteTransfer(remote)
    }

    public func clearRemoteCancel(_ remote: String) {
        RemoteOps(repo: repo).clearRemoteCancel(remote)
    }

    public func gcWithBudget() throws -> MaintenanceOps.StorageBudgetReport {
        try MaintenanceOps(repo: repo).gcWithBudget()
    }

    public func duplicateContentReport() throws -> MaintenanceOps.DuplicateContentReport {
        try MaintenanceOps(repo: repo).duplicateContentReport()
    }

    public func performanceDiagnostics() throws -> MaintenanceOps.PerformanceDiagnostics {
        try MaintenanceOps(repo: repo).performanceDiagnostics()
    }
}



final class SpacesEventHub: @unchecked Sendable {
    static let shared = SpacesEventHub()
    private let lock = NSLock()
    private var streams: [String: [UUID: AsyncStream<SpacesEvent>.Continuation]] = [:]

    func subscribe(worktree: URL) -> AsyncStream<SpacesEvent> {
        let key = worktree.standardizedFileURL.path
        let id = UUID()
        return AsyncStream { continuation in
            self.lock.lock()
            self.streams[key, default: [:]][id] = continuation
            self.lock.unlock()
            continuation.onTermination = { _ in
                self.lock.lock()
                self.streams[key]?[id] = nil
                self.lock.unlock()
            }
        }
    }

    func emit(_ event: SpacesEvent, worktree: URL) {
        let key = worktree.standardizedFileURL.path
        lock.lock()
        let continuations = Array((streams[key] ?? [:]).values)
        lock.unlock()
        for continuation in continuations { continuation.yield(event) }
    }
}

public enum SpacesEvent: Sendable {
    case statusChanged
    case refsChanged
    case operationStarted(String)
    case operationFinished(String)
}
