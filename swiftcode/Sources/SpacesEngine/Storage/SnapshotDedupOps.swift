import Foundation

public struct SnapshotDedupOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public struct PerSnapshot: Sendable, Codable {
        public var oid: ObjectID
        public var message: String
        public var naiveBytes: Int64
    }

    public struct DeduplicationReport: Sendable, Codable {
        public var snapshotCount: Int
        public var naiveBytes: Int64
        public var sharedBytes: Int64
        public var sharedBlobCount: Int
        public var bytesSaved: Int64
        public var perSnapshot: [PerSnapshot]
    }

    public func deduplicationReport() throws -> DeduplicationReport {
        let snapshots = try SnapshotOps(repo: repo).list()
        var snapshotUseCount: [ObjectID: Int] = [:]
        var blobUseCount: [ObjectID: Int] = [:]
        var perSnapshot: [PerSnapshot] = []
        var naiveBytes: Int64 = 0
        for snapshot in snapshots {
            let reachable = try repo.objects.reachable(from: [snapshot.oid])
            var snapshotBytes: Int64 = 0
            for id in reachable {
                snapshotUseCount[id, default: 0] += 1
                snapshotBytes += storedSize(id)
                if let stored = try? repo.objects.read(id), stored.type == .blob {
                    blobUseCount[id, default: 0] += 1
                }
            }
            naiveBytes += snapshotBytes
            perSnapshot.append(PerSnapshot(oid: snapshot.oid, message: snapshot.message,
                                           naiveBytes: snapshotBytes))
        }
        var sharedBytes: Int64 = 0
        for id in snapshotUseCount.keys { sharedBytes += storedSize(id) }
        let sharedBlobCount = blobUseCount.values.filter { $0 >= 2 }.count
        return DeduplicationReport(snapshotCount: snapshots.count, naiveBytes: naiveBytes,
                                   sharedBytes: sharedBytes, sharedBlobCount: sharedBlobCount,
                                   bytesSaved: naiveBytes - sharedBytes, perSnapshot: perSnapshot)
    }

    private func storedSize(_ id: ObjectID) -> Int64 {
        (try? FileManager.default.attributesOfItem(atPath: repo.objects.url(for: id).path)[.size] as? Int64) ?? 0
    }
}
