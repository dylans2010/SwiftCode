import Foundation

public struct BranchCheckpointOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public struct CheckpointInfo: Sendable, Codable {
        public var branch: String
        public var name: String
        public var oid: ObjectID
        public var refName: String
        public var timestamp: Int64
        public var message: String
    }

    private func refName(branch: String, name: String) -> String {
        "refs/branch-checkpoints/\(branch)/\(name)"
    }

    private func validateBranch(_ branch: String) throws -> ObjectID {
        guard let oid = try repo.refs.readRef("refs/heads/\(branch)") else {
            throw SpacesError.branchNotFound(branch)
        }
        return oid
    }

    @discardableResult
    public func create(branch: String, name: String) throws -> ObjectID {
        try AdvancedVCStore.requireNameComponent(name)
        _ = try validateBranch(branch)
        let ref = refName(branch: branch, name: name)
        if try repo.refs.readRef(ref) != nil {
            throw SpacesError.invalidArgument("checkpoint already exists: \(branch)/\(name)")
        }
        let oid = try SnapshotOps(repo: repo).create(
            message: "checkpoint \(branch)/\(name)", kind: .automatic,
            metadata: ["branch": branch, "checkpoint": name])
        return try repo.withLock {
            _ = try repo.refs.updateRef(ref, to: oid)
            try repo.appendReflog(refName: ref, old: nil, new: oid,
                                  message: "checkpoint created: \(branch)/\(name)")
            return oid
        }
    }

    public func list(branch: String) throws -> [CheckpointInfo] {
        _ = try validateBranch(branch)
        let prefix = "refs/branch-checkpoints/\(branch)/"
        var result: [CheckpointInfo] = []
        for ref in try repo.refs.allRefs() where ref.name.hasPrefix(prefix) {
            let name = String(ref.name.dropFirst(prefix.count))
            var timestamp: Int64 = 0
            var message = ""
            if let payload: SnapshotPayload = try? repo.objects.readPayload(ref.oid, expected: .snapshot) {
                timestamp = payload.timestamp
                message = payload.message
            }
            result.append(CheckpointInfo(branch: branch, name: name, oid: ref.oid,
                                         refName: ref.name, timestamp: timestamp, message: message))
        }
        return result.sorted { $0.name < $1.name }
    }

    public func restore(branch: String, name: String) throws {
        try AdvancedVCStore.requireNameComponent(name)
        _ = try validateBranch(branch)
        let ref = refName(branch: branch, name: name)
        guard let oid = try repo.refs.readRef(ref) else {
            throw SpacesError.refNotFound(ref)
        }
        try SnapshotOps(repo: repo).restore(oid.hex)
    }
}
