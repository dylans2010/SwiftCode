import Foundation

/// Snapshot system: point-in-time captures of worktree+index stored as
/// snapshot objects under `refs/snapshots/`. Powers the timeline, recovery
/// points, and pre-operation checkpoints.
public struct SnapshotOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public enum Kind: String, Sendable {
        case manual, automatic, preOperation = "pre-operation", scheduled, workspace
    }

    public struct SnapshotInfo: Sendable, Encodable {
        public var oid: ObjectID
        public var refName: String
        public var message: String
        public var kind: String
        public var operation: String?
        public var timestamp: Int64
        public var author: String
    }

    /// Creates a snapshot of the current worktree (tracked files' worktree
    /// contents plus staged state). Does not require a clean tree.
    @discardableResult
    public func create(message: String, kind: Kind = .manual,
                       operation: String? = nil,
                       metadata: [String: String] = [:]) throws -> ObjectID {
        try repo.performTransaction(steps: ["snapshot"]) {
            // Hash every non-ignored worktree file into a flat listing.
            let scanner = WorktreeScanner(repo: repo)
            let files = try scanner.scan()
            var listing: [String: (oid: ObjectID, mode: FileMode)] = [:]
            for f in files {
                let (oid, mode) = try scanner.hashEntry(f)
                listing[f.relativePath] = (oid, mode)
            }
            let treeOID = try TreeBuilder.writeTree(entries: listing, objects: repo.objects)

            // Index tree.
            var indexListing: [String: (oid: ObjectID, mode: FileMode)] = [:]
            let index = try repo.index()
            for (p, e) in index.entries { indexListing[p] = (e.oid, e.mode) }
            let indexTree = try TreeBuilder.writeTree(entries: indexListing, objects: repo.objects)

            let ident = repo.identity()
            let parents = (try? repo.refs.headOID(objects: repo.objects)).map { [$0] } ?? []
            let payload = SnapshotPayload(tree: treeOID, indexTree: indexTree,
                                          parents: parents, author: ident,
                                          message: message, kind: kind.rawValue,
                                          operation: operation, metadata: metadata)
            let oid = try repo.objects.write(.snapshot, value: payload)

            // Ref name: refs/snapshots/<timestamp>-<slug>.
            let slug = message.lowercased()
                .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
                .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
            let stamp = Int64(Date().timeIntervalSince1970)
            let refName = "refs/snapshots/\(stamp)-\(String(oid.hex.prefix(8)))\(slug.isEmpty ? "" : "-" + String(slug.prefix(40)))"
            _ = try repo.refs.updateRef(refName, to: oid)
            try repo.appendReflog(refName: refName, old: nil, new: oid,
                                  message: "snapshot: \(message)")
            return oid
        }
    }

    public func list(limit: Int = 200) throws -> [SnapshotInfo] {
        var result: [SnapshotInfo] = []
        for ref in try repo.refs.allRefs() where ref.kind == .snapshot {
            guard let stored = try? repo.objects.read(ref.oid, expectedType: .snapshot),
                  let payload = try? JSONDecoder().decode(SnapshotPayload.self, from: stored.payload) else {
                continue
            }
            result.append(SnapshotInfo(oid: ref.oid, refName: ref.name,
                                       message: payload.message, kind: payload.kind,
                                       operation: payload.operation,
                                       timestamp: payload.timestamp,
                                       author: payload.author.name))
        }
        return result.sorted { $0.timestamp > $1.timestamp }.prefix(limit).map { $0 }
    }

    public func inspect(_ rev: String) throws -> SnapshotPayload {
        let oid = try repo.resolveRevision(rev)
        guard let stored = try? repo.objects.read(oid, expectedType: .snapshot),
              let payload = try? JSONDecoder().decode(SnapshotPayload.self, from: stored.payload) else {
            throw SpacesError.invalidArgument("not a snapshot: \(rev)")
        }
        return payload
    }

    /// Restores worktree (and optionally index) to a snapshot's state.
    /// Creates a pre-restore checkpoint first unless disabled.
    public func restore(_ rev: String, includeIndex: Bool = true,
                        checkpoint: Bool = true) throws {
        try repo.performTransaction(steps: ["snapshot-restore:\(rev)"]) {
            let payload = try inspect(rev)
            if checkpoint {
                _ = try create(message: "pre-restore checkpoint",
                               kind: .preOperation, operation: "snapshot restore")
            }
            // Materialize snapshot tree to worktree.
            _ = try TreeBuilder.checkout(repo: repo, treeOID: payload.tree)
            // Rebuild index.
            var index = Index()
            let flat = try TreeBuilder.flattenTree(repo: repo, treeOID: payload.tree)
            for (path, e) in flat {
                let url = try repo.worktreeURL(forRelativePath: path)
                index.entries[path] = try Index.entry(forFileAt: url, oid: e.oid, mode: e.mode)
            }
            if includeIndex, let indexTree = payload.indexTree {
                // Restore staged state: entries whose index oid differs from
                // worktree oid represent staged changes.
                let idxFlat = try TreeBuilder.flattenTree(repo: repo, treeOID: indexTree)
                for (path, e) in idxFlat {
                    if index.entries[path]?.oid != e.oid {
                        let url = try repo.worktreeURL(forRelativePath: path)
                        if FileManager.default.fileExists(atPath: url.path) {
                            index.entries[path] = try Index.entry(forFileAt: url, oid: e.oid, mode: e.mode)
                        }
                    }
                }
            }
            try repo.saveIndex(index)
        }
    }

    /// Deletes a snapshot (its ref; object remains until gc).
    public func delete(_ rev: String) throws { return try repo.withLock {
        let payload = try inspect(rev)
        _ = payload
        // Find ref pointing at it.
        let target = try repo.resolveRevision(rev)
        for ref in try repo.refs.allRefs() where ref.kind == .snapshot && ref.oid == target {
            try repo.refs.deleteRef(ref.name)
            return
        }
        throw SpacesError.refNotFound(rev)
        }
    }

    /// `spaces timeline` — unified view of snapshots + commits + reflog events.
    public struct TimelineEntry: Sendable {
        public enum Kind: String, Sendable { case snapshot, commit, reflog }
        public var kind: Kind
        public var timestamp: Int64
        public var oid: ObjectID?
        public var title: String
        public var detail: String
    }

    public func timeline(limit: Int = 100) throws -> [TimelineEntry] {
        var entries: [TimelineEntry] = []
        for s in try list(limit: limit) {
            entries.append(TimelineEntry(kind: .snapshot, timestamp: s.timestamp,
                                         oid: s.oid, title: s.message,
                                         detail: "snapshot (\(s.kind))"))
        }
        for c in try HistoryOps(repo: repo).log(limit: limit) {
            entries.append(TimelineEntry(kind: .commit, timestamp: c.timestamp,
                                         oid: c.oid, title: c.summary,
                                         detail: c.author.name))
        }
        for e in try repo.readReflog(limit: limit) {
            entries.append(TimelineEntry(kind: .reflog, timestamp: e.timestamp,
                                         oid: e.new, title: e.message,
                                         detail: e.ident))
        }
        return entries.sorted { $0.timestamp > $1.timestamp }.prefix(limit).map { $0 }
    }
}
