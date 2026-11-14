import Foundation

public struct TestProvenanceOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public struct TestRecord: Codable, Sendable, Equatable {
        public var commit: String
        public var worktreeHead: String
        public var suite: String
        public var passed: Int
        public var failed: Int
        public var timestamp: Int64

        public init(commit: String, worktreeHead: String, suite: String, passed: Int, failed: Int, timestamp: Int64) {
            self.commit = commit
            self.worktreeHead = worktreeHead
            self.suite = suite
            self.passed = passed
            self.failed = failed
            self.timestamp = timestamp
        }
    }

    public func recordTestResult(commit: ObjectID, suite: String, passed: Int, failed: Int) throws {
        guard !suite.isEmpty else { throw SpacesError.invalidArgument("suite must not be empty") }
        guard passed >= 0 && failed >= 0 else { throw SpacesError.invalidArgument("passed and failed must not be negative") }
        let headHex: String
        if let head = try? repo.refs.headOID(objects: repo.objects), let oid = head {
            headHex = oid.hex
        } else {
            headHex = ""
        }
        let record = TestRecord(commit: commit.hex, worktreeHead: headHex, suite: suite, passed: passed, failed: failed, timestamp: Int64(Date().timeIntervalSince1970))
        try ToolingStorage.appendJSONLine(repo: repo, file: "tests.jsonl", value: record)
    }

    public func testResultsFor(commit: ObjectID) throws -> [TestRecord] {
        let records: [TestRecord] = try ToolingStorage.readJSONLines(repo: repo, file: "tests.jsonl")
        return records.filter { $0.commit == commit.hex }
    }
}
