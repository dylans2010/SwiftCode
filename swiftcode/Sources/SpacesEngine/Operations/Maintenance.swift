import Foundation



public struct MaintenanceOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public struct FSCKIssue: Sendable, Encodable {
        public enum Severity: String, Sendable, Encodable { case error, warning }
        public var severity: Severity
        public var message: String
        public var object: String?
    }

    
    
    public func fsck() throws -> [FSCKIssue] {
        var issues: [FSCKIssue] = []
        
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
        
        do {
            _ = try repo.refs.readHEAD()
        } catch {
            issues.append(FSCKIssue(severity: .error, message: "HEAD unreadable"))
        }
        
        let reachable = try reachableSet()
        let unreachable = allIDs.filter { !reachable.contains($0) }
        if !unreachable.isEmpty {
            issues.append(FSCKIssue(severity: .warning,
                                    message: "\(unreachable.count) unreachable object(s)"))
        }
        return issues
    }

    
    public func reachableSet() throws -> Set<ObjectID> {
        var seeds: [ObjectID] = []
        for ref in try repo.refs.allRefs() { seeds.append(ref.oid) }
        if let head = try repo.refs.headOID(objects: repo.objects) { seeds.append(head) }
        
        let index = try repo.index()
        for e in index.entries.values { seeds.append(e.oid) }
        return try repo.objects.reachable(from: seeds)
    }

    
    
    @discardableResult
    public func gc(pruneDays: Int = 0) throws -> (pruned: Int, reachable: Int) {
        try repo.performTransaction(steps: ["gc"]) {
            let reachable = try reachableSet()
            let all = try repo.objects.allIDs()
            
            var keep = reachable
            if pruneDays > 0 {
                
            }
            let pruned = try repo.objects.prune(unreachable: keep)
            keep.removeAll()
            try? repo.journal.compact()
            return (pruned, reachable.count)
        }
    }

    public struct StorageBudgetReport: Sendable {
        public var pruned: Int
        public var reachable: Int
        public var totalBytes: Int64
        public var maxBytes: Int64?
        public var overBudgetBy: Int64
    }

    public func gcWithBudget() throws -> StorageBudgetReport {
        let result = try gc()
        let usage = try storage()
        let maxBytes = try RetentionPolicyOps(repo: repo).policy().maxBytes
        let over = maxBytes.map { max(Int64(0), usage.total - $0) } ?? 0
        return StorageBudgetReport(pruned: result.pruned, reachable: result.reachable,
                                   totalBytes: usage.total, maxBytes: maxBytes, overBudgetBy: over)
    }

    public struct DuplicateContentReport: Sendable {
        public var sharedBlobCount: Int
        public var sharedBytes: Int64
        public var bytesSaved: Int64
        public var unreachableBlobCount: Int
        public var unreachableBlobBytes: Int64
        public var snapshotCount: Int
    }

    public func duplicateContentReport() throws -> DuplicateContentReport {
        let dedup = try SnapshotDedupOps(repo: repo).deduplicationReport()
        let reachable = try reachableSet()
        var unreachableBlobs = 0
        var unreachableBytes: Int64 = 0
        for id in try repo.objects.allIDs() where !reachable.contains(id) {
            if let stored = try? repo.objects.read(id), stored.type == .blob {
                unreachableBlobs += 1
                unreachableBytes += Int64(stored.payload.count)
            }
        }
        return DuplicateContentReport(sharedBlobCount: dedup.sharedBlobCount,
                                      sharedBytes: dedup.sharedBytes,
                                      bytesSaved: dedup.bytesSaved,
                                      unreachableBlobCount: unreachableBlobs,
                                      unreachableBlobBytes: unreachableBytes,
                                      snapshotCount: dedup.snapshotCount)
    }

    public struct PerformanceDiagnostics: Sendable {
        public var statusMs: Int64
        public var logMs: Int64
        public var fsckMs: Int64
        public var storageMs: Int64
        public var timestamp: Int64
    }

    public func performanceDiagnostics() throws -> PerformanceDiagnostics {
        let api = SpacesAPI(repo: repo)
        var start = Date()
        _ = try api.status()
        let statusMs = Int64(ceil(Date().timeIntervalSince(start) * 1000))
        start = Date()
        _ = try api.log(limit: 100)
        let logMs = Int64(ceil(Date().timeIntervalSince(start) * 1000))
        start = Date()
        _ = try api.fsck()
        let fsckMs = Int64(ceil(Date().timeIntervalSince(start) * 1000))
        start = Date()
        _ = try api.storage()
        let storageMs = Int64(ceil(Date().timeIntervalSince(start) * 1000))
        return PerformanceDiagnostics(statusMs: statusMs, logMs: logMs, fsckMs: fsckMs,
                                      storageMs: storageMs,
                                      timestamp: Int64(Date().timeIntervalSince1970))
    }

    
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

    
    public struct Diagnostic: Sendable, Encodable {
        public enum Level: String, Sendable, Encodable { case ok, warning, error }
        public var level: Level
        public var name: String
        public var detail: String
    }

    public func diagnose() throws -> [Diagnostic] {
        var diags: [Diagnostic] = []

        
        diags.append(Diagnostic(level: .ok, name: "config",
                                detail: "format v\(repo.config.version)"))

        
        if let branch = try repo.refs.currentBranch() {
            diags.append(Diagnostic(level: .ok, name: "HEAD",
                                    detail: "on branch \(branch)"))
        } else {
            diags.append(Diagnostic(level: .warning, name: "HEAD", detail: "detached"))
        }

        
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

        
        if repo.journal.hasUnfinishedTransactions {
            diags.append(Diagnostic(level: .warning, name: "journal",
                                    detail: "unfinished transaction entries"))
        } else {
            diags.append(Diagnostic(level: .ok, name: "journal", detail: "clean"))
        }

        
        let issues = try fsck()
        let errors = issues.filter { $0.severity == .error }
        let warnings = issues.filter { $0.severity == .warning }
        diags.append(Diagnostic(level: errors.isEmpty ? .ok : .error, name: "objects",
                                detail: errors.isEmpty
                                    ? "\(warnings.count) warning(s), all objects verified"
                                    : "\(errors.count) corrupt/missing object(s)"))

        
        do {
            _ = try repo.index()
            diags.append(Diagnostic(level: .ok, name: "index", detail: "valid"))
        } catch {
            diags.append(Diagnostic(level: .error, name: "index",
                                    detail: error.localizedDescription))
        }

        
        let status = try WorktreeScanner(repo: repo).status()
        let conflicts = status.unmerged
        if !conflicts.isEmpty {
            diags.append(Diagnostic(level: .error, name: "conflicts",
                                    detail: "\(conflicts.count) unresolved: \(conflicts.prefix(3).joined(separator: ", "))"))
        }
        return diags
    }

    
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
            
            
            
            let oldIndex = (try? repo.index()) ?? Index()
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

    
    
    public func repair() throws -> [String] {
        var actions: [String] = []
        
        let n = try rebuildIndex()
        actions.append("rebuilt index (\(n) entries)")
        
        for ref in try repo.refs.allRefs() {
            if (try? repo.objects.read(ref.oid)) == nil {
                
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
