import Foundation

enum StorageFileIO {
    static func directory(repo: Repository) throws -> URL {
        let dir = repo.metaURL.appendingPathComponent("storage")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func load<T: Decodable>(repo: Repository, name: String, defaultValue: T) throws -> T {
        let url = try directory(repo: repo).appendingPathComponent(name)
        guard let data = try? Data(contentsOf: url) else { return defaultValue }
        return (try? JSONDecoder().decode(T.self, from: data)) ?? defaultValue
    }

    static func save<T: Encodable>(repo: Repository, name: String, value: T) throws {
        let dir = try directory(repo: repo)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        try repo.refs.atomicWrite(dir.appendingPathComponent(name), contents: encoder.encode(value))
    }

    static func appendLine(repo: Repository, name: String, line: String) throws {
        let url = try directory(repo: repo).appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: url.path) {
            let handle = try FileHandle(forWritingTo: url)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: Data(line.utf8))
        } else {
            try Data(line.utf8).write(to: url, options: .atomic)
        }
    }

    static func readLines(repo: Repository, name: String) throws -> [String] {
        let url = try directory(repo: repo).appendingPathComponent(name)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return text.components(separatedBy: "\n").filter { !$0.isEmpty }
    }
}

public struct ContinuousSnapshotOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public static let triggerDescription = "There is no background daemon. Continuous snapshots are captured only when SpacesAPI.status() is called and the configured interval has elapsed since the last scheduled snapshot."

    public struct ContinuousConfig: Codable, Sendable {
        public var enabled: Bool
        public var intervalMinutes: Int
        public var maxSnapshots: Int

        public init(enabled: Bool = false, intervalMinutes: Int = 60, maxSnapshots: Int = 10) {
            self.enabled = enabled
            self.intervalMinutes = intervalMinutes
            self.maxSnapshots = maxSnapshots
        }
    }

    public func config() throws -> ContinuousConfig {
        try StorageFileIO.load(repo: repo, name: "continuous.json", defaultValue: ContinuousConfig())
    }

    public func setConfig(_ config: ContinuousConfig) throws {
        try repo.withLock {
            try StorageFileIO.save(repo: repo, name: "continuous.json", value: config)
        }
    }

    public func listContinuous() throws -> [SnapshotOps.SnapshotInfo] {
        try SnapshotOps(repo: repo).list().filter { $0.kind == SnapshotOps.Kind.scheduled.rawValue }
    }

    @discardableResult
    public func captureIfDue() throws -> ObjectID? {
        let config = try config()
        guard config.enabled else { return nil }
        let now = Int64(Date().timeIntervalSince1970)
        if let last = try listContinuous().first,
           now - last.timestamp < Int64(config.intervalMinutes * 60) {
            return nil
        }
        let oid = try SnapshotOps(repo: repo).create(
            message: "Continuous workspace snapshot", kind: .scheduled)
        try pruneOldestScheduled(keeping: config.maxSnapshots)
        return oid
    }

    private func pruneOldestScheduled(keeping max: Int) throws {
        guard max >= 0 else { return }
        var scheduled = try listContinuous().sorted { $0.timestamp < $1.timestamp }
        let pinned = Set(try RetentionPolicyOps(repo: repo).policy().pinned)
        while scheduled.count > max {
            guard let oldest = scheduled.first(where: { !pinned.contains($0.oid.hex) }) else { return }
            try SnapshotOps(repo: repo).delete(oldest.oid.hex)
            scheduled.removeAll { $0.oid == oldest.oid }
        }
    }
}
