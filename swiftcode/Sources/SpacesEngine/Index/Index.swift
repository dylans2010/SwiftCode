import Foundation

/// One staged path's record: object id, mode, and filesystem stat cache used
/// to skip re-hashing unchanged files.
public struct IndexEntry: Codable, Hashable, Sendable {
    public var oid: ObjectID
    public var mode: FileMode
    public var size: Int64
    public var mtime: Int64   // nanoseconds since 1970
    public var ctime: Int64
    public var device: Int64
    public var inode: Int64

    public init(oid: ObjectID, mode: FileMode, size: Int64,
                mtime: Int64, ctime: Int64, device: Int64, inode: Int64) {
        self.oid = oid
        self.mode = mode
        self.size = size
        self.mtime = mtime
        self.ctime = ctime
        self.device = device
        self.inode = inode
    }
}

/// The staging index: `.spaces/index`. Versioned JSON mapping repo-relative
/// paths to their staged object IDs.
public struct Index: Codable, Sendable {
    public var version: Int
    public var entries: [String: IndexEntry]

    public init(version: Int = RepositoryFormat.indexVersion,
                entries: [String: IndexEntry] = [:]) {
        self.version = version
        self.entries = entries
    }

    public static func load(from url: URL) throws -> Index {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return Index()
        }
        do {
            let idx = try JSONDecoder().decode(Index.self, from: Data(contentsOf: url))
            guard idx.version <= RepositoryFormat.indexVersion else {
                throw SpacesError.indexCorrupt("index version \(idx.version) is newer than supported")
            }
            return idx
        } catch let e as SpacesError {
            throw e
        } catch {
            throw SpacesError.indexCorrupt(error.localizedDescription)
        }
    }

    public func save(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let temp = url.appendingPathExtension("tmp-\(UUID().uuidString)")
        try encoder.encode(self).write(to: temp)
        _ = try? FileManager.default.removeItem(at: url)
        try FileManager.default.moveItem(at: temp, to: url)
    }

    // MARK: - Stat helpers

    /// Builds an IndexEntry for a worktree file, hashing its contents.
    public static func entry(forFileAt url: URL, oid: ObjectID, mode: FileMode,
                             objects: ObjectStore? = nil) throws -> IndexEntry {
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attrs[.size] as? Int64) ?? 0
        let mtime = Self.mtimeNanos(of: attrs)
        let ctime = Int64((attrs[.creationDate] as? Date)?.timeIntervalSince1970 ?? 0)
        let device = Int64((attrs[.systemNumber] as? Int) ?? 0)
        let inode = Int64((attrs[.systemFileNumber] as? Int) ?? 0)
        return IndexEntry(oid: oid, mode: mode, size: size,
                          mtime: mtime, ctime: ctime, device: device, inode: inode)
    }

    /// Builds an index entry for `url` whose recorded OID is `expectedOID`
    /// (e.g. a HEAD tree entry during reset/rebuild-index). The file is hashed
    /// once: when contents and mode match, the real stat cache is stored;
    /// otherwise the stat cache is invalidated so status re-hashes the file
    /// and reports the unstaged difference instead of a false clean.
    public static func entry(fileAt url: URL, matchingOID expectedOID: ObjectID,
                             mode expectedMode: FileMode,
                             objects: ObjectStore) throws -> IndexEntry {
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let isSymlink = (attrs[.type] as? FileAttributeType) == .typeSymbolicLink
        let data: Data
        let actualMode: FileMode
        if isSymlink {
            data = Data(try FileManager.default.destinationOfSymbolicLink(atPath: url.path).utf8)
            actualMode = .symlink
        } else {
            data = try Data(contentsOf: url)
            let perms = (attrs[.posixPermissions] as? Int) ?? 0o644
            actualMode = (perms & 0o111) != 0 ? .executable : .regular
        }
        let actualOID = try objects.write(type: .blob, payload: data)
        guard actualOID == expectedOID, actualMode == expectedMode else {
            return IndexEntry(oid: expectedOID, mode: expectedMode, size: 0,
                              mtime: 0, ctime: 0, device: 0, inode: 0)
        }
        return try entry(forFileAt: url, oid: expectedOID, mode: expectedMode)
    }

    /// True when the file's stat data still matches the cached entry, meaning
    /// the contents are very likely unchanged (mtime+size+inode match).
    public static func statMatches(_ entry: IndexEntry, fileAt url: URL) -> Bool {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) else { return false }
        let size = (attrs[.size] as? Int64) ?? -1
        let mtime = mtimeNanos(of: attrs)
        let inode = Int64((attrs[.systemFileNumber] as? Int) ?? -1)
        return size == entry.size && mtime == entry.mtime && inode == entry.inode
    }

    /// Modification time in nanoseconds. Second-granularity timestamps let a
    /// same-size rewrite inside one second look unchanged; nanoseconds close
    /// that window to filesystem timestamp resolution.
    private static func mtimeNanos(of attrs: [FileAttributeKey: Any]) -> Int64 {
        guard let date = attrs[.modificationDate] as? Date else { return -1 }
        return Int64(date.timeIntervalSince1970 * 1_000_000_000)
    }
}
