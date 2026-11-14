import Foundation

public struct RecoveryVaultOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public struct VaultEntry: Codable, Sendable {
        public var id: String
        public var path: String
        public var blob: String
        public var timestamp: Int64
        public var reason: String
        public var size: Int64
    }

    private var vaultDir: URL { repo.metaURL.appendingPathComponent("vault") }
    private var manifestURL: URL { vaultDir.appendingPathComponent("manifest.json") }

    private func loadEntries() throws -> [VaultEntry] {
        guard let data = try? Data(contentsOf: manifestURL),
              let entries = try? JSONDecoder().decode([VaultEntry].self, from: data) else {
            return []
        }
        return entries
    }

    private func saveEntries(_ entries: [VaultEntry]) throws {
        try FileManager.default.createDirectory(at: vaultDir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        try repo.refs.atomicWrite(manifestURL, contents: encoder.encode(entries))
    }

    @discardableResult
    public func vaultRetain(paths: [String], reason: String = "retained") throws -> [VaultEntry] {
        try repo.withLock {
            var entries = try loadEntries()
            var created: [VaultEntry] = []
            for path in paths {
                let url = try repo.worktreeURL(forRelativePath: path)
                guard let data = try? Data(contentsOf: url) else {
                    throw SpacesError.pathNotFound(path)
                }
                let blob = try repo.objects.write(.blob, payload: data)
                let entry = VaultEntry(id: UUID().uuidString, path: path, blob: blob.hex,
                                       timestamp: Int64(Date().timeIntervalSince1970),
                                       reason: reason, size: Int64(data.count))
                entries.append(entry)
                created.append(entry)
            }
            try saveEntries(entries)
            return created
        }
    }

    public func vaultEntries() throws -> [VaultEntry] {
        try loadEntries().sorted { $0.timestamp > $1.timestamp }
    }

    @discardableResult
    public func restoreFromVault(entry id: String, path: String? = nil) throws -> String {
        try repo.withLock {
            guard let found = try loadEntries().first(where: { $0.id == id }) else {
                throw SpacesError.invalidArgument("no vault entry \(id)")
            }
            guard let oid = try? ObjectID(validating: found.blob) else {
                throw SpacesError.objectCorrupt(found.blob)
            }
            let data = try repo.blobData(oid)
            let target = path ?? found.path
            let url = try repo.worktreeURL(forRelativePath: target)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
            return target
        }
    }
}
