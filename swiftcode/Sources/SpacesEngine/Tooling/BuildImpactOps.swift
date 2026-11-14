import Foundation

public struct BuildImpactOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public enum BuildResult: String, Codable, Sendable {
        case success
        case failure
    }

    public struct BuildRecord: Codable, Sendable, Equatable {
        public var commit: String
        public var timestamp: Int64
        public var result: BuildResult
        public var durationMs: Int64
        public var failures: [String]

        public init(commit: String, timestamp: Int64, result: BuildResult, durationMs: Int64, failures: [String]) {
            self.commit = commit
            self.timestamp = timestamp
            self.result = result
            self.durationMs = durationMs
            self.failures = failures
        }
    }

    public func recordBuildResult(commit: ObjectID, result: BuildResult, durationMs: Int64, failures: [String]) throws {
        guard durationMs >= 0 else { throw SpacesError.invalidArgument("durationMs must not be negative") }
        let record = BuildRecord(commit: commit.hex, timestamp: Int64(Date().timeIntervalSince1970), result: result, durationMs: durationMs, failures: failures)
        try ToolingStorage.appendJSONLine(repo: repo, file: "builds.jsonl", value: record)
    }

    public func buildHistory(commit: ObjectID) throws -> [BuildRecord] {
        let records: [BuildRecord] = try ToolingStorage.readJSONLines(repo: repo, file: "builds.jsonl")
        return records.filter { $0.commit == commit.hex }
    }
}
