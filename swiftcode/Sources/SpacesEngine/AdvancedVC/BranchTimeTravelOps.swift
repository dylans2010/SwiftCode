import Foundation

public struct BranchTimeTravelOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public struct BranchState: Sendable, Codable {
        public var oid: ObjectID
        public var timestamp: Int64
        public var summary: String
        public var source: String
    }

    public func states(branch: String, limit: Int = 50) throws -> [BranchState] {
        guard try repo.refs.readRef("refs/heads/\(branch)") != nil else {
            throw SpacesError.branchNotFound(branch)
        }
        var byOID: [ObjectID: BranchState] = [:]
        let entries = try repo.readReflog(refName: "refs/heads/\(branch)", limit: limit)
        for entry in entries {
            guard let oid = entry.new else { continue }
            if byOID[oid] != nil { continue }
            let summary: String
            if let commit = try? repo.commitObject(oid) {
                summary = commit.summary
            } else {
                summary = entry.message
            }
            byOID[oid] = BranchState(oid: oid, timestamp: entry.timestamp,
                                     summary: summary, source: "reflog")
        }
        for snapshot in try SnapshotOps(repo: repo).list(limit: limit) {
            if byOID[snapshot.oid] == nil {
                byOID[snapshot.oid] = BranchState(oid: snapshot.oid, timestamp: snapshot.timestamp,
                                                  summary: snapshot.message, source: "snapshot")
            }
        }
        return byOID.values.sorted { $0.timestamp > $1.timestamp }.prefix(limit).map { $0 }
    }

    @discardableResult
    public func timeTravel(branch: String, to rev: String, force: Bool = false) throws -> ObjectID {
        guard let currentTip = try repo.refs.readRef("refs/heads/\(branch)") else {
            throw SpacesError.branchNotFound(branch)
        }
        let targetOID = try repo.resolveRevision(rev)
        let targetCommit = try repo.commitObject(targetOID)
        if !force {
            let status = try WorktreeScanner(repo: repo).status()
            let dirty = status.entries.filter { $0.isStaged || $0.isUnstaged }.map { $0.path }
            if !dirty.isEmpty {
                throw SpacesError.dirtyWorkingTree(dirty)
            }
        }
        return try repo.performTransaction(steps: ["time-travel:\(branch)@\(rev)"]) {
            let ident = repo.identity()
            let payload = CommitPayload(tree: targetCommit.tree, parents: [currentTip],
                                        author: ident, committer: ident,
                                        message: "time travel \(branch) to \(String(targetOID.hex.prefix(7)))",
                                        metadata: CommitMetadata(trailers: ["time-travel-from": targetOID.hex]))
            let newOID = try repo.objects.write(.commit, value: payload)
            let old = try repo.refs.updateRef("refs/heads/\(branch)", to: newOID)
            try repo.appendReflog(refName: "refs/heads/\(branch)", old: old, new: newOID,
                                  message: "time travel to \(String(targetOID.hex.prefix(7)))")
            if try repo.refs.currentBranch() == branch {
                _ = try TreeBuilder.checkout(repo: repo, treeOID: targetCommit.tree)
                let flat = try TreeBuilder.flattenTree(repo: repo, treeOID: targetCommit.tree)
                var index = Index()
                for (path, entry) in flat {
                    let url = try repo.worktreeURL(forRelativePath: path)
                    index.entries[path] = try Index.entry(forFileAt: url, oid: entry.oid, mode: entry.mode)
                }
                try repo.saveIndex(index)
            }
            return newOID
        }
    }
}
