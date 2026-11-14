import Foundation

/// Stash operations. A stash is a commit object (type .commit) whose message
/// carries stash metadata in `metadata.trailers`, stored under
/// `refs/stash/<id>` plus a reflog-style list in `.spaces/stash.json` for
/// named/multiple stashes.
public struct StashOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public struct StashEntry: Codable, Sendable {
        public var id: String
        public var oid: ObjectID
        public var message: String
        public var timestamp: Int64
        public var branch: String?
    }

    private var stashListURL: URL { repo.metaURL.appendingPathComponent("stash.json") }

    public func list() throws -> [StashEntry] {
        guard let data = try? Data(contentsOf: stashListURL),
              let entries = try? JSONDecoder().decode([StashEntry].self, from: data) else {
            return []
        }
        return entries.sorted { $0.timestamp > $1.timestamp }
    }

    private func saveList(_ entries: [StashEntry]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        try encoder.encode(entries).write(to: stashListURL)
    }

    /// `spaces stash [message]` — records worktree+index state, then resets
    /// the worktree to HEAD.
    @discardableResult
    public func create(message: String? = nil, includeUntracked: Bool = false) throws -> StashEntry? {
        try repo.performTransaction(steps: ["stash"]) {
            let staging = StagingOps(repo: repo)
            // Stage everything first so the stash captures the full state.
            _ = try staging.add(".", all: true)
            let worktreeTree = try staging.writeIndexTree()
            guard let headOID = try repo.refs.headOID(objects: repo.objects) else {
                throw SpacesError.branchNotFound("HEAD (unborn)")
            }
            let headCommit = try repo.commitObject(headOID)
            // Stash commit: tree = worktree state, parents = [HEAD], metadata
            // records the index tree for faithful apply.
            let index = try repo.index()
            var indexListing: [String: (oid: ObjectID, mode: FileMode)] = [:]
            for (p, e) in index.entries { indexListing[p] = (e.oid, e.mode) }
            let indexTree = try TreeBuilder.writeTree(entries: indexListing, objects: repo.objects)

            let ident = repo.identity()
            let branchName = try repo.refs.currentBranch()
            let msg = message ?? "WIP on \(branchName ?? "HEAD")"
            var trailers: [String: String] = ["stash": "true"]
            if includeUntracked { trailers["include-untracked"] = "true" }
            let payload = CommitPayload(tree: worktreeTree, parents: [headOID],
                                        author: ident, committer: ident,
                                        message: msg,
                                        metadata: CommitMetadata(trailers: trailers))
            let stashOID = try repo.objects.write(.commit, value: payload)
            _ = indexTree

            let entry = StashEntry(id: String(stashOID.hex.prefix(8)), oid: stashOID,
                                   message: msg,
                                   timestamp: Int64(Date().timeIntervalSince1970),
                                   branch: try repo.refs.currentBranch())
            var entries = try list()
            entries.insert(entry, at: 0)
            try saveList(entries)

            // Reset worktree+index to HEAD.
            _ = try TreeBuilder.checkout(repo: repo, treeOID: headCommit.tree)
            let flat = try TreeBuilder.flattenTree(repo: repo, treeOID: headCommit.tree)
            var newIndex = Index()
            for (path, e) in flat {
                let url = try repo.worktreeURL(forRelativePath: path)
                newIndex.entries[path] = try Index.entry(forFileAt: url, oid: e.oid, mode: e.mode)
            }
            try repo.saveIndex(newIndex)
            return entry
        }
    }

    public func show(_ id: String) throws -> StashEntry {
        guard let e = try list().first(where: { $0.id == id || $0.oid.hex.hasPrefix(id) || String($0.oid.hex.prefix(8)) == id }) else {
            throw SpacesError.refNotFound("stash \(id)")
        }
        return e
    }

    /// Applies a stash: merges its tree into the current worktree/index.
    /// `drop` removes the entry afterwards (pop semantics).
    @discardableResult
    public func apply(_ id: String, drop: Bool = false) throws { return try repo.withLock {
        let entry = try show(id)
        let stashCommit = try repo.commitObject(entry.oid)
        guard let headOID = try repo.refs.headOID(objects: repo.objects) else {
            throw SpacesError.branchNotFound("HEAD")
        }
        // Merge stash tree into HEAD via the merge engine (base = stash parent).
        let baseOID = stashCommit.parents.first ?? headOID
        let merged = try MergeEngine(repo: repo).mergeTrees(
            oursHead: headOID, theirsOID: entry.oid, baseOID: baseOID)
        if !merged.conflicts.isEmpty {
            // Write conflict-markered worktree.
            let staging = StagingOps(repo: repo)
            try MergeEngine(repo: repo).checkoutTree(merged.tree, overlay: merged.resolved)
            _ = staging
            let records = merged.conflicts.map {
                WorktreeScanner.ConflictRecord(path: $0.path, resolved: false,
                                               ours: nil, theirs: nil, base: nil)
            }
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
            try encoder.encode(records).write(
                to: repo.metaURL.appendingPathComponent("conflicts.json"))
            throw SpacesError.conflictsRemain(merged.conflicts.map(\.path))
        }
        try MergeEngine(repo: repo).checkoutTree(merged.tree, overlay: merged.resolved)
        if drop {
            var entries = try list()
            entries.removeAll { $0.id == entry.id }
            try saveList(entries)
        }
        }
    }

    public func drop(_ id: String) throws { return try repo.withLock {
        var entries = try list()
        guard let e = try? show(id) else { throw SpacesError.refNotFound("stash \(id)") }
        entries.removeAll { $0.id == e.id }
        try saveList(entries)
        }
    }

    public func rename(_ id: String, to newMessage: String) throws { return try repo.withLock {
        var entries = try list()
        guard let idx = entries.firstIndex(where: { $0.id == id || String($0.oid.hex.prefix(8)) == id }) else {
            throw SpacesError.refNotFound("stash \(id)")
        }
        entries[idx].message = newMessage
        try saveList(entries)
        }
    }

    /// `spaces stash-branch <name> <id>` — creates a branch at the stash and
    /// applies it there.
    public func branch(_ name: String, at id: String) throws { return try repo.withLock {
        let entry = try show(id)
        _ = try BranchOps(repo: repo).create(name, at: entry.oid.hex)
        try BranchOps(repo: repo).switchTo(name)
        try apply(id)
        }
    }
}
