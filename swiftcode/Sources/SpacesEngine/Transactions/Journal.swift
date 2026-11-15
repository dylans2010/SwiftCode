import Foundation

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
        !unfinishedTransactionIDs().isEmpty
    }

    public func unfinishedTransactionIDs() -> [String] {
        guard let lines = try? readLines() else { return [] }
        var order: [String] = []
        var open = Set<String>()
        for line in lines {
            guard let e = try? JSONDecoder().decode(Entry.self, from: Data(line.utf8)) else { continue }
            if e.op == "begin", !open.contains(e.tx) {
                open.insert(e.tx)
                order.append(e.tx)
            }
            if e.op == "commit" || e.op == "abort" {
                open.remove(e.tx)
                order.removeAll { $0 == e.tx }
            }
        }
        return order
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

    public func compact() throws {
        guard let lines = try? readLines() else { return }
        var unfinished = Set<String>()
        var parsed: [Entry?] = []
        for line in lines {
            let entry = try? JSONDecoder().decode(Entry.self, from: Data(line.utf8))
            parsed.append(entry)
            if let e = entry {
                if e.op == "begin" { unfinished.insert(e.tx) }
                if e.op == "commit" || e.op == "abort" { unfinished.remove(e.tx) }
            }
        }
        var keep: [String] = []
        for (line, entry) in zip(lines, parsed) {
            if let e = entry, unfinished.contains(e.tx) { keep.append(line) }
        }
        let text = keep.joined(separator: "\n") + (keep.isEmpty ? "" : "\n")
        try AtomicFileIO.writeAtomically(Data(text.utf8), to: url)
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
        try AtomicFileIO.append(line, to: url)
    }
}
