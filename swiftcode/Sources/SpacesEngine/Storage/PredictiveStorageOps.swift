import Foundation

public struct PredictiveStorageOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public struct StorageSample: Codable, Sendable {
        public var timestamp: Int64
        public var objectCount: Int
        public var bytes: Int64
    }

    public struct GrowthEstimate: Sendable, Codable {
        public var samples: [StorageSample]
        public var dailyGrowthBytes: Double
        public var projectedBytesAt30Days: Int64?
        public var recommendation: String
        public var method: String
    }

    @discardableResult
    public func recordStorageSample() throws -> StorageSample {
        let storage = try MaintenanceOps(repo: repo).storage()
        let counts = try MaintenanceOps(repo: repo).countObjects()
        let sample = StorageSample(timestamp: Int64(Date().timeIntervalSince1970),
                                   objectCount: counts.total, bytes: storage.total)
        let data = try JSONEncoder().encode(sample)
        guard var line = String(data: data, encoding: .utf8) else {
            throw SpacesError.ioError("cannot encode storage sample")
        }
        line += "\n"
        try StorageFileIO.appendLine(repo: repo, name: "growth.jsonl", line: line)
        return sample
    }

    public func growthEstimate() throws -> GrowthEstimate {
        let method = "Linear projection fitted to measured storage samples; a projection, not a forecast."
        let samples = try readSamples()
        guard samples.count >= 2 else {
            return GrowthEstimate(samples: samples, dailyGrowthBytes: 0, projectedBytesAt30Days: nil,
                                  recommendation: "Collect at least two storage samples over time before projecting growth.",
                                  method: method)
        }
        let first = samples.first ?? samples[0]
        let last = samples.last ?? samples[0]
        let span = Double(last.timestamp - first.timestamp)
        guard span > 0 else {
            return GrowthEstimate(samples: samples, dailyGrowthBytes: 0, projectedBytesAt30Days: nil,
                                  recommendation: "Storage samples share one timestamp; collect samples over time before projecting growth.",
                                  method: method)
        }
        let count = Double(samples.count)
        var sumX = 0.0
        var sumY = 0.0
        var sumXY = 0.0
        var sumXX = 0.0
        for sample in samples {
            let x = Double(sample.timestamp - first.timestamp)
            let y = Double(sample.bytes)
            sumX += x
            sumY += y
            sumXY += x * y
            sumXX += x * x
        }
        let denominator = count * sumXX - sumX * sumX
        guard denominator != 0 else {
            return GrowthEstimate(samples: samples, dailyGrowthBytes: 0, projectedBytesAt30Days: nil,
                                  recommendation: "Storage samples do not support a projection; collect samples over time.",
                                  method: method)
        }
        let slope = (count * sumXY - sumX * sumY) / denominator
        let daily = slope * 86_400
        let projected = Int64(Double(last.bytes) + daily * 30)
        let recommendation: String
        if daily <= 0 {
            recommendation = "Measured storage is stable or shrinking (\(Int64(daily)) bytes/day); no maintenance action is indicated."
        } else if projected > 1_073_741_824 {
            recommendation = "Measured growth of \(Int64(daily)) bytes/day projects to \(projected) bytes in 30 days; consider running gc to prune unreachable objects."
        } else {
            recommendation = "Measured growth of \(Int64(daily)) bytes/day projects to \(projected) bytes in 30 days; no action needed yet."
        }
        return GrowthEstimate(samples: samples, dailyGrowthBytes: daily,
                              projectedBytesAt30Days: projected,
                              recommendation: recommendation, method: method)
    }

    private func readSamples() throws -> [StorageSample] {
        let lines = try StorageFileIO.readLines(repo: repo, name: "growth.jsonl")
        return lines.compactMap { line in
            try? JSONDecoder().decode(StorageSample.self, from: Data(line.utf8))
        }.sorted { $0.timestamp < $1.timestamp }
    }
}
