import Foundation





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

    
    
    @discardableResult
    public func create(message: String? = nil, includeUntracked: Bool = false) throws -> StashEntry? {
        try repo.performTransaction(steps: ["stash"]) {
            let staging = StagingOps(repo: repo)
            let scanner = WorktreeScanner(repo: repo)
            guard let headOID = try repo.refs.headOID(objects: repo.objects) else {
                throw SpacesError.branchNotFound("HEAD (unborn)")
            }
            let headCommit = try repo.commitObject(headOID)

            let indexBefore = try repo.index()
            var indexListing: [String: (oid: ObjectID, mode: FileMode)] = [:]
            for (p, e) in indexBefore.entries { indexListing[p] = (e.oid, e.mode) }
            let indexTree = try TreeBuilder.writeTree(entries: indexListing, objects: repo.objects)

            let untrackedPaths = try scanner.status().untrackedFiles.map { $0.path }
            if includeUntracked {
                _ = try staging.add(".", all: true)
            } else {
                _ = try stageTrackedOnly()
            }
            let worktreeTree = try staging.writeIndexTree()

            guard worktreeTree != headCommit.tree || indexTree != headCommit.tree else {
                throw SpacesError.invalidArgument("no local changes to stash")
            }

            let ident = repo.identity()
            let branchName = try repo.refs.currentBranch()
            let msg = message ?? "WIP on \(branchName ?? "HEAD")"
            let indexCommitOID = try repo.objects.write(.commit, value: CommitPayload(
                tree: indexTree, parents: [headOID], author: ident, committer: ident,
                message: "index on \(branchName ?? "HEAD"): \(headCommit.summary)"))
            var parents: [ObjectID] = [headOID, indexCommitOID]
            var trailers: [String: String] = ["stash": "true",
                                               "index-commit": indexCommitOID.hex]
            if includeUntracked, !untrackedPaths.isEmpty {
                var untrackedListing: [String: (oid: ObjectID, mode: FileMode)] = [:]
                let files = try scanner.scan()
                var byPath: [String: WorktreeScanner.FileEntry] = [:]
                for f in files { byPath[f.relativePath] = f }
                for path in untrackedPaths {
                    if let entry = byPath[path] {
                        untrackedListing[path] = try scanner.hashEntry(entry)
                    }
                }
                let untrackedTree = try TreeBuilder.writeTree(entries: untrackedListing, objects: repo.objects)
                let untrackedCommitOID = try repo.objects.write(.commit, value: CommitPayload(
                    tree: untrackedTree, parents: [headOID], author: ident, committer: ident,
                    message: "untracked files on \(branchName ?? "HEAD"): \(headCommit.summary)"))
                parents.append(untrackedCommitOID)
                trailers["untracked-commit"] = untrackedCommitOID.hex
                trailers["include-untracked"] = "true"
            }
            let payload = CommitPayload(tree: worktreeTree, parents: parents,
                                        author: ident, committer: ident,
                                        message: msg,
                                        metadata: CommitMetadata(trailers: trailers))
            let stashOID = try repo.objects.write(.commit, value: payload)

            let entry = StashEntry(id: String(stashOID.hex.prefix(8)), oid: stashOID,
                                   message: msg,
                                   timestamp: Int64(Date().timeIntervalSince1970),
                                   branch: try repo.refs.currentBranch())
            var entries = try list()
            entries.insert(entry, at: 0)
            try saveList(entries)

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

    private func stageTrackedOnly() throws -> [String] {
        let scanner = WorktreeScanner(repo: repo)
        let files = try scanner.scan()
        let index = try repo.index()
        let headTreeOID: ObjectID
        if let head = try repo.headCommit() {
            headTreeOID = head.tree
        } else {
            headTreeOID = try TreeBuilder.emptyTree(objects: repo.objects)
        }
        let headFlat = try TreeBuilder.flattenTree(repo: repo, treeOID: headTreeOID)
        var staged: [String] = []
        var present = Set<String>()
        for f in files {
            present.insert(f.relativePath)
            guard index.entries[f.relativePath] != nil || headFlat[f.relativePath] != nil else {
                continue
            }
            _ = try StagingOps(repo: repo).hashWorktreeFile(f.relativePath)
            staged.append(f.relativePath)
        }
        var newIndex = try repo.index()
        for path in newIndex.entries.keys where !present.contains(path) {
            newIndex.entries.removeValue(forKey: path)
            staged.append(path)
        }
        try repo.saveIndex(newIndex)
        return staged.sorted()
    }

    public func show(_ id: String) throws -> StashEntry {
        guard let e = try list().first(where: { $0.id == id || $0.oid.hex.hasPrefix(id) || String($0.oid.hex.prefix(8)) == id }) else {
            throw SpacesError.refNotFound("stash \(id)")
        }
        return e
    }

    
    
    @discardableResult
    public func apply(_ id: String, drop: Bool = false) throws { return try repo.withLock {
        if let pending = repo.readState("STASH_HEAD")?.trimmingCharacters(in: .whitespacesAndNewlines),
           !pending.isEmpty {
            throw SpacesError.invalidArgument(
                "a stash apply is already in progress (stash \(pending)); resolve it or run applyContinue first")
        }
        let entry = try show(id)
        let stashCommit = try repo.commitObject(entry.oid)
        guard let headOID = try repo.refs.headOID(objects: repo.objects) else {
            throw SpacesError.branchNotFound("HEAD")
        }

        let baseOID = stashCommit.parents.first ?? headOID
        let merged = try MergeEngine(repo: repo).mergeTrees(
            oursHead: headOID, theirsOID: entry.oid, baseOID: baseOID)
        if !merged.conflicts.isEmpty {

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
            try repo.writeState("STASH_HEAD", contents: entry.oid.hex + "\n")
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

    @discardableResult
    public func applyContinue(drop: Bool = false) throws -> StashEntry { return try repo.withLock {
        guard let text = repo.readState("STASH_HEAD")?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty,
              let stashOID = try? ObjectID(validating: text) else {
            throw SpacesError.invalidArgument("no stash apply in progress")
        }
        let unresolved = try WorktreeScanner(repo: repo).conflictedPaths()
        guard unresolved.isEmpty else { throw SpacesError.conflictsRemain(unresolved) }
        _ = try StagingOps(repo: repo).add(".", all: true)
        let entry = StashEntry(id: String(stashOID.hex.prefix(8)), oid: stashOID,
                               message: (try? repo.commitObject(stashOID).message) ?? "",
                               timestamp: Int64(Date().timeIntervalSince1970),
                               branch: try repo.refs.currentBranch())
        repo.clearState(["STASH_HEAD", "conflicts.json"])
        if drop {
            var entries = try list()
            entries.removeAll { $0.oid == stashOID }
            try saveList(entries)
        }
        return entry
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

    
    
    public func branch(_ name: String, at id: String) throws { return try repo.withLock {
        let entry = try show(id)
        _ = try BranchOps(repo: repo).create(name, at: entry.oid.hex)
        try BranchOps(repo: repo).switchTo(name)
        try apply(id)
        }
    }
}
