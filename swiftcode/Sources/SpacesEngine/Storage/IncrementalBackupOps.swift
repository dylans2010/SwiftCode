import Foundation

public struct IncrementalBackupOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public struct BackupManifest: Codable, Sendable {
        public var id: String
        public var objects: [String]
        public var base: String?
        public var timestamp: Int64

        public init(id: String, objects: [String], base: String?, timestamp: Int64) {
            self.id = id
            self.objects = objects
            self.base = base
            self.timestamp = timestamp
        }
    }

    private var backupsDir: URL {
        repo.metaURL.appendingPathComponent("storage").appendingPathComponent("backups")
    }

    @discardableResult
    public func createBackup(to path: String) throws -> BackupManifest {
        try repo.withLock {
            let previous = try backups().first
            let previousObjects = Set(previous?.objects ?? [])
            var seeds: [ObjectID] = []
            for ref in try repo.refs.allRefs() { seeds.append(ref.oid) }
            if let head = try repo.refs.headOID(objects: repo.objects) { seeds.append(head) }
            let reachable = try repo.objects.reachable(from: seeds)
            let fresh = reachable.filter { !previousObjects.contains($0.hex) }.sorted()
            let timestamp = Int64(Date().timeIntervalSince1970)
            let id = "\(timestamp)-\(String(UUID().uuidString.prefix(8)))"
            try writeBundle(to: path, objects: fresh)
            let manifest = BackupManifest(id: id, objects: fresh.map(\.hex),
                                          base: previous?.id, timestamp: timestamp)
            try FileManager.default.createDirectory(at: backupsDir, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
            try repo.refs.atomicWrite(backupsDir.appendingPathComponent("\(id).json"),
                                      contents: encoder.encode(manifest))
            return manifest
        }
    }

    public func verifyBackup(url: String) throws -> BundleOps.BundleReport {
        let report = try BundleOps.verify(path: url)
        for hex in report.objects {
            if let oid = try? ObjectID(validating: hex), repo.objects.exists(oid) {
                _ = try repo.objects.read(oid)
            }
        }
        return report
    }

    @discardableResult
    public func restoreBackup(url: String) throws -> BundleOps.BundleReport {
        try repo.withLock {
            try BundleOps.importBundle(into: repo, path: url)
        }
    }

    public func backups() throws -> [BackupManifest] {
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: backupsDir.path) else {
            return []
        }
        var manifests: [BackupManifest] = []
        for file in files where file.hasSuffix(".json") {
            if let data = try? Data(contentsOf: backupsDir.appendingPathComponent(file)),
               let manifest = try? JSONDecoder().decode(BackupManifest.self, from: data) {
                manifests.append(manifest)
            }
        }
        return manifests.sorted { $0.timestamp > $1.timestamp }
    }

    private func writeBundle(to path: String, objects: [ObjectID]) throws {
        struct Header: Codable {
            var refs: [String: String]
            var objects: [String]
            var created: Int64
            var message: String
        }
        let header = Header(refs: [:], objects: objects.map(\.hex),
                            created: Int64(Date().timeIntervalSince1970),
                            message: "spaces incremental backup")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let headerData = try encoder.encode(header)
        var out = Data()
        out.append(contentsOf: [0x53, 0x50, 0x42, 0x44])
        var version: UInt32 = 1
        withUnsafeBytes(of: version.bigEndian) { out.append(contentsOf: $0) }
        var headerLen = UInt64(headerData.count).bigEndian
        withUnsafeBytes(of: &headerLen) { out.append(contentsOf: $0) }
        out.append(headerData)
        for id in objects {
            let stored = try repo.objects.read(id)
            let encoded = ObjectCoding.encode(StoredObject(type: stored.type, payload: stored.payload))
            var len = UInt64(encoded.count).bigEndian
            withUnsafeBytes(of: &len) { out.append(contentsOf: $0) }
            out.append(encoded)
        }
        let url = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try out.write(to: url, options: .atomic)
    }
}
