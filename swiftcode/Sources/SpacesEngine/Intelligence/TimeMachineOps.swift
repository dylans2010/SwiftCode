import Foundation

enum SpacesIntelligenceStore {
    static func intelligenceDirectory(repo: Repository) throws -> URL {
        let url = repo.metaURL.appendingPathComponent("intelligence", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func writeJSON<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        let data = try encoder.encode(value)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let temp = url.appendingPathExtension("tmp-\(UUID().uuidString)")
        try data.write(to: temp, options: .atomic)
        _ = try? FileManager.default.removeItem(at: url)
        try FileManager.default.moveItem(at: temp, to: url)
    }

    static func readJSON<T: Decodable>(_ type: T.Type, from url: URL) throws -> T? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
        } catch {
            throw SpacesError.ioError("cannot decode \(url.lastPathComponent): \(error.localizedDescription)")
        }
    }

    static func appendLine(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            try data.write(to: url, options: .atomic)
            return
        }
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
    }

    static func blobText(repo: Repository, oid: ObjectID) -> String? {
        guard let data = try? repo.blobData(oid) else { return nil }
        guard !DiffEngine.isBinary(data) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func stateTree(repo: Repository, rev: String) throws -> (oid: ObjectID, tree: ObjectID) {
        let oid = try repo.resolveRevision(rev)
        if let commit = try? repo.commitObject(oid) {
            return (oid, commit.tree)
        }
        if let snapshot: SnapshotPayload = try? repo.objects.readPayload(oid, expected: .snapshot) {
            return (oid, snapshot.tree)
        }
        throw SpacesError.invalidArgument("not a commit or snapshot state: \(rev)")
    }

    static func rebuildIndexFromFlat(repo: Repository, flat: [String: (oid: ObjectID, mode: FileMode)]) throws {
        var index = Index()
        for (path, entry) in flat {
            let url = try repo.worktreeURL(forRelativePath: path)
            if FileManager.default.fileExists(atPath: url.path) {
                index.entries[path] = try Index.entry(
                    fileAt: url, matchingOID: entry.oid, mode: entry.mode, objects: repo.objects)
            }
        }
        try repo.saveIndex(index)
    }
}

public struct TimeMachineOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public enum StateKind: String, Codable, Sendable {
        case commit, snapshot, reflog
    }

    public struct TimeMachineState: Codable, Sendable {
        public var oid: ObjectID?
        public var kind: StateKind
        public var timestamp: Int64
        public var title: String
        public var detail: String
    }

    public func states(limit: Int = 100) throws -> [TimeMachineState] {
        var collected: [TimeMachineState] = []
        for snapshot in try SnapshotOps(repo: repo).list(limit: limit) {
            collected.append(TimeMachineState(
                oid: snapshot.oid, kind: .snapshot, timestamp: snapshot.timestamp,
                title: snapshot.message, detail: "snapshot (\(snapshot.kind))"))
        }
        for commit in try HistoryOps(repo: repo).log(limit: limit) {
            collected.append(TimeMachineState(
                oid: commit.oid, kind: .commit, timestamp: commit.timestamp,
                title: commit.summary, detail: commit.author.name))
        }
        for entry in try repo.readReflog(limit: limit) {
            guard let oid = entry.new else { continue }
            collected.append(TimeMachineState(
                oid: oid, kind: .reflog, timestamp: entry.timestamp,
                title: entry.message, detail: entry.ident))
        }
        var seen = Set<String>()
        var deduped: [TimeMachineState] = []
        for state in collected.sorted(by: { $0.timestamp > $1.timestamp }) {
            let key = "\(state.kind.rawValue):\(state.oid?.hex ?? state.title)"
            guard seen.insert(key).inserted else { continue }
            deduped.append(state)
        }
        return Array(deduped.prefix(max(0, limit)))
    }

    @discardableResult
    public func restoreState(rev: String, paths: [String]? = nil) throws -> [String] {
        try repo.performTransaction(steps: ["time-machine-restore:\(rev)"]) {
            let resolved = try SpacesIntelligenceStore.stateTree(repo: repo, rev: rev)
            let flat = try TreeBuilder.flattenTree(repo: repo, treeOID: resolved.tree)
            guard let requested = paths else {
                _ = try TreeBuilder.checkout(repo: repo, treeOID: resolved.tree)
                try SpacesIntelligenceStore.rebuildIndexFromFlat(repo: repo, flat: flat)
                return flat.keys.sorted()
            }
            guard !requested.isEmpty else {
                throw SpacesError.invalidArgument("restore paths must not be empty")
            }
            var affected: [String] = []
            var index = try repo.index()
            for path in requested {
                let exact = flat[path]
                if exact != nil {
                    let url = try repo.worktreeURL(forRelativePath: path)
                    try FileManager.default.createDirectory(
                        at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try repo.blobData(exact!.oid).write(to: url)
                    index.entries[path] = try Index.entry(
                        fileAt: url, matchingOID: exact!.oid, mode: exact!.mode,
                        objects: repo.objects)
                    affected.append(path)
                    continue
                }
                let prefix = path + "/"
                let under = flat.keys.filter { $0.hasPrefix(prefix) }.sorted()
                if !under.isEmpty {
                    for target in under {
                        let url = try repo.worktreeURL(forRelativePath: target)
                        try FileManager.default.createDirectory(
                            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                        try repo.blobData(flat[target]!.oid).write(to: url)
                        index.entries[target] = try Index.entry(
                            fileAt: url, matchingOID: flat[target]!.oid,
                            mode: flat[target]!.mode, objects: repo.objects)
                        affected.append(target)
                    }
                    for tracked in index.entries.keys where tracked.hasPrefix(prefix) && flat[tracked] == nil {
                        let url = try repo.worktreeURL(forRelativePath: tracked)
                        try? FileManager.default.removeItem(at: url)
                        index.entries.removeValue(forKey: tracked)
                        affected.append(tracked)
                    }
                    continue
                }
                if index.entries[path] != nil {
                    let url = try repo.worktreeURL(forRelativePath: path)
                    try? FileManager.default.removeItem(at: url)
                    index.entries.removeValue(forKey: path)
                    affected.append(path)
                    continue
                }
                throw SpacesError.pathNotFound(path)
            }
            try repo.saveIndex(index)
            return affected.sorted()
        }
    }
}
