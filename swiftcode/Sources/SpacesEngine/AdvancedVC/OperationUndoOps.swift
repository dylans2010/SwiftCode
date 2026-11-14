import Foundation

public struct OperationUndoOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public struct UndoRecord: Sendable, Codable {
        public var id: String
        public var operation: String
        public var target: String
        public var oid: String?
        public var detail: String?
        public var timestamp: Int64
    }

    private var logURL: URL {
        repo.metaURL.appendingPathComponent("undo").appendingPathComponent("log.jsonl")
    }

    private func readLog() -> [UndoRecord] {
        AdvancedVCStore.readJSONLines(UndoRecord.self, from: logURL)
    }

    private func writeLog(_ records: [UndoRecord]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let text = records.map { record in
            String(decoding: (try? encoder.encode(record)) ?? Data(), as: UTF8.self)
        }.joined(separator: "\n") + (records.isEmpty ? "" : "\n")
        try FileManager.default.createDirectory(at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try AdvancedVCStore.writeText(text, to: logURL)
    }

    private func appendRecord(operation: String, target: String, oid: String?, detail: String?) throws -> UndoRecord {
        let record = UndoRecord(id: UUID().uuidString, operation: operation, target: target,
                                oid: oid, detail: detail, timestamp: AdvancedVCStore.now())
        return try repo.withLock {
            try AdvancedVCStore.appendJSONLine(record, to: logURL)
            return record
        }
    }

    public func undoableOperations() throws -> [UndoRecord] {
        readLog().sorted { $0.timestamp > $1.timestamp }
    }

    @discardableResult
    public func createBranchUndoable(name: String, at rev: String = "HEAD") throws -> ObjectID {
        let oid = try BranchOps(repo: repo).create(name, at: rev)
        _ = try appendRecord(operation: "branch-create", target: name, oid: oid.hex, detail: nil)
        return oid
    }

    public func deleteBranchUndoable(name: String, force: Bool = false) throws {
        try BranchOps(repo: repo).delete(name, force: force)
        let archive = try repo.refs.allRefs()
            .filter { $0.name.hasPrefix("refs/archive/branches/\(name)-") }
            .sorted { $0.name < $1.name }.last
        _ = try appendRecord(operation: "branch-delete", target: name, oid: archive?.oid.hex, detail: archive?.name)
    }

    @discardableResult
    public func createTagUndoable(name: String, at rev: String = "HEAD", annotated: Bool = false, message: String = "") throws -> ObjectID {
        let oid = try TagOps(repo: repo).create(name, at: rev, annotated: annotated, message: message)
        _ = try appendRecord(operation: "tag-create", target: name, oid: oid.hex, detail: nil)
        return oid
    }

    public func deleteTagUndoable(name: String) throws {
        guard let oid = try repo.refs.readRef("refs/tags/\(name)") else {
            throw SpacesError.refNotFound(name)
        }
        try TagOps(repo: repo).delete(name)
        let archive = try repo.refs.allRefs()
            .filter { $0.name.hasPrefix("refs/archive/tags/\(name)-") }
            .sorted { $0.name < $1.name }.last
        _ = try appendRecord(operation: "tag-delete", target: name, oid: oid.hex, detail: archive?.name)
    }

    @discardableResult
    public func createSnapshotUndoable(message: String) throws -> ObjectID {
        let oid = try SnapshotOps(repo: repo).create(message: message, kind: .manual)
        _ = try appendRecord(operation: "snapshot-create", target: oid.hex, oid: oid.hex, detail: nil)
        return oid
    }

    @discardableResult
    public func createStashUndoable(message: String? = nil) throws -> StashOps.StashEntry {
        guard let entry = try StashOps(repo: repo).create(message: message) else {
            throw SpacesError.nothingToCommit
        }
        _ = try appendRecord(operation: "stash-create", target: entry.id, oid: entry.oid.hex, detail: nil)
        return entry
    }

    @discardableResult
    public func undoLast() throws -> UndoRecord {
        var records = readLog()
        guard let last = records.last else {
            throw SpacesError.invalidArgument("nothing to undo")
        }
        switch last.operation {
        case "branch-create":
            try BranchOps(repo: repo).delete(last.target, force: true)
        case "branch-delete":
            guard let archive = last.detail else {
                throw SpacesError.internalInconsistency("deleted branch \(last.target) has no archive ref")
            }
            try BranchOps(repo: repo).restoreArchived(archive, as: last.target)
        case "tag-create":
            try TagOps(repo: repo).delete(last.target)
        case "tag-delete":
            guard let hex = last.oid, let oid = try? ObjectID(validating: hex) else {
                throw SpacesError.internalInconsistency("deleted tag \(last.target) has no recorded object id")
            }
            try repo.withLock {
                _ = try repo.refs.updateRef("refs/tags/\(last.target)", to: oid)
            }
        case "snapshot-create":
            guard let hex = last.oid else {
                throw SpacesError.internalInconsistency("created snapshot has no recorded object id")
            }
            try SnapshotOps(repo: repo).delete(hex)
        case "stash-create":
            try StashOps(repo: repo).drop(last.target)
        default:
            throw SpacesError.unsupportedOperation("cannot undo \(last.operation): undo never rewrites commits, merges, rebases or pushes")
        }
        records.removeLast()
        try repo.withLock {
            try writeLog(records)
        }
        return last
    }
}
