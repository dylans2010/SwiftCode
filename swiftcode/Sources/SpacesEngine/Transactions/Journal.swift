import Foundation

/// Append-only operation journal used for crash recovery. Every mutation that
/// spans multiple steps records its intent before performing it; on open,
/// `Repository.recoverIfNeeded()` finishes or rolls back incomplete entries.
///
/// Journal line format (JSON per line):
///   {"op":"begin","tx":"<uuid>","steps":[...],"time":...}
///   {"op":"step","tx":"<uuid>","index":n}
///   {"op":"commit","tx":"<uuid>"}
///   {"op":"abort","tx":"<uuid>"}
public final class Journal: @unchecked Sendable {
    public struct Entry: Codable, Sendable {
        public var op: String
        public var tx: String
        public var index: Int?
        public var steps: [String]?
        public var time: Int64
    }

    public let url: URL
    private let lock = NSLock()

    public init(metaURL: URL) {
        self.url = metaURL.appendingPathComponent("journal")
    }

    public var hasUnfinishedTransactions: Bool {
        guard let lines = try? readLines() else { return false }
        var open = Set<String>()
        for line in lines {
            guard let e = try? JSONDecoder().decode(Entry.self, from: Data(line.utf8)) else { continue }
            if e.op == "begin" { open.insert(e.tx) }
            if e.op == "commit" || e.op == "abort" { open.remove(e.tx) }
        }
        return !open.isEmpty
    }

    public func begin(tx: String, steps: [String]) throws {
        try append(Entry(op: "begin", tx: tx, index: nil, steps: steps,
                         time: Int64(Date().timeIntervalSince1970)))
    }

    public func step(tx: String, index: Int) throws {
        try append(Entry(op: "step", tx: tx, index: index, steps: nil,
                         time: Int64(Date().timeIntervalSince1970)))
    }

    public func finish(tx: String, committed: Bool) throws {
        try append(Entry(op: committed ? "commit" : "abort", tx: tx, index: nil, steps: nil,
                         time: Int64(Date().timeIntervalSince1970)))
    }

    /// Returns the steps that were recorded but never committed, for the most
    /// recent unfinished transaction. Steps are opaque strings the operation
    /// interprets (e.g. "ref:refs/heads/main=<oid>").
    public func unfinishedSteps() -> [String] {
        guard let lines = try? readLines() else { return [] }
        var open: [String: [String]] = [:]
        for line in lines {
            guard let e = try? JSONDecoder().decode(Entry.self, from: Data(line.utf8)) else { continue }
            switch e.op {
            case "begin": open[e.tx] = e.steps ?? []
            case "commit", "abort": open.removeValue(forKey: e.tx)
            default: break
            }
        }
        return open.values.flatMap { $0 }
    }

    /// Truncates the journal after all transactions are finished. Called by
    /// maintenance (`spaces gc`) — never automatic, to preserve auditability.
    public func compact() throws {
        guard let lines = try? readLines() else { return }
        var keep: [String] = []
        var open = Set<String>()
        for line in lines {
            guard let e = try? JSONDecoder().decode(Entry.self, from: Data(line.utf8)) else { continue }
            if e.op == "begin" { open.insert(e.tx) }
            if e.op == "commit" || e.op == "abort" { open.remove(e.tx) }
            if !open.isEmpty || e.op == "begin" { keep.append(line) }
        }
        try atomicWriteText(keep.joined(separator: "\n") + (keep.isEmpty ? "" : "\n"))
    }

    private func readLines() throws -> [String] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let text = try String(contentsOf: url, encoding: .utf8)
        return text.components(separatedBy: "\n").filter { !$0.isEmpty }
    }

    private func append(_ entry: Entry) throws {
        lock.lock(); defer { lock.unlock() }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        var line = try encoder.encode(entry)
        line.append(0x0a)
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: line)
    }

    private func atomicWriteText(_ text: String) throws {
        let temp = url.appendingPathExtension("tmp-\(UUID().uuidString)")
        try Data(text.utf8).write(to: temp)
        _ = try? FileManager.default.removeItem(at: url)
        try FileManager.default.moveItem(at: temp, to: url)
    }
}
