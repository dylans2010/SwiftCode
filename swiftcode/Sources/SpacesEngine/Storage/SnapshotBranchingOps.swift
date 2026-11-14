import Foundation

public struct SnapshotBranchingOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    @discardableResult
    public func branchFromSnapshot(rev: String, name: String) throws -> ObjectID {
        try repo.performTransaction(steps: ["snapshot-branch:\(rev)"]) {
            let payload = try SnapshotOps(repo: repo).inspect(rev)
            let snapshotOID = try repo.resolveRevision(rev)
            let ident = repo.identity()
            let commit = CommitPayload(
                tree: payload.tree,
                parents: payload.parents,
                author: ident,
                committer: ident,
                message: "Branch \(name) from snapshot \(snapshotOID.hex.prefix(8))",
                metadata: CommitMetadata(trailers: ["Snapshot": snapshotOID.hex]))
            let commitOID = try repo.objects.write(.commit, value: commit)
            _ = try BranchOps(repo: repo).create(name, at: commitOID.hex)
            return commitOID
        }
    }

    public func checkoutSnapshot(rev: String) throws {
        try SnapshotOps(repo: repo).restore(rev)
    }
}
