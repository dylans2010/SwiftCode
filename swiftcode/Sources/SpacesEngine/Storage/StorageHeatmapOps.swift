import Foundation

public struct StorageHeatmapOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public struct Bucket: Sendable, Codable {
        public var label: String
        public var count: Int
        public var bytes: Int64
    }

    public struct StorageHeatmap: Sendable, Codable {
        public var byType: [Bucket]
        public var sizeBands: [Bucket]
        public var ageBands: [Bucket]
        public var reachableBytes: Int64
        public var unreachableBytes: Int64
        public var totalBytes: Int64
        public var totalObjects: Int
    }

    public func heatmap() throws -> StorageHeatmap {
        let ids = try repo.objects.allIDs()
        let reachable = try MaintenanceOps(repo: repo).reachableSet()
        let now = Date().timeIntervalSince1970
        let sizeLabels = ["under 1 KiB", "1 KiB to 16 KiB", "16 KiB to 256 KiB",
                          "256 KiB to 1 MiB", "over 1 MiB"]
        let ageLabels = ["under 1 day", "1 to 7 days", "7 to 30 days", "over 30 days"]
        var byType: [String: Bucket] = [:]
        var sizeBands: [String: Bucket] = [:]
        var ageBands: [String: Bucket] = [:]
        for label in sizeLabels { sizeBands[label] = Bucket(label: label, count: 0, bytes: 0) }
        for label in ageLabels { ageBands[label] = Bucket(label: label, count: 0, bytes: 0) }
        var reachableBytes: Int64 = 0
        var totalBytes: Int64 = 0
        for id in ids {
            let url = repo.objects.url(for: id)
            let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
            let size = attributes?[.size] as? Int64 ?? 0
            let mtime = (attributes?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? now
            let typeLabel = (try? repo.objects.read(id).type.rawValue) ?? "unknown"
            var typeBucket = byType[typeLabel] ?? Bucket(label: typeLabel, count: 0, bytes: 0)
            typeBucket.count += 1
            typeBucket.bytes += size
            byType[typeLabel] = typeBucket
            let sizeLabel: String
            switch size {
            case 0..<1_024: sizeLabel = sizeLabels[0]
            case 1_024..<16_384: sizeLabel = sizeLabels[1]
            case 16_384..<262_144: sizeLabel = sizeLabels[2]
            case 262_144..<1_048_576: sizeLabel = sizeLabels[3]
            default: sizeLabel = sizeLabels[4]
            }
            sizeBands[sizeLabel]?.count += 1
            sizeBands[sizeLabel]?.bytes += size
            let ageSeconds = now - mtime
            let ageLabel: String
            switch ageSeconds {
            case 0..<86_400: ageLabel = ageLabels[0]
            case 86_400..<604_800: ageLabel = ageLabels[1]
            case 604_800..<2_592_000: ageLabel = ageLabels[2]
            default: ageLabel = ageLabels[3]
            }
            ageBands[ageLabel]?.count += 1
            ageBands[ageLabel]?.bytes += size
            totalBytes += size
            if reachable.contains(id) { reachableBytes += size }
        }
        return StorageHeatmap(
            byType: byType.values.sorted { $0.label < $1.label },
            sizeBands: sizeLabels.map { sizeBands[$0] ?? Bucket(label: $0, count: 0, bytes: 0) },
            ageBands: ageLabels.map { ageBands[$0] ?? Bucket(label: $0, count: 0, bytes: 0) },
            reachableBytes: reachableBytes,
            unreachableBytes: totalBytes - reachableBytes,
            totalBytes: totalBytes,
            totalObjects: ids.count)
    }
}
