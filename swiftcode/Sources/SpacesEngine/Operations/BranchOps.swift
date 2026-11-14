import Foundation

/// Branch and checkout operations.
public struct BranchOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public struct BranchInfo: Sendable, Encodable {
        public var name: String
        public var oid: ObjectID
        public var upstream: String?
        public var isCurrent: Bool
        public var isRemote: Bool
        public var ahead: Int
        public var behind: Int
        public var lastCommit: String
        public var commitTime: Int64
    }

    public func list(includeRemote: Bool = true) throws -> [BranchInfo] {
        var result: [BranchInfo] = []
        let current = try repo.refs.currentBranch()
        for ref in try repo.refs.allRefs() {
            switch ref.kind {
            case .branch:
                let name = ref.shortName
                var ahead = 0, behind = 0
                if let up = repo.config.branchTracking[name],
                   let upOID = try? repo.refs.resolve(up, objects: repo.objects) {
                    let (a, b) = try WorktreeScanner(repo: repo).countAheadBehind(head: ref.oid, upstream: upOID)
                    ahead = a; behind = b
                }
                let commit = try? repo.commitObject(ref.oid)
                result.append(BranchInfo(name: name, oid: ref.oid,
                                         upstream: repo.config.branchTracking[name],
                                         isCurrent: name == current, isRemote: false,
                                         ahead: ahead, behind: behind,
                                         lastCommit: commit?.summary ?? "",
                                         commitTime: commit?.committer.timestamp ?? 0))
            case .remote where includeRemote:
                let name = ref.shortName
                let commit = try? repo.commitObject(ref.oid)
                result.append(BranchInfo(name: name, oid: ref.oid, upstream: nil,
                                         isCurrent: false, isRemote: true,
                                         ahead: 0, behind: 0,
                                         lastCommit: commit?.summary ?? "",
                                         commitTime: commit?.committer.timestamp ?? 0))
            default:
                break
            }
        }
        return result.sorted { $0.name < $1.name }
    }

    /// `spaces branch create <name> [start]`.
    @discardableResult
    public func create(_ name: String, at startPoint: String = "HEAD") throws -> ObjectID { return try repo.withLock {
        guard RefDatabase.isValidRefName("refs/heads/" + name) else {
            throw SpacesError.invalidRef(name)
        }
        let full = "refs/heads/\(name)"
        if try repo.refs.readRef(full) != nil { throw SpacesError.branchExists(name) }
        let oid = try repo.resolveRevision(startPoint)
        let old = try repo.refs.updateRef(full, to: oid)
        try repo.appendReflog(refName: full, old: old, new: oid,
                              message: "branch created from \(startPoint)")
        return oid
        }
    }

    /// `spaces branch delete <name>` — recoverable: the ref is moved to
    /// `refs/archive/branches/<name>-<timestamp>` instead of destroyed, and
    /// recorded in the reflog.
    public func delete(_ name: String, force: Bool = false) throws { return try repo.withLock {
        let full = "refs/heads/\(name)"
        guard let oid = try repo.refs.readRef(full) else {
            throw SpacesError.branchNotFound(name)
        }
        if name == (try repo.refs.currentBranch() ?? "\0") && !force {
            throw SpacesError.invalidArgument("cannot delete the current branch; switch first")
        }
        // Safety: refuse if branch is unmerged into HEAD unless forced.
        if !force, let head = try repo.refs.headOID(objects: repo.objects) {
            let merged = try isAncestor(oid, of: head)
            if !merged {
                throw SpacesError.invalidArgument(
                    "branch '\(name)' is not merged into HEAD (use --force to delete anyway)")
            }
        }
        // Recoverable deletion: archive the ref.
        let stamp = Int64(Date().timeIntervalSince1970)
        let archiveName = "refs/archive/branches/\(name)-\(stamp)"
        _ = try repo.refs.updateRef(archiveName, to: oid)
        try repo.refs.deleteRef(full)
        try repo.appendReflog(refName: "HEAD", old: oid, new: nil,
                              message: "branch deleted: \(name) (archived as \(archiveName))")
        }
    }

    public func rename(_ old: String, to new: String) throws { return try repo.withLock {
        guard let oid = try repo.refs.readRef("refs/heads/\(old)") else {
            throw SpacesError.branchNotFound(old)
        }
        _ = try repo.refs.updateRef("refs/heads/\(new)", to: oid)
        try repo.refs.deleteRef("refs/heads/\(old)")
        if repo.config.branchTracking[old] != nil {
            repo.config.branchTracking[new] = repo.config.branchTracking.removeValue(forKey: old)
            try repo.saveConfig()
        }
        if try repo.refs.currentBranch() == old {
            try repo.refs.setHEAD(ref: "refs/heads/\(new)")
        }
        }
    }

    /// `spaces switch <branch>` / `spaces checkout <branch|commit>`.
    /// Updates HEAD, index, and worktree. Refuses on dirty tree unless forced.
    public func switchTo(_ target: String, force: Bool = false,
                         create: Bool = false) throws {
        try repo.performTransaction(steps: ["switch:\(target)"]) {
            if repo.inMerge() || repo.inRebase() || repo.inCherryPick() {
                throw SpacesError.invalidArgument("cannot switch during an in-progress operation")
            }
            // Branch switch vs detached checkout.
            let isBranch = (try? repo.refs.readRef("refs/heads/\(target)")) != nil || create
            let targetOID: ObjectID
            if create {
                targetOID = try self.create(target)
            } else if isBranch {
                guard let oid = try repo.refs.readRef("refs/heads/\(target)") else {
                    throw SpacesError.branchNotFound(target)
                }
                targetOID = oid
            } else {
                targetOID = try repo.resolveRevision(target)
            }

            // Dirty check.
            if !force {
                let status = try WorktreeScanner(repo: repo).status()
                let dirty = status.entries.filter {
                    $0.indexStatus == .untracked ? false : ($0.isStaged || $0.isUnstaged)
                }
                if !dirty.isEmpty {
                    throw SpacesError.dirtyWorkingTree(dirty.map { $0.path })
                }
            }

            let commit = try repo.commitObject(targetOID)
            // Write target tree to worktree.
            _ = try TreeBuilder.checkout(repo: repo, treeOID: commit.tree)
            // Rebuild index from tree.
            let flat = try TreeBuilder.flattenTree(repo: repo, treeOID: commit.tree)
            var index = Index()
            for (path, e) in flat {
                let url = try repo.worktreeURL(forRelativePath: path)
                index.entries[path] = try Index.entry(forFileAt: url, oid: e.oid, mode: e.mode)
            }
            try repo.saveIndex(index)

            let oldHEAD = try repo.refs.headOID(objects: repo.objects)
            if isBranch {
                try repo.refs.setHEAD(ref: "refs/heads/\(target)")
            } else {
                try repo.refs.setHEAD(oid: targetOID)
            }
            try repo.appendReflog(refName: "HEAD", old: oldHEAD, new: targetOID,
                                  message: "checkout: moving to \(target)")
            // post-checkout hook.
            _ = try StagingOps(repo: repo).runHook(.postCheckout, input: "\(oldHEAD?.hex ?? "") \(targetOID.hex)\n")
        }
    }

    /// `spaces reset --soft|--mixed|--hard <rev>`.
    public enum ResetMode { case soft, mixed, hard }

    public func reset(to rev: String, mode: ResetMode) throws {
        try repo.performTransaction(steps: ["reset:\(mode)@\(rev)"]) {
            let oid = try repo.resolveRevision(rev)
            let oldHEAD = try repo.refs.headOID(objects: repo.objects)
            let commit = try repo.commitObject(oid)

            // Safety checkpoint: snapshot before hard reset.
            if mode == .hard {
                _ = try SnapshotOps(repo: repo).create(
                    message: "pre-reset checkpoint", kind: .preOperation, operation: "reset --hard")
            }

            switch mode {
            case .soft:
                // Move HEAD only; index and worktree untouched.
                if let sym = try repo.refs.symbolicHEAD() {
                    _ = try repo.refs.updateRef(sym, to: oid)
                } else {
                    try repo.refs.setHEAD(oid: oid)
                }
            case .mixed:
                // Move HEAD; reset index to target tree; worktree untouched.
                if let sym = try repo.refs.symbolicHEAD() {
                    _ = try repo.refs.updateRef(sym, to: oid)
                } else {
                    try repo.refs.setHEAD(oid: oid)
                }
                let flat = try TreeBuilder.flattenTree(repo: repo, treeOID: commit.tree)
                var index = Index()
                for (path, e) in flat {
                    let url = try repo.worktreeURL(forRelativePath: path)
                    if FileManager.default.fileExists(atPath: url.path) {
                        index.entries[path] = try Index.entry(
                            fileAt: url, matchingOID: e.oid, mode: e.mode,
                            objects: repo.objects)
                    } else {
                        index.entries[path] = IndexEntry(oid: e.oid, mode: e.mode, size: 0,
                                                         mtime: 0, ctime: 0, device: 0, inode: 0)
                    }
                }
                try repo.saveIndex(index)
            case .hard:
                // Move HEAD; index and worktree = target tree.
                if let sym = try repo.refs.symbolicHEAD() {
                    _ = try repo.refs.updateRef(sym, to: oid)
                } else {
                    try repo.refs.setHEAD(oid: oid)
                }
                _ = try TreeBuilder.checkout(repo: repo, treeOID: commit.tree)
                let flat = try TreeBuilder.flattenTree(repo: repo, treeOID: commit.tree)
                var index = Index()
                for (path, e) in flat {
                    let url = try repo.worktreeURL(forRelativePath: path)
                    index.entries[path] = try Index.entry(forFileAt: url, oid: e.oid, mode: e.mode)
                }
                try repo.saveIndex(index)
            }
            try repo.appendReflog(refName: "HEAD", old: oldHEAD, new: oid,
                                  message: "reset \(mode) to \(rev)")
        }
    }

    /// `spaces reflog [ref]`.
    public func reflog(refName: String = "HEAD", limit: Int = 50) throws -> [ReflogEntry] {
        try repo.readReflog(refName: refName, limit: limit)
    }

    /// `spaces graph` — commit graph data for rendering.
    public struct GraphNode: Sendable {
        public var oid: ObjectID
        public var parents: [ObjectID]
        public var lane: Int
        public var refs: [String]
        public var summary: String
        public var timestamp: Int64
    }

    public func graph(limit: Int = 200, all: Bool = false) throws -> [GraphNode] {
        let commits = try HistoryOps(repo: repo).log(limit: limit, all: all)
        // Assign lanes oldest→newest so parents are colored before children.
        var laneOf: [ObjectID: Int] = [:]
        var usedLanes = Set<Int>()
        var nodes: [GraphNode] = []
        for c in commits.reversed() {
            var lane: Int
            if let fp = c.parents.first, let l = laneOf[fp] {
                lane = l
            } else {
                lane = 0
                while usedLanes.contains(lane) { lane += 1 }
            }
            laneOf[c.oid] = lane
            usedLanes.insert(lane)
            nodes.append(GraphNode(oid: c.oid, parents: c.parents, lane: lane,
                                   refs: c.refs, summary: c.summary, timestamp: c.timestamp))
        }
        return nodes.reversed()
    }

    /// `spaces branch recovery` — list archived (recoverable-deleted) branches.
    public func archivedBranches() throws -> [Ref] {
        try repo.refs.allRefs().filter { $0.name.hasPrefix("refs/archive/branches/") }
    }

    /// Restores an archived branch to refs/heads/.
    public func restoreArchived(_ archiveName: String, as name: String? = nil) throws { return try repo.withLock {
        guard let ref = try repo.refs.allRefs().first(where: { $0.name == archiveName || $0.name.hasSuffix("/\(archiveName)") }) else {
            throw SpacesError.refNotFound(archiveName)
        }
        let target = name ?? String(ref.name.split(separator: "/").last ?? "").components(separatedBy: "-").dropLast().joined(separator: "-")
        _ = try repo.refs.updateRef("refs/heads/\(target)", to: ref.oid)
        }
    }

    private func isAncestor(_ ancestor: ObjectID, of descendant: ObjectID) throws -> Bool {
        // BFS from descendant.
        var visited = Set<ObjectID>()
        var queue = [descendant]
        while !queue.isEmpty {
            let oid = queue.removeFirst()
            if oid == ancestor { return true }
            guard visited.insert(oid).inserted else { continue }
            queue.append(contentsOf: try repo.commitObject(oid).parents)
        }
        return false
    }
}
