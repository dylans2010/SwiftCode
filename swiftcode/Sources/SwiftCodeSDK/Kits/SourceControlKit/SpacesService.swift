import Foundation
import SpacesEngine







public actor SpacesService {
    public static let shared = SpacesService()

    private var cache: [String: (Repository, SpacesAPI)] = [:]

    public init() {}

    
    public static var defaultBranchSetting: String {
        UserDefaults.standard.string(forKey: "spacesDefaultBranch") ?? "main"
    }

    public func isSpacesAvailable(at url: URL) async -> Bool {
        guard Repository.isRepository(at: url) else { return false }
        return (try? Repository.open(at: url)) != nil
    }

    
    public func isSpacesRepository(at url: URL) -> Bool {
        Repository.isRepository(at: url)
    }

    
    @discardableResult
    public func initialize(at url: URL, defaultBranch: String = "main") throws -> URL {
        let repo = try Repository.create(at: url, defaultBranch: defaultBranch)
        cache[repo.worktreeURL.path] = (repo, SpacesAPI(repo: repo))
        return repo.worktreeURL
    }

    private func api(for repositoryURL: URL) throws -> (Repository, SpacesAPI) {
        let key = repositoryURL.standardizedFileURL.path
        if let hit = cache[key] { return hit }
        let repo = try Repository.open(at: repositoryURL)
        let api = SpacesAPI(repo: repo)
        cache[repo.worktreeURL.path] = (repo, api)
        return (repo, api)
    }

    private func relativePath(_ path: URL, repositoryURL: URL, repo: Repository) throws -> String {
        if let rel = try? repo.relativePath(path) { return rel }
        let prefix = repositoryURL.standardizedFileURL.path + "/"
        let p = path.standardizedFileURL.path
        guard p.hasPrefix(prefix) else {
            throw SpacesError.invalidArgument("\(path.path) is outside the repository")
        }
        return String(p.dropFirst(prefix.count))
    }

    

    public func getStatus(for repositoryURL: URL) async throws -> GitStatusSnapshot {
        let (_, api) = try api(for: repositoryURL)
        let report = try api.status()
        var files: [GitFileStatus] = []
        for entry in report.entries {
            if entry.isUntracked {
                files.append(GitFileStatus(path: entry.path, status: .untracked, isStaged: false))
                continue
            }
            if let staged = entry.indexStatus, entry.isStaged {
                files.append(GitFileStatus(path: entry.path,
                                           status: Self.statusType(staged), isStaged: true))
            }
            if let unstaged = entry.worktreeStatus, entry.isUnstaged {
                files.append(GitFileStatus(path: entry.oldPath ?? entry.path,
                                           status: Self.statusType(unstaged), isStaged: false))
            }
        }
        return GitStatusSnapshot(branchName: report.branch ?? "HEAD",
                                 ahead: report.ahead, behind: report.behind,
                                 files: files)
    }

    private static func statusType(_ kind: WorktreeScanner.ChangeKind) -> GitFileStatus.StatusType {
        switch kind {
        case .added: return .added
        case .deleted: return .deleted
        case .renamed: return .renamed
        case .untracked: return .untracked
        case .modified, .typechanged: return .modified
        }
    }

    

    public func stage(path: URL, repositoryURL: URL) async throws {
        let (repo, api) = try api(for: repositoryURL)
        let rel = try relativePath(path, repositoryURL: repositoryURL, repo: repo)
        _ = try api.add(rel)
    }

    public func unstage(path: URL, repositoryURL: URL) async throws {
        let (repo, api) = try api(for: repositoryURL)
        let rel = try relativePath(path, repositoryURL: repositoryURL, repo: repo)
        try api.unstage(rel)
    }

    public func discardChanges(path: URL, repositoryURL: URL) async throws {
        let (repo, api) = try api(for: repositoryURL)
        let rel = try relativePath(path, repositoryURL: repositoryURL, repo: repo)
        try api.restore(rel)
    }

    public func stageAll(repositoryURL: URL) async throws {
        let (_, api) = try api(for: repositoryURL)
        _ = try api.stageAll()
    }

    public func commit(message: String, repositoryURL: URL) async throws {
        let (_, api) = try api(for: repositoryURL)
        _ = try api.commit(message: message)
    }

    public func clone(remoteURL: URL, destinationURL: URL, token: String?) async throws {
        if let token, !token.isEmpty {
            guard let scheme = remoteURL.scheme?.lowercased(),
                  scheme == "http" || scheme == "https" || scheme == "spaces",
                  let host = remoteURL.host, !host.isEmpty else {
                throw SpacesError.invalidArgument("a clone token is only supported for http(s) remotes")
            }
            #if os(macOS)
            try KeychainCredentialStore().save(Credentials(token: token), for: host)
            #else
            try FileCredentialStore().save(Credentials(token: token), for: host)
            #endif
        }
        _ = try CloneOps.clone(url: remoteURL.absoluteString, into: destinationURL)
    }

    

    public func getLog(repositoryURL: URL) async throws -> [GitCommit] {
        let (_, api) = try api(for: repositoryURL)
        return try api.log(limit: 100).map { info in
            GitCommit(hash: info.oid.hex,
                      shortHash: String(info.oid.hex.prefix(7)),
                      authorName: info.author.name,
                      authorEmail: info.author.email,
                      date: Date(timeIntervalSince1970: TimeInterval(info.timestamp)),
                      message: info.message,
                      parentHashes: info.parents.map(\.hex))
        }
    }

    public func getBranches(repositoryURL: URL) async throws -> [GitBranch] {
        let (_, api) = try api(for: repositoryURL)
        return try api.branches().map {
            GitBranch(name: $0.name, isCurrent: $0.isCurrent, isRemote: $0.isRemote)
        }
    }

    public func createBranch(name: String, repositoryURL: URL) async throws {
        let (_, api) = try api(for: repositoryURL)
        _ = try api.createBranch(name)
        try api.switchTo(name)
    }

    public func checkout(branch: String, repositoryURL: URL) async throws {
        let (_, api) = try api(for: repositoryURL)
        try api.switchTo(branch)
    }

    public func deleteBranch(name: String, repositoryURL: URL) async throws {
        let (_, api) = try api(for: repositoryURL)
        try api.deleteBranch(name)
    }

    public func renameBranch(_ old: String, to new: String, repositoryURL: URL) async throws {
        let (_, api) = try api(for: repositoryURL)
        try api.renameBranch(old, to: new)
    }

    public func cherryPick(rev: String, repositoryURL: URL) async throws {
        let (_, api) = try api(for: repositoryURL)
        _ = try api.cherryPick(rev)
    }

    public func blame(fileURL: URL, repositoryURL: URL) async throws -> [HistoryOps.BlameLine] {
        let (repo, api) = try api(for: repositoryURL)
        let rel = try relativePath(fileURL, repositoryURL: repositoryURL, repo: repo)
        return try api.blame(rel)
    }

    public func showCommit(sha: String, repositoryURL: URL) async throws -> HistoryOps.ShowResult {
        let (_, api) = try api(for: repositoryURL)
        return try api.show(sha)
    }

    public func graph(repositoryURL: URL, limit: Int = 100) async throws -> [BranchOps.GraphNode] {
        let (_, api) = try api(for: repositoryURL)
        return try api.graph(limit: limit)
    }

    

    public func getDiff(repositoryURL: URL) async throws -> [GitDiffHunk] {
        let (_, api) = try api(for: repositoryURL)
        let diffs = try api.diff()
        var hunks: [GitDiffHunk] = []
        for file in diffs {
            guard let patch = file.patch else { continue }
            hunks.append(contentsOf: Self.parseUnifiedPatch(patch, filePath: file.newPath))
        }
        return hunks
    }

    
    static func parseUnifiedPatch(_ patch: String, filePath: String) -> [GitDiffHunk] {
        var hunks: [GitDiffHunk] = []
        var header: String?
        var lines: [String] = []
        for line in patch.components(separatedBy: .newlines) {
            if line.hasPrefix("@@") {
                if let h = header {
                    hunks.append(GitDiffHunk(filePath: filePath, header: h, lines: lines))
                }
                header = line
                lines = []
            } else if header != nil {
                lines.append(line)
            }
        }
        if let h = header {
            hunks.append(GitDiffHunk(filePath: filePath, header: h, lines: lines))
        }
        return hunks
    }

    

    public func fetch(repositoryURL: URL, remote: String = "origin") async throws {
        let (_, api) = try api(for: repositoryURL)
        _ = try api.fetch(remote)
    }

    public func pull(repositoryURL: URL, remote: String = "origin") async throws {
        let (_, api) = try api(for: repositoryURL)
        _ = try api.pull(remote)
    }

    public func push(repositoryURL: URL, remote: String = "origin") async throws {
        let (repo, api) = try api(for: repositoryURL)
        guard let branch = try repo.refs.currentBranch() else {
            throw SpacesError.invalidArgument("no current branch")
        }
        _ = try api.push(remote, refspec: "refs/heads/\(branch):refs/heads/\(branch)")
    }

    public func forcePush(branch: String, repositoryURL: URL) async throws {
        let (_, api) = try api(for: repositoryURL)
        _ = try api.push("origin", refspec: "refs/heads/\(branch):refs/heads/\(branch)", force: true)
    }

    public func rollback(to sha: String, repositoryURL: URL) async throws {
        let (_, api) = try api(for: repositoryURL)
        try api.reset(to: sha, mode: .hard)
    }

    

    public func merge(_ target: String, repositoryURL: URL) async throws {
        let (_, api) = try api(for: repositoryURL)
        _ = try api.merge(target)
    }

    public func stash(message: String, repositoryURL: URL) async throws {
        let (_, api) = try api(for: repositoryURL)
        _ = try api.stash(message: message)
    }

    public func remotes(repositoryURL: URL) async throws -> [GitRemote] {
        let (repo, _) = try api(for: repositoryURL)
        return repo.config.remotes.keys.sorted().map {
            GitRemote(name: $0,
                      fetchURL: repo.config.remotes[$0]?.url ?? "",
                      pushURL: repo.config.remotes[$0]?.pushURL ?? repo.config.remotes[$0]?.url ?? "")
        }
    }

    public func tags(repositoryURL: URL) async throws -> [GitBranch] {
        let (_, api) = try api(for: repositoryURL)
        return try api.tags().map {
            GitBranch(name: $0.name, isCurrent: false, isRemote: false)
        }
    }

    public func createTag(name: String, at rev: String = "HEAD", annotated: Bool = false, message: String = "", repositoryURL: URL) async throws {
        let (_, api) = try api(for: repositoryURL)
        _ = try api.createTag(name, at: rev, annotated: annotated, message: message)
    }

    public func deleteTag(name: String, repositoryURL: URL) async throws {
        let (_, api) = try api(for: repositoryURL)
        try api.deleteTag(name)
    }

    

    public func worktrees(repositoryURL: URL) async throws -> [WorktreeOps.WorktreeInfo] {
        let (repo, _) = try api(for: repositoryURL)
        return try WorktreeOps(repo: repo).list()
    }

    public func addWorktree(path: String, branch: String?, repositoryURL: URL) async throws -> WorktreeOps.WorktreeInfo {
        let (repo, _) = try api(for: repositoryURL)
        return try WorktreeOps(repo: repo).add(path: path, branch: branch)
    }

    public func removeWorktree(_ nameOrPath: String, repositoryURL: URL) async throws {
        let (repo, _) = try api(for: repositoryURL)
        try WorktreeOps(repo: repo).remove(nameOrPath)
    }

    

    public struct FileDiffStat: Sendable {
        public let path: String
        public let added: Int?
        public let removed: Int?
        public let isBinary: Bool
        public init(path: String, added: Int?, removed: Int?, isBinary: Bool) {
            self.path = path
            self.added = added
            self.removed = removed
            self.isBinary = isBinary
        }
    }

    public func getCommitFileStats(sha: String, repositoryURL: URL) async throws -> [FileDiffStat] {
        let (repo, _) = try api(for: repositoryURL)
        let oid = try repo.resolveRevision(sha)
        let commit = try repo.commitObject(oid)
        if let parent = commit.parents.first {
            let parentTree = try repo.commitObject(parent).tree
            let diffs = try DiffOps(repo: repo).diffTrees(parentTree, commit.tree)
            return diffs.map { d in
                FileDiffStat(path: d.newPath,
                             added: d.isBinary ? nil : d.added,
                             removed: d.isBinary ? nil : d.removed,
                             isBinary: d.isBinary)
            }
        } else {
            let flat = try TreeBuilder.flattenTree(repo: repo, treeOID: commit.tree)
            var stats: [FileDiffStat] = []
            for (path, e) in flat.sorted(by: { $0.key < $1.key }) {
                let data = try repo.blobData(e.oid)
                let isBin = DiffEngine.isBinary(data)
                let lines = isBin ? 0 : DiffEngine.splitLines(data).count
                stats.append(FileDiffStat(path: path,
                                         added: isBin ? nil : lines,
                                         removed: isBin ? nil : 0,
                                         isBinary: isBin))
            }
            return stats
        }
    }

    public func getDiffBetween(from: String, to: String, repositoryURL: URL) async throws -> String {
        let (repo, _) = try api(for: repositoryURL)
        let fromOID = try repo.resolveRevision(from)
        let toOID = try repo.resolveRevision(to)
        let fromTree = try repo.commitObject(fromOID).tree
        let toTree = try repo.commitObject(toOID).tree
        let diffs = try DiffOps(repo: repo).diffTrees(fromTree, toTree)
        var out = ""
        for d in diffs {
            if let p = d.patch {
                out += p
            } else {
                out += "diff --spaces a/\(d.oldPath) b/\(d.newPath)\n"
            }
        }
        return out
    }

    public func compare(from: String, to: String, repositoryURL: URL) async throws -> String {
        let (_, api) = try api(for: repositoryURL)
        let diffs = try api.diff(from, to)
        var out = ""
        for d in diffs {
            if let p = d.patch {
                out += p
            } else {
                out += "diff --spaces a/\(d.oldPath) b/\(d.newPath)\n"
            }
        }
        return out
    }

    public func search(query: String, repositoryURL: URL) async throws -> [SearchOps.Result] {
        let (_, api) = try api(for: repositoryURL)
        return try api.search(SearchOps.Query(text: query))
    }

    

    public func rebase(onto: String, repositoryURL: URL) async throws {
        let (_, api) = try api(for: repositoryURL)
        _ = try api.rebase(onto: onto)
    }

    public func rebaseContinue(repositoryURL: URL) async throws {
        let (_, api) = try api(for: repositoryURL)
        _ = try api.rebaseContinue()
    }

    public func rebaseAbort(repositoryURL: URL) async throws {
        let (_, api) = try api(for: repositoryURL)
        try api.rebaseAbort()
    }

    public func mergeContinue(repositoryURL: URL) async throws {
        let (_, api) = try api(for: repositoryURL)
        _ = try api.mergeContinue()
    }

    public func mergeAbort(repositoryURL: URL) async throws {
        let (_, api) = try api(for: repositoryURL)
        try api.mergeAbort()
    }

    

    public func stashes(repositoryURL: URL) async throws -> [StashOps.StashEntry] {
        let (_, api) = try api(for: repositoryURL)
        return try api.stashes()
    }

    public func stashApply(id: String, pop: Bool = false, repositoryURL: URL) async throws {
        let (_, api) = try api(for: repositoryURL)
        try api.stashApply(id, pop: pop)
    }

    public func stashDrop(id: String, repositoryURL: URL) async throws {
        let (_, api) = try api(for: repositoryURL)
        try api.stashDrop(id)
    }

    public func snapshot(message: String, repositoryURL: URL) async throws {
        let (_, api) = try api(for: repositoryURL)
        _ = try api.snapshot(message: message)
    }

    public func snapshots(repositoryURL: URL) async throws -> [SnapshotOps.SnapshotInfo] {
        let (_, api) = try api(for: repositoryURL)
        return try api.snapshots()
    }

    public func timeline(repositoryURL: URL, limit: Int = 50) async throws -> [SnapshotOps.TimelineEntry] {
        let (_, api) = try api(for: repositoryURL)
        return try api.timeline(limit: limit)
    }

    public func restoreSnapshot(rev: String, repositoryURL: URL) async throws {
        let (_, api) = try api(for: repositoryURL)
        try api.restoreSnapshot(rev)
    }

    

    public func clean(repositoryURL: URL) async throws -> [String] {
        let (_, api) = try api(for: repositoryURL)
        return try api.clean()
    }

    public func gc(repositoryURL: URL) async throws -> (pruned: Int, reachable: Int) {
        let (_, api) = try api(for: repositoryURL)
        return try api.gc()
    }
}
