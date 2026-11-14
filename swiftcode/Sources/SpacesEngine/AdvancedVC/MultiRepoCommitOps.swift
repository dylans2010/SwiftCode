import Foundation

enum AdvancedVCStore {
    static func writeJSON<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        let data = try encoder.encode(value)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let temp = url.appendingPathExtension("tmp-\(UUID().uuidString)")
        try data.write(to: temp, options: .atomic)
        _ = try? FileManager.default.removeItem(at: url)
        try FileManager.default.moveItem(at: temp, to: url)
    }

    static func readJSON<T: Decodable>(_ type: T.Type, from url: URL) throws -> T? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
    }

    static func appendJSONLine<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        var line = try encoder.encode(value)
        line.append(0x0a)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: line)
    }

    static func readJSONLines<T: Decodable>(_ type: T.Type, from url: URL) -> [T] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return text.components(separatedBy: "\n").filter { !$0.isEmpty }.compactMap {
            try? JSONDecoder().decode(T.self, from: Data($0.utf8))
        }
    }

    static func requireNameComponent(_ name: String) throws {
        guard !name.isEmpty, !name.contains("/"), !name.contains(".."),
              !name.contains(" "), !name.hasPrefix(".") else {
            throw SpacesError.invalidArgument("invalid name: \(name)")
        }
        guard name.allSatisfy({ !$0.isNewline }) else {
            throw SpacesError.invalidArgument("invalid name: \(name)")
        }
    }

    static func writeText(_ text: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let temp = url.appendingPathExtension("tmp-\(UUID().uuidString)")
        try Data(text.utf8).write(to: temp, options: .atomic)
        _ = try? FileManager.default.removeItem(at: url)
        try FileManager.default.moveItem(at: temp, to: url)
    }

    static func now() -> Int64 {
        Int64(Date().timeIntervalSince1970)
    }
}

public struct MultiRepoCommitOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public struct RepoOutcome: Sendable, Codable {
        public var repoPath: String
        public var committed: ObjectID?
        public var skipped: Bool
        public var error: String?
    }

    public struct MultiRepoCommitResult: Sendable, Codable {
        public var tx: String
        public var bestEffort: Bool
        public var message: String
        public var results: [RepoOutcome]
        public var committedCount: Int {
            results.filter { $0.committed != nil }.count
        }
    }

    public struct RecoveryEntry: Sendable, Codable {
        public var repoPath: String
        public var committed: ObjectID?
        public var state: String
        public var error: String?
    }

    public struct MultiRepoRecoveryReport: Sendable, Codable {
        public var tx: String
        public var status: String
        public var entries: [RecoveryEntry]
    }

    struct TxRecord: Codable {
        var tx: String
        var message: String
        var status: String
        var repos: [String]
        var outcomes: [RepoOutcome]
        var created: Int64
    }

    private func journalURL(for target: Repository, tx: String) -> URL {
        target.metaURL.appendingPathComponent("multirepo").appendingPathComponent("\(tx).json")
    }

    @discardableResult
    public func multiRepoCommit(repos: [URL], message: String, allowEmpty: Bool = false) throws -> MultiRepoCommitResult {
        guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SpacesError.invalidArgument("commit message must not be empty")
        }
        guard !repos.isEmpty else {
            throw SpacesError.invalidArgument("at least one repository is required")
        }
        let tx = UUID().uuidString
        var outcomes: [RepoOutcome] = []
        var opened: [Repository] = []
        for url in repos {
            let path = url.standardizedFileURL.path
            do {
                let target = try Repository.open(at: url)
                opened.append(target)
                try target.journal.begin(tx: tx, steps: ["multirepo-commit"])
                let api = SpacesAPI(repo: target)
                let staged = try api.status().staged
                if staged.isEmpty && !allowEmpty {
                    outcomes.append(RepoOutcome(repoPath: path, committed: nil, skipped: true, error: "nothing staged"))
                } else {
                    let result = try api.commit(message: message)
                    outcomes.append(RepoOutcome(repoPath: path, committed: result.oid, skipped: false, error: nil))
                    try target.journal.finish(tx: tx, committed: true)
                }
            } catch {
                outcomes.append(RepoOutcome(repoPath: path, committed: nil, skipped: false, error: "\(error)"))
            }
            let partial = outcomes.contains { $0.error != nil || $0.skipped }
            let record = TxRecord(tx: tx, message: message, status: partial ? "partial" : "committed",
                                  repos: repos.map { $0.standardizedFileURL.path },
                                  outcomes: outcomes, created: AdvancedVCStore.now())
            for target in opened {
                try? AdvancedVCStore.writeJSON(record, to: journalURL(for: target, tx: tx))
            }
            if !opened.contains(where: { $0.worktreeURL == repo.worktreeURL }) {
                try? AdvancedVCStore.writeJSON(record, to: journalURL(for: repo, tx: tx))
            }
        }
        let partial = outcomes.contains { $0.error != nil || $0.skipped }
        let record = TxRecord(tx: tx, message: message, status: partial ? "partial" : "committed",
                              repos: repos.map { $0.standardizedFileURL.path },
                              outcomes: outcomes, created: AdvancedVCStore.now())
        for target in opened {
            try? AdvancedVCStore.writeJSON(record, to: journalURL(for: target, tx: tx))
        }
        try AdvancedVCStore.writeJSON(record, to: journalURL(for: repo, tx: tx))
        return MultiRepoCommitResult(tx: tx, bestEffort: true, message: message, results: outcomes)
    }

    public func multiRepoRecover(tx: String) throws -> MultiRepoRecoveryReport {
        guard let record: TxRecord = try AdvancedVCStore.readJSON(TxRecord.self, from: journalURL(for: repo, tx: tx)) else {
            throw SpacesError.invalidArgument("no multi-repo transaction \(tx)")
        }
        var entries: [RecoveryEntry] = []
        for path in record.repos {
            let recorded = record.outcomes.first { $0.repoPath == path }
            do {
                let target = try Repository.open(at: URL(fileURLWithPath: path))
                if let oid = recorded?.committed {
                    let history = try HistoryOps(repo: target).walk(limit: 10000)
                    let state = history.contains { $0.oid == oid } ? "committed" : "unknown"
                    entries.append(RecoveryEntry(repoPath: path, committed: oid, state: state, error: nil))
                } else {
                    entries.append(RecoveryEntry(repoPath: path, committed: nil, state: "not-committed", error: recorded?.error))
                }
            } catch {
                entries.append(RecoveryEntry(repoPath: path, committed: recorded?.committed, state: "unknown", error: "\(error)"))
            }
        }
        let status: String
        if entries.allSatisfy({ $0.state == "committed" }) {
            status = "committed"
        } else if entries.allSatisfy({ $0.state == "not-committed" }) {
            status = "not-committed"
        } else {
            status = "partial"
        }
        return MultiRepoRecoveryReport(tx: tx, status: status, entries: entries)
    }
}
