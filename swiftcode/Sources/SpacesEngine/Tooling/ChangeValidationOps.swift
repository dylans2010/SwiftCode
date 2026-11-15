import Foundation

public struct ChangeValidationOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public struct ValidationPlanEntry: Codable, Sendable, Equatable {
        public var component: String
        public var testSuite: String
        public var testSuiteExists: Bool

        public init(component: String, testSuite: String, testSuiteExists: Bool) {
            self.component = component
            self.testSuite = testSuite
            self.testSuiteExists = testSuiteExists
        }
    }

    public struct ValidationRunResult: Codable, Sendable, Equatable {
        public var rev: String
        public var suite: String
        public var status: String
        public var exitCode: Int32?
        public var durationMs: Int64
        public var note: String

        public init(rev: String, suite: String, status: String, exitCode: Int32? = nil,
                    durationMs: Int64, note: String) {
            self.rev = rev
            self.suite = suite
            self.status = status
            self.exitCode = exitCode
            self.durationMs = durationMs
            self.note = note
        }
    }

    @discardableResult
    public func runValidation(rev: String, timeoutSeconds: TimeInterval = 300) throws -> [ValidationRunResult] {
        let plan = try validationPlan(rev: rev)
        var results: [ValidationRunResult] = []
        for entry in plan {
            let result: ValidationRunResult
            if !entry.testSuiteExists {
                result = ValidationRunResult(rev: rev, suite: entry.testSuite, status: "skipped",
                                             durationMs: 0,
                                             note: "test suite not found in tree; skipped")
            } else {
                let outcome = ToolingCommandRunner.run(
                    command: "swift test --filter \(entry.testSuite)",
                    worktree: repo.worktreeURL, timeoutSeconds: timeoutSeconds)
                let status: String
                let note: String
                if outcome.timedOut {
                    status = "failed"
                    note = "command timed out after \(Int64(timeoutSeconds)) seconds"
                } else if outcome.exitCode == 0 {
                    status = "passed"
                    note = "swift test --filter \(entry.testSuite) exited 0"
                } else {
                    status = "failed"
                    note = "swift test --filter \(entry.testSuite) exited with status \(outcome.exitCode)"
                }
                result = ValidationRunResult(rev: rev, suite: entry.testSuite, status: status,
                                             exitCode: outcome.exitCode,
                                             durationMs: outcome.durationMs, note: note)
            }
            try ToolingStorage.appendJSONLine(repo: repo, file: "validation-runs.jsonl", value: result)
            results.append(result)
        }
        return results
    }

    public func validationRuns(rev: String) throws -> [ValidationRunResult] {
        let records: [ValidationRunResult] = try ToolingStorage.readJSONLines(
            repo: repo, file: "validation-runs.jsonl")
        return records.filter { $0.rev == rev }
    }

    public func affectedComponents(rev: String) throws -> [String] {
        let oid = try repo.resolveRevision(rev)
        let commit = try repo.commitObject(oid)
        var paths: [String] = []
        if let parent = commit.parents.first {
            let diffs = try DiffOps(repo: repo).commitDiff(parent.hex, rev)
            paths = diffs.map { $0.newPath }
        } else {
            let flat = try TreeBuilder.flattenTree(repo: repo, treeOID: commit.tree)
            paths = Array(flat.keys)
        }
        var components = Set<String>()
        for path in paths {
            if let component = component(for: path) {
                components.insert(component)
            }
        }
        return components.sorted()
    }

    public func validationPlan(rev: String) throws -> [ValidationPlanEntry] {
        let components = try affectedComponents(rev: rev)
        let flat = try ToolingStorage.flatTree(repo: repo, rev: rev)
        return components.map { component in
            let suite = component + "Tests"
            let exists = flat.keys.contains { key in
                key.hasPrefix("Tests/" + suite + "/") || key.contains("/Tests/" + suite + "/")
            }
            return ValidationPlanEntry(component: component, testSuite: suite, testSuiteExists: exists)
        }
    }

    public static func component(for path: String) -> String? {
        let segments = path.split(separator: "/").map(String.init)
        guard !segments.isEmpty else { return nil }
        if let sourcesIndex = segments.firstIndex(of: "Sources"), sourcesIndex + 1 < segments.count {
            return segments[sourcesIndex + 1]
        }
        if let testsIndex = segments.firstIndex(of: "Tests"), testsIndex + 1 < segments.count {
            let target = segments[testsIndex + 1]
            if target.hasSuffix("Tests") {
                return String(target.dropLast("Tests".count))
            }
            return target
        }
        return segments[0]
    }
}
