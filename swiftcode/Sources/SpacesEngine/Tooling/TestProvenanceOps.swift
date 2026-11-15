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
        public var source: String = "caller-supplied"
        public var command: String? = nil
        public var exitCode: Int32? = nil
        public var failures: [String] = []

        public init(commit: String, worktreeHead: String, suite: String, passed: Int, failed: Int,
                    timestamp: Int64, source: String = "caller-supplied",
                    command: String? = nil, exitCode: Int32? = nil,
                    failures: [String] = []) {
            self.commit = commit
            self.worktreeHead = worktreeHead
            self.suite = suite
            self.passed = passed
            self.failed = failed
            self.timestamp = timestamp
            self.source = source
            self.command = command
            self.exitCode = exitCode
            self.failures = failures
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

    @discardableResult
    public func recordTestResult(commit: ObjectID, suite: String, command: String,
                                 timeoutSeconds: TimeInterval = 120) throws -> TestRecord {
        guard !suite.isEmpty else { throw SpacesError.invalidArgument("suite must not be empty") }
        let outcome = ToolingCommandRunner.run(command: command, worktree: repo.worktreeURL,
                                               timeoutSeconds: timeoutSeconds)
        let combined = outcome.stdout + "\n" + outcome.stderr
        var passed = 0
        var failed = 0
        var parsed = false
        if let match = combined.firstMatch(of: #/Executed (\d+) tests, with (\d+) failures/#) {
            let executed = Int(String(match.1)) ?? 0
            failed = Int(String(match.2)) ?? 0
            passed = max(0, executed - failed)
            parsed = true
        } else if let match = combined.firstMatch(of: #/Test run with (\d+) tests passed/#) {
            passed = Int(String(match.1)) ?? 0
            failed = outcome.exitCode == 0 ? 0 : 1
            parsed = true
        }
        if !parsed {
            failed = outcome.exitCode == 0 && !outcome.timedOut ? 0 : 1
        }
        let failures: [String]
        if outcome.timedOut {
            failures = ["command timed out after \(Int64(timeoutSeconds)) seconds"]
        } else if outcome.exitCode == 0 {
            failures = []
        } else {
            let lines = combined.components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty && ($0.lowercased().contains("fail") || $0.lowercased().contains("error")) }
            let tail = Array(lines.suffix(20))
            failures = tail.isEmpty ? ["command exited with status \(outcome.exitCode)"] : tail
        }
        let headHex: String
        if let head = try? repo.refs.headOID(objects: repo.objects), let oid = head {
            headHex = oid.hex
        } else {
            headHex = ""
        }
        let source = parsed
            ? "executed command: \(command) (counts parsed from command output)"
            : "executed command: \(command) (counts derived from exit code only; counts could not be parsed from command output)"
        let record = TestRecord(commit: commit.hex, worktreeHead: headHex, suite: suite,
                                passed: passed, failed: failed,
                                timestamp: Int64(Date().timeIntervalSince1970),
                                source: source, command: command,
                                exitCode: outcome.exitCode, failures: failures)
        try ToolingStorage.appendJSONLine(repo: repo, file: "tests.jsonl", value: record)
        return record
    }

    public func testResultsFor(commit: ObjectID) throws -> [TestRecord] {
        let records: [TestRecord] = try ToolingStorage.readJSONLines(repo: repo, file: "tests.jsonl")
        return records.filter { $0.commit == commit.hex }
    }
}
