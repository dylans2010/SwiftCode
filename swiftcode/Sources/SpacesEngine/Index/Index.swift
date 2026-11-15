import Foundation

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

public struct IndexEntry: Codable, Hashable, Sendable {
    public var oid: ObjectID
    public var mode: FileMode
    public var size: Int64
    public var mtime: Int64
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
            if headResolves(siblingOf: url) {
                throw SpacesError.indexCorrupt("index file is missing but HEAD resolves to a commit")
            }
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
        try AtomicFileIO.writeAtomically(encoder.encode(self), to: url)
    }

    public static func entry(forFileAt url: URL, oid: ObjectID, mode: FileMode,
                             objects: ObjectStore? = nil) throws -> IndexEntry {
        let values = try statValues(at: url)
        return IndexEntry(oid: oid, mode: mode, size: values.size,
                          mtime: values.mtimeNanos, ctime: values.ctimeNanos,
                          device: values.device, inode: values.inode)
    }

    public static func entry(fileAt url: URL, matchingOID expectedOID: ObjectID,
                             mode expectedMode: FileMode,
                             objects: ObjectStore) throws -> IndexEntry {
        let values = try statValues(at: url)
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
        let actualOID = ObjectID.compute(type: .blob, payload: data)
        let oid = actualOID == expectedOID ? expectedOID : actualOID
        let mode = actualMode == expectedMode ? expectedMode : actualMode
        return IndexEntry(oid: oid, mode: mode, size: values.size,
                          mtime: values.mtimeNanos, ctime: values.ctimeNanos,
                          device: values.device, inode: values.inode)
    }

    public static func statMatches(_ entry: IndexEntry, fileAt url: URL) -> Bool {
        guard let values = try? statValues(at: url) else { return false }
        return values.size == entry.size && values.mtimeNanos == entry.mtime && values.inode == entry.inode
    }

    private static func statValues(at url: URL) throws -> (size: Int64, mtimeNanos: Int64, ctimeNanos: Int64, device: Int64, inode: Int64) {
        var st = stat()
        let result = url.path.withCString { stat($0, &st) }
        guard result == 0 else {
            throw SpacesError.ioError("cannot stat \(url.path): \(AtomicFileIO.posixMessage())")
        }
        #if canImport(Darwin)
        let mtimeNanos = Int64(st.st_mtimespec.tv_sec) * 1_000_000_000 + Int64(st.st_mtimespec.tv_nsec)
        let ctimeNanos = Int64(st.st_ctimespec.tv_sec) * 1_000_000_000 + Int64(st.st_ctimespec.tv_nsec)
        #else
        let mtimeNanos = Int64(st.st_mtim.tv_sec) * 1_000_000_000 + Int64(st.st_mtim.tv_nsec)
        let ctimeNanos = Int64(st.st_ctim.tv_sec) * 1_000_000_000 + Int64(st.st_ctim.tv_nsec)
        #endif
        return (Int64(st.st_size), mtimeNanos, ctimeNanos, Int64(st.st_dev), Int64(st.st_ino))
    }

    private static func headResolves(siblingOf indexURL: URL) -> Bool {
        let meta = indexURL.deletingLastPathComponent()
        guard let headText = try? String(contentsOf: meta.appendingPathComponent("HEAD"), encoding: .utf8) else { return false }
        let head = headText.trimmingCharacters(in: .whitespacesAndNewlines)
        if head.hasPrefix("ref: ") {
            let target = String(head.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            if target.isEmpty { return false }
            if FileManager.default.fileExists(atPath: meta.appendingPathComponent(target).path) { return true }
            if let packed = try? String(contentsOf: meta.appendingPathComponent("packed-refs"), encoding: .utf8) {
                for line in packed.components(separatedBy: "\n") {
                    let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
                    if parts.count == 2, parts[1] == target { return true }
                }
            }
            return false
        }
        guard !head.isEmpty, (try? ObjectID(validating: head)) != nil else { return false }
        let (prefix, rest) = ObjectID(hex: head).objectPathComponents
        return FileManager.default.fileExists(atPath: meta.appendingPathComponent("objects").appendingPathComponent(prefix).appendingPathComponent(rest).path)
    }
}
