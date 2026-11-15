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
        public var source: String = "caller-supplied"
        public var command: String? = nil
        public var exitCode: Int32? = nil

        public init(commit: String, timestamp: Int64, result: BuildResult, durationMs: Int64,
                    failures: [String], source: String = "caller-supplied",
                    command: String? = nil, exitCode: Int32? = nil) {
            self.commit = commit
            self.timestamp = timestamp
            self.result = result
            self.durationMs = durationMs
            self.failures = failures
            self.source = source
            self.command = command
            self.exitCode = exitCode
        }
    }

    public func recordBuildResult(commit: ObjectID, result: BuildResult, durationMs: Int64, failures: [String]) throws {
        guard durationMs >= 0 else { throw SpacesError.invalidArgument("durationMs must not be negative") }
        let record = BuildRecord(commit: commit.hex, timestamp: Int64(Date().timeIntervalSince1970), result: result, durationMs: durationMs, failures: failures)
        try ToolingStorage.appendJSONLine(repo: repo, file: "builds.jsonl", value: record)
    }

    @discardableResult
    public func recordBuildResult(commit: ObjectID, command: String,
                                  timeoutSeconds: TimeInterval = 120) throws -> BuildRecord {
        let outcome = ToolingCommandRunner.run(command: command, worktree: repo.worktreeURL,
                                               timeoutSeconds: timeoutSeconds)
        let failures: [String]
        if outcome.timedOut {
            failures = ["command timed out after \(Int64(timeoutSeconds)) seconds"]
        } else if outcome.exitCode == 0 {
            failures = []
        } else {
            let lines = outcome.stderr.components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            let tail = Array(lines.suffix(20))
            failures = tail.isEmpty ? ["command exited with status \(outcome.exitCode)"] : tail
        }
        let result: BuildResult = outcome.exitCode == 0 && !outcome.timedOut ? .success : .failure
        let record = BuildRecord(commit: commit.hex,
                                 timestamp: Int64(Date().timeIntervalSince1970),
                                 result: result, durationMs: outcome.durationMs,
                                 failures: failures,
                                 source: "executed command: \(command)",
                                 command: command, exitCode: outcome.exitCode)
        try ToolingStorage.appendJSONLine(repo: repo, file: "builds.jsonl", value: record)
        return record
    }

    public func buildHistory(commit: ObjectID) throws -> [BuildRecord] {
        let records: [BuildRecord] = try ToolingStorage.readJSONLines(repo: repo, file: "builds.jsonl")
        return records.filter { $0.commit == commit.hex }
    }
}

enum ToolingCommandRunner {
    struct Outcome {
        var exitCode: Int32
        var stdout: String
        var stderr: String
        var durationMs: Int64
        var timedOut: Bool
    }

    static func run(command: String, worktree: URL, timeoutSeconds: TimeInterval) -> Outcome {
        let started = Date()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["sh", "-c", command]
        process.currentDirectoryURL = worktree
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        let outBox = ToolingDataBox()
        let errBox = ToolingDataBox()
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global().async {
            outBox.data = outPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        group.enter()
        DispatchQueue.global().async {
            errBox.data = errPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        do {
            try process.run()
        } catch {
            group.wait()
            return Outcome(exitCode: -1, stdout: "", stderr: "failed to launch: \(error.localizedDescription)",
                           durationMs: elapsedMs(since: started), timedOut: false)
        }
        var timedOut = false
        while process.isRunning {
            if Date().timeIntervalSince(started) > timeoutSeconds {
                timedOut = true
                process.terminate()
                break
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        process.waitUntilExit()
        group.wait()
        let stdout = String(data: outBox.data, encoding: .utf8) ?? ""
        let stderr = String(data: errBox.data, encoding: .utf8) ?? ""
        return Outcome(exitCode: process.terminationStatus, stdout: stdout, stderr: stderr,
                       durationMs: elapsedMs(since: started), timedOut: timedOut)
    }

    private static func elapsedMs(since started: Date) -> Int64 {
        Int64(ceil(Date().timeIntervalSince(started) * 1000))
    }
}

private final class ToolingDataBox: @unchecked Sendable {
    var data = Data()
}
