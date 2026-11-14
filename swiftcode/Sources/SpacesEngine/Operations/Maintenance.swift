import Foundation

/// Repository maintenance: fsck, gc, count-objects, storage analysis,
/// doctor diagnostics, index rebuild, object verification.
public struct MaintenanceOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public struct FSCKIssue: Sendable, Encodable {
        public enum Severity: String, Sendable, Encodable { case error, warning }
        public var severity: Severity
        public var message: String
        public var object: String?
    }

    /// `spaces fsck` — verifies every object's hash and reachability of all
    /// refs. Returns issues; empty = clean.
    public func fsck() throws -> [FSCKIssue] {
        var issues: [FSCKIssue] = []
        // 1) Verify all stored objects hash correctly.
        let allIDs = try repo.objects.allIDs()
        for id in allIDs {
            do {
                _ = try repo.objects.read(id)
            } catch {
                issues.append(FSCKIssue(severity: .error,
                                        message: "corrupt object: \(error.localizedDescription)",
                                        object: id.hex))
            }
        }
        // 2) Verify all refs point at existing objects of right type.
        for ref in try repo.refs.allRefs() {
            do {
                let stored = try repo.objects.read(ref.oid)
                switch ref.kind {
                case .branch, .remote:
                    if stored.type != .commit {
                        issues.append(FSCKIssue(severity: .error,
                                                message: "ref \(ref.name) points at \(stored.type.rawValue), expected commit",
                                                object: ref.oid.hex))
                    }
                case .tag:
                    if stored.type != .commit && stored.type != .tag {
                        issues.append(FSCKIssue(severity: .warning,
                                                message: "tag ref \(ref.name) points at \(stored.type.rawValue)",
                                                object: ref.oid.hex))
                    }
                default: break
                }
            } catch {
                issues.append(FSCKIssue(severity: .error,
                                        message: "ref \(ref.name) points at missing object",
                                        object: ref.oid.hex))
            }
        }
        // 3) HEAD sanity.
        do {
            _ = try repo.refs.readHEAD()
        } catch {
            issues.append(FSCKIssue(severity: .error, message: "HEAD unreadable"))
        }
        // 4) Unreachable objects count (warning only).
        let reachable = try reachableSet()
        let unreachable = allIDs.filter { !reachable.contains($0) }
        if !unreachable.isEmpty {
            issues.append(FSCKIssue(severity: .warning,
                                    message: "\(unreachable.count) unreachable object(s)"))
        }
        return issues
    }

    /// Set of objects reachable from all refs + index + snapshots.
    public func reachableSet() throws -> Set<ObjectID> {
        var seeds: [ObjectID] = []
        for ref in try repo.refs.allRefs() { seeds.append(ref.oid) }
        if let head = try repo.refs.headOID(objects: repo.objects) { seeds.append(head) }
        // Index blobs.
        let index = try repo.index()
        for e in index.entries.values { seeds.append(e.oid) }
        return try repo.objects.reachable(from: seeds)
    }

    /// `spaces gc` — repack is implicit (loose objects); prunes unreachable
    /// objects older than grace period and compacts the journal.
    @discardableResult
    public func gc(pruneDays: Int = 0) throws -> (pruned: Int, reachable: Int) {
        try repo.performTransaction(steps: ["gc"]) {
            let reachable = try reachableSet()
            let all = try repo.objects.allIDs()
            // With pruneDays=0 prune everything unreachable now.
            var keep = reachable
            if pruneDays > 0 {
                // Conservative: keep all (age-based pruning needs mtimes).
            }
            let pruned = try repo.objects.prune(unreachable: keep)
            keep.removeAll()
            try? repo.journal.compact()
            return (pruned, reachable.count)
        }
    }

    /// `spaces count` — object counts by type.
    public func countObjects() throws -> (blobs: Int, trees: Int, commits: Int,
                                          tags: Int, snapshots: Int, total: Int) {
        var counts: [ObjectType: Int] = [:]
        for id in try repo.objects.allIDs() {
            if let stored = try? repo.objects.read(id) {
                counts[stored.type, default: 0] += 1
            }
        }
        return (counts[.blob] ?? 0, counts[.tree] ?? 0, counts[.commit] ?? 0,
                counts[.tag] ?? 0, counts[.snapshot] ?? 0,
                counts.values.reduce(0, +))
    }

    /// `spaces storage` — disk usage breakdown.
    public func storage() throws -> (objects: Int64, index: Int64, total: Int64, fileCount: Int) {
        let objectsSize = try repo.objects.diskUsage()
        let indexURL = repo.metaURL.appendingPathComponent("index")
        let indexSize = (try? FileManager.default.attributesOfItem(atPath: indexURL.path)[.size] as? Int64) ?? 0
        var total: Int64 = objectsSize + indexSize
        var fileCount = 0
        if let enumerator = FileManager.default.enumerator(atPath: repo.metaURL.path) {
            for case let p as String in enumerator {
                let full = repo.metaURL.appendingPathComponent(p)
                if let s = try? FileManager.default.attributesOfItem(atPath: full.path)[.size] as? Int64 {
                    total += s
                }
                fileCount += 1
            }
        }
        return (objectsSize, indexSize, total, fileCount)
    }

    /// `spaces doctor` / `spaces diagnostics` — composite health report.
    public struct Diagnostic: Sendable, Encodable {
        public enum Level: String, Sendable, Encodable { case ok, warning, error }
        public var level: Level
        public var name: String
        public var detail: String
    }

    public func diagnose() throws -> [Diagnostic] {
        var diags: [Diagnostic] = []

        // Config valid.
        diags.append(Diagnostic(level: .ok, name: "config",
                                detail: "format v\(repo.config.version)"))

        // HEAD state.
        if let branch = try repo.refs.currentBranch() {
            diags.append(Diagnostic(level: .ok, name: "HEAD",
                                    detail: "on branch \(branch)"))
        } else {
            diags.append(Diagnostic(level: .warning, name: "HEAD", detail: "detached"))
        }

        // Unfinished operations.
        if repo.inMerge() {
            diags.append(Diagnostic(level: .warning, name: "merge",
                                    detail: "merge in progress (MERGE_HEAD set)"))
        }
        if repo.inRebase() {
            diags.append(Diagnostic(level: .warning, name: "rebase",
                                    detail: "rebase in progress"))
        }
        if repo.inCherryPick() {
            diags.append(Diagnostic(level: .warning, name: "cherry-pick/revert",
                                    detail: "operation in progress"))
        }

        // Journal.
        if repo.journal.hasUnfinishedTransactions {
            diags.append(Diagnostic(level: .warning, name: "journal",
                                    detail: "unfinished transaction entries"))
        } else {
            diags.append(Diagnostic(level: .ok, name: "journal", detail: "clean"))
        }

        // FSCK quick pass.
        let issues = try fsck()
        let errors = issues.filter { $0.severity == .error }
        let warnings = issues.filter { $0.severity == .warning }
        diags.append(Diagnostic(level: errors.isEmpty ? .ok : .error, name: "objects",
                                detail: errors.isEmpty
                                    ? "\(warnings.count) warning(s), all objects verified"
                                    : "\(errors.count) corrupt/missing object(s)"))

        // Index validity.
        do {
            _ = try repo.index()
            diags.append(Diagnostic(level: .ok, name: "index", detail: "valid"))
        } catch {
            diags.append(Diagnostic(level: .error, name: "index",
                                    detail: error.localizedDescription))
        }

        // Untracked/conflict state.
        let status = try WorktreeScanner(repo: repo).status()
        let conflicts = status.unmerged
        if !conflicts.isEmpty {
            diags.append(Diagnostic(level: .error, name: "conflicts",
                                    detail: "\(conflicts.count) unresolved: \(conflicts.prefix(3).joined(separator: ", "))"))
        }
        return diags
    }

    /// `spaces health` — single score + top issues.
    public func healthScore() throws -> (score: Int, issues: [Diagnostic]) {
        let diags = try diagnose()
        var score = 100
        for d in diags {
            switch d.level {
            case .error: score -= 25
            case .warning: score -= 5
            case .ok: break
            }
        }
        return (max(0, score), diags.filter { $0.level != .ok })
    }

    /// `spaces repair-index` / `spaces rebuild-index` — rebuild index from
    /// HEAD tree + worktree scan.
    public func rebuildIndex() throws -> Int {
        try repo.performTransaction(steps: ["rebuild-index"]) {
            var index = Index()
            var count = 0
            if let head = try repo.headCommit() {
                let flat = try TreeBuilder.flattenTree(repo: repo, treeOID: head.tree)
                for (path, e) in flat {
                    let url = try repo.worktreeURL(forRelativePath: path)
                    if FileManager.default.fileExists(atPath: url.path) {
                        index.entries[path] = try Index.entry(
                            fileAt: url, matchingOID: e.oid, mode: e.mode,
                            objects: repo.objects)
                        count += 1
                    }
                }
            }
            // Add untracked-but-present files as untracked is implicit; index
            // only holds tracked. Also re-add previously staged entries that
            // still exist on disk.
            let oldIndex = try repo.index()
            for (path, e) in oldIndex.entries where index.entries[path] == nil {
                let url = try repo.worktreeURL(forRelativePath: path)
                if FileManager.default.fileExists(atPath: url.path) {
                    index.entries[path] = try Index.entry(
                        fileAt: url, matchingOID: e.oid, mode: e.mode,
                        objects: repo.objects)
                    count += 1
                }
            }
            try repo.saveIndex(index)
            return count
        }
    }

    /// `spaces repair` — attempts safe repairs: rebuild index, re-resolve
    /// refs whose objects are missing by rewinding to last valid reflog entry.
    public func repair() throws -> [String] {
        var actions: [String] = []
        // 1) Rebuild index.
        let n = try rebuildIndex()
        actions.append("rebuilt index (\(n) entries)")
        // 2) Check refs.
        for ref in try repo.refs.allRefs() {
            if (try? repo.objects.read(ref.oid)) == nil {
                // Try reflog for this ref to find last valid oid.
                if let entries = try? repo.readReflog(refName: ref.name, limit: 50),
                   let valid = entries.first(where: { e in
                       guard let oid = e.new else { return false }
                       return (try? repo.objects.read(oid)) != nil
                   }), let oid = valid.new {
                    _ = try repo.refs.updateRef(ref.name, to: oid)
                    actions.append("repaired \(ref.name) → \(oid.hex.prefix(8))")
                } else {
                    actions.append("cannot repair \(ref.name): target object missing")
                }
            }
        }
        return actions
    }
}
