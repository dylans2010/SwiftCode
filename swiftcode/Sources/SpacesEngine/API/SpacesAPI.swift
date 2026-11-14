import Foundation

/// Public API surface for Spaces. Typed, async, cancellable. The CLI and the
/// SwiftCode app both go through this layer — there is exactly one engine.
public final class SpacesAPI: @unchecked Sendable {
    public let repo: Repository

    public init(repo: Repository) {
        self.repo = repo
    }

    public static func open(at path: String? = nil) throws -> SpacesAPI {
        let url = path.map { URL(fileURLWithPath: $0) }
        return SpacesAPI(repo: try Repository.open(at: url))
    }

    // MARK: - Repository

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

    // MARK: - Status & staging

    public func status() throws -> WorktreeScanner.StatusReport {
        try WorktreeScanner(repo: repo).status()
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
        try repo.performTransaction {
            if staged { try StagingOps(repo: repo).unstage(path) }
            else { try StagingOps(repo: repo).restoreWorktree(path) }
        }
    }

    public func clean(dryRun: Bool = false) throws -> [String] {
        try StagingOps(repo: repo).clean(dryRun: dryRun)
    }

    // MARK: - Commits

    @discardableResult
    public func commit(message: String, amend: Bool = false,
                       trailers: [String: String] = [:]) throws -> StagingOps.CommitResult {
        try StagingOps(repo: repo).commit(message: message, amend: amend, trailers: trailers)
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

    // MARK: - Branches

    public func branches() throws -> [BranchOps.BranchInfo] {
        try BranchOps(repo: repo).list()
    }

    @discardableResult
    public func createBranch(_ name: String, at: String = "HEAD") throws -> ObjectID {
        try repo.performTransaction { try BranchOps(repo: repo).create(name, at: at) }
    }

    public func deleteBranch(_ name: String, force: Bool = false) throws {
        try repo.performTransaction { try BranchOps(repo: repo).delete(name, force: force) }
    }

    public func renameBranch(_ old: String, to new: String) throws {
        try repo.performTransaction { try BranchOps(repo: repo).rename(old, to: new) }
    }

    public func switchTo(_ target: String, create: Bool = false, force: Bool = false) throws {
        try BranchOps(repo: repo).switchTo(target, force: force, create: create)
    }

    public func reset(to rev: String, mode: BranchOps.ResetMode) throws {
        try BranchOps(repo: repo).reset(to: rev, mode: mode)
    }

    // MARK: - Merge & history ops

    @discardableResult
    public func merge(_ target: String) throws -> MergeEngine.MergeOutcome {
        try MergeEngine(repo: repo).merge(target)
    }

    public func mergeContinue() throws -> ObjectID {
        try MergeEngine(repo: repo).mergeContinue()
    }

    public func mergeAbort() throws {
        try MergeEngine(repo: repo).mergeAbort()
    }

    @discardableResult
    public func cherryPick(_ rev: String) throws -> ObjectID? {
        try MergeEngine(repo: repo).cherryPick(rev)
    }

    @discardableResult
    public func revert(_ rev: String) throws -> ObjectID? {
        try MergeEngine(repo: repo).cherryPick(rev, revert: true)
    }

    public func cherryPickContinue() throws -> ObjectID? {
        try MergeEngine(repo: repo).cherryPickContinue()
    }

    public func cherryPickAbort() throws {
        try MergeEngine(repo: repo).cherryPickAbort()
    }

    @discardableResult
    public func rebase(onto: String, todo: [String]? = nil) throws -> RebaseOps.RebaseState? {
        try RebaseOps(repo: repo).start(onto: onto, todo: todo)
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

    // MARK: - Tags

    public func tags() throws -> [TagOps.TagInfo] { try TagOps(repo: repo).list() }

    @discardableResult
    public func createTag(_ name: String, at: String = "HEAD",
                          annotated: Bool = false, message: String = "") throws -> ObjectID {
        try repo.performTransaction {
            try TagOps(repo: repo).create(name, at: at, annotated: annotated, message: message)
        }
    }

    public func deleteTag(_ name: String) throws {
        try repo.performTransaction { try TagOps(repo: repo).delete(name) }
    }

    public func verifyTag(_ name: String) throws -> Bool {
        try TagOps(repo: repo).verify(name)
    }

    // MARK: - Stashes

    public func stashes() throws -> [StashOps.StashEntry] {
        try StashOps(repo: repo).list()
    }

    @discardableResult
    public func stash(message: String? = nil) throws -> StashOps.StashEntry? {
        try StashOps(repo: repo).create(message: message)
    }

    public func stashApply(_ id: String, pop: Bool = false) throws {
        try StashOps(repo: repo).apply(id, drop: pop)
    }

    public func stashDrop(_ id: String) throws {
        try StashOps(repo: repo).drop(id)
    }

    // MARK: - Snapshots & timeline

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

    // MARK: - Remotes

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
        try RemoteOps(repo: repo).fetch(remote)
    }

    public func pull(_ remote: String, branch: String? = nil) throws -> MergeEngine.MergeOutcome? {
        try RemoteOps(repo: repo).pull(remote, branch: branch)
    }

    public func push(_ remote: String, refspec: String) throws -> RemoteOps.PushReport {
        try RemoteOps(repo: repo).push(remote, refspec: refspec)
    }

    // MARK: - Diff

    public func diff(stagedOnly: Bool = false) throws -> [DiffOps.FileDiff] {
        try DiffOps(repo: repo).workingDiff(stagedOnly: stagedOnly)
    }

    public func diff(_ from: String, _ to: String = "HEAD") throws -> [DiffOps.FileDiff] {
        try DiffOps(repo: repo).commitDiff(from, to)
    }

    // MARK: - Search

    public func search(_ query: SearchOps.Query) throws -> [SearchOps.Result] {
        try SearchOps(repo: repo).search(query)
    }

    // MARK: - Maintenance

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
        try MaintenanceOps(repo: repo).storage()
    }

    @discardableResult
    public func repair() throws -> [String] {
        try MaintenanceOps(repo: repo).repair()
    }

    @discardableResult
    public func rebuildIndex() throws -> Int {
        try MaintenanceOps(repo: repo).rebuildIndex()
    }

    // MARK: - Migration

    @discardableResult
    public func importGit(at path: String) throws -> GitMigration.ImportReport {
        try GitMigration(repo: repo).importGit(at: path)
    }

    @discardableResult
    public func exportGit(to path: String) throws -> GitMigration.ExportReport {
        try GitMigration(repo: repo).exportGit(to: path)
    }

    // MARK: - Worktrees

    public func worktrees() throws -> [WorktreeOps.WorktreeInfo] {
        try WorktreeOps(repo: repo).list()
    }

    public func addWorktree(path: String, branch: String? = nil, newBranch: String? = nil) throws -> WorktreeOps.WorktreeInfo {
        try WorktreeOps(repo: repo).add(path: path, branch: branch, newBranch: newBranch)
    }

    public func removeWorktree(_ name: String) throws {
        try WorktreeOps(repo: repo).remove(name)
    }

    // MARK: - Events

    /// Repository event stream for UI/CLI observers. Emits on every mutation
    /// performed against this repository, from any `SpacesAPI` instance or
    /// direct `Repository`/ops-layer call.
    public func events() -> AsyncStream<SpacesEvent> {
        SpacesEventHub.shared.subscribe(worktree: repo.worktreeURL)
    }
}

/// Fan-out hub for repository mutation events, keyed by worktree path so
/// every observer of the same `.spaces/` repository is notified.
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
