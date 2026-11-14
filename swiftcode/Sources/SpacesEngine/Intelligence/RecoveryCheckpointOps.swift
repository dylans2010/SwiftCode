import Foundation

public struct RecoveryCheckpointOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public struct CheckpointInfo: Codable, Sendable {
        public var oid: ObjectID
        public var operation: String
        public var message: String
        public var timestamp: Int64
    }

    private struct CheckpointIndexFile: Codable {
        var checkpoints: [CheckpointInfo]
    }

    private var indexURL: URL {
        repo.metaURL.appendingPathComponent("checkpoints/index.json")
    }

    private func loadIndex() throws -> [CheckpointInfo] {
        let stored: CheckpointIndexFile? = try SpacesIntelligenceStore.readJSON(
            CheckpointIndexFile.self, from: indexURL)
        return stored?.checkpoints ?? []
    }

    private func saveIndex(_ checkpoints: [CheckpointInfo]) throws {
        try SpacesIntelligenceStore.writeJSON(
            CheckpointIndexFile(checkpoints: checkpoints), to: indexURL)
    }

    @discardableResult
    public func createCheckpointBefore(operation: String) throws -> ObjectID {
        let trimmed = operation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SpacesError.invalidArgument("checkpoint operation must not be empty")
        }
        let oid = try SnapshotOps(repo: repo).create(
            message: "checkpoint before \(trimmed)",
            kind: .preOperation, operation: trimmed)
        let record = CheckpointInfo(
            oid: oid, operation: trimmed,
            message: "checkpoint before \(trimmed)",
            timestamp: Int64(Date().timeIntervalSince1970))
        try repo.withLock {
            var checkpoints = try loadIndex()
            checkpoints.removeAll { $0.oid == oid }
            checkpoints.append(record)
            try saveIndex(checkpoints)
        }
        return oid
    }

    public func listCheckpoints() throws -> [CheckpointInfo] {
        try loadIndex().sorted { $0.timestamp > $1.timestamp }
    }

    public func restoreCheckpoint(_ rev: String) throws {
        let oid = try repo.resolveRevision(rev)
        let known = try loadIndex().contains { $0.oid == oid }
        guard known else { throw SpacesError.refNotFound(rev) }
        try SnapshotOps(repo: repo).restore(rev)
    }
}
