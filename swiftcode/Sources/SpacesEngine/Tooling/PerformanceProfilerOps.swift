import Foundation

public struct PerformanceProfilerOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public enum ProfileOperation: String, Codable, Sendable, CaseIterable {
        case status
        case log
        case fsck
        case storage
        case search
    }

    public struct ProfileSample: Codable, Sendable, Equatable {
        public var operation: String
        public var durationMs: Int64
        public var objectCount: Int
        public var bytes: Int64
        public var timestamp: Int64

        public init(operation: String, durationMs: Int64, objectCount: Int, bytes: Int64, timestamp: Int64) {
            self.operation = operation
            self.durationMs = durationMs
            self.objectCount = objectCount
            self.bytes = bytes
            self.timestamp = timestamp
        }
    }

    public struct ProfileSummary: Codable, Sendable, Equatable {
        public var operation: String
        public var samples: Int
        public var averageDurationMs: Double
        public var minDurationMs: Int64
        public var maxDurationMs: Int64
        public var totalBytes: Int64

        public init(operation: String, samples: Int, averageDurationMs: Double, minDurationMs: Int64, maxDurationMs: Int64, totalBytes: Int64) {
            self.operation = operation
            self.samples = samples
            self.averageDurationMs = averageDurationMs
            self.minDurationMs = minDurationMs
            self.maxDurationMs = maxDurationMs
            self.totalBytes = totalBytes
        }
    }

    public func profileOperation(_ operation: ProfileOperation) throws -> ProfileSample {
        let api = SpacesAPI(repo: repo)
        let started = Date()
        switch operation {
        case .status:
            _ = try api.status()
        case .log:
            _ = try api.log(limit: 100)
        case .fsck:
            _ = try api.fsck()
        case .storage:
            _ = try api.storage()
        case .search:
            _ = try api.search(SearchOps.Query(text: "a", limit: 50))
        }
        let durationMs = Int64(ceil(Date().timeIntervalSince(started) * 1000))
        let counts = try api.countObjects()
        let storage = try api.storage()
        let sample = ProfileSample(operation: operation.rawValue, durationMs: durationMs, objectCount: counts.total, bytes: storage.total, timestamp: Int64(Date().timeIntervalSince1970))
        try ToolingStorage.appendJSONLine(repo: repo, file: "profile.jsonl", value: sample)
        return sample
    }

    public func performanceProfile(limit: Int = 1000) throws -> [ProfileSummary] {
        guard limit > 0 else { throw SpacesError.invalidArgument("limit must be positive") }
        let all: [ProfileSample] = try ToolingStorage.readJSONLines(repo: repo, file: "profile.jsonl")
        let recent = Array(all.suffix(limit))
        var grouped: [String: [ProfileSample]] = [:]
        for sample in recent {
            grouped[sample.operation, default: []].append(sample)
        }
        return grouped.keys.sorted().map { operation in
            let samples = grouped[operation] ?? []
            let durations = samples.map { $0.durationMs }
            let average = durations.isEmpty ? 0 : Double(durations.reduce(0, +)) / Double(durations.count)
            return ProfileSummary(operation: operation, samples: samples.count, averageDurationMs: average, minDurationMs: durations.min() ?? 0, maxDurationMs: durations.max() ?? 0, totalBytes: samples.map { $0.bytes }.reduce(0, +))
        }
    }
}
