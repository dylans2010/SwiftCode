import Foundation

public struct RetentionPolicyOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public struct RetentionPolicy: Codable, Sendable {
        public var maxAgeDays: Int?
        public var maxCount: Int?
        public var maxBytes: Int64?
        public var pinned: [String]

        public init(maxAgeDays: Int? = nil, maxCount: Int? = nil, maxBytes: Int64? = nil,
                    pinned: [String] = []) {
            self.maxAgeDays = maxAgeDays
            self.maxCount = maxCount
            self.maxBytes = maxBytes
            self.pinned = pinned
        }
    }

    public func policy() throws -> RetentionPolicy {
        try StorageFileIO.load(repo: repo, name: "retention.json", defaultValue: RetentionPolicy())
    }

    public func setPolicy(_ policy: RetentionPolicy) throws {
        try repo.withLock {
            try StorageFileIO.save(repo: repo, name: "retention.json", value: policy)
        }
    }

    @discardableResult
    public func applyRetention() throws -> [ObjectID] {
        let policy = try policy()
        let now = Int64(Date().timeIntervalSince1970)
        let pinned = Set(policy.pinned)
        var remaining = try SnapshotOps(repo: repo).list().sorted { $0.timestamp < $1.timestamp }
        var deleted: [ObjectID] = []

        func delete(_ info: SnapshotOps.SnapshotInfo) throws {
            try SnapshotOps(repo: repo).delete(info.oid.hex)
            deleted.append(info.oid)
            remaining.removeAll { $0.oid == info.oid }
        }

        if let maxAgeDays = policy.maxAgeDays {
            let cutoff = now - Int64(maxAgeDays * 86_400)
            for info in remaining where info.timestamp < cutoff && !pinned.contains(info.oid.hex) {
                try delete(info)
            }
        }

        if let maxCount = policy.maxCount {
            while remaining.count > maxCount {
                guard let oldest = remaining.first(where: { !pinned.contains($0.oid.hex) }) else { break }
                try delete(oldest)
            }
        }

        if let maxBytes = policy.maxBytes {
            let report = try SnapshotDedupOps(repo: repo).deduplicationReport()
            var bytesByOID: [ObjectID: Int64] = [:]
            for entry in report.perSnapshot { bytesByOID[entry.oid] = entry.naiveBytes }
            var total = remaining.reduce(Int64(0)) { $0 + (bytesByOID[$1.oid] ?? 0) }
            while total > maxBytes {
                guard let oldest = remaining.first(where: { !pinned.contains($0.oid.hex) }) else { break }
                total -= bytesByOID[oldest.oid] ?? 0
                try delete(oldest)
            }
        }

        return deleted
    }
}
