import Foundation

/// Content-addressed object database rooted at `.spaces/objects/`.
///
/// Layout: `objects/<first-2-hex>/<remaining-hex>`. Writes are atomic
/// (temp file + rename) and deduplicated (an existing object is never
/// rewritten). Reads always re-verify the payload hash, so corrupt objects
/// are detected at lookup time rather than trusted blindly.
public final class ObjectStore: @unchecked Sendable {
    public let root: URL // .spaces/objects

    public init(root: URL) {
        self.root = root
    }

    public func url(for id: ObjectID) -> URL {
        let (prefix, rest) = id.objectPathComponents
        return root.appendingPathComponent(prefix).appendingPathComponent(rest)
    }

    public func exists(_ id: ObjectID) -> Bool {
        FileManager.default.fileExists(atPath: url(for: id).path)
    }

    /// Writes an object if absent. Returns its ID. Idempotent and atomic.
    @discardableResult
    public func write(type: ObjectType, payload: Data) throws -> ObjectID {
        let id = ObjectID.compute(type: type, payload: payload)
        let destination = url(for: id)
        if FileManager.default.fileExists(atPath: destination.path) { return id }
        let encoded = ObjectCoding.encode(StoredObject(type: type, payload: payload))
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        let temp = destination.appendingPathExtension("tmp-\(UUID().uuidString)")
        try encoded.write(to: temp, options: .atomic)
        _ = try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: temp, to: destination)
        return id
    }

    /// Convenience: encode a Codable payload and store it.
    @discardableResult
    public func write<T: Encodable>(_ type: ObjectType, value: T) throws -> ObjectID {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try write(type: type, payload: encoder.encode(value))
    }

    /// Reads and fully validates an object: framing, declared type, and the
    /// cryptographic ID must match the requested ID.
    public func read(_ id: ObjectID, expectedType: ObjectType? = nil) throws -> StoredObject {
        let file = url(for: id)
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw SpacesError.objectNotFound(id.hex)
        }
        let data: Data
        do { data = try Data(contentsOf: file) }
        catch { throw SpacesError.ioError("cannot read object \(id.hex): \(error.localizedDescription)") }

        let stored: StoredObject
        do { stored = try ObjectCoding.decode(data) }
        catch { throw SpacesError.objectCorrupt(id.hex) }

        if let expected = expectedType, stored.type != expected {
            throw SpacesError.invalidObject("object \(id.hex) is \(stored.type.rawValue), expected \(expected.rawValue)")
        }
        let actual = ObjectID.compute(type: stored.type, payload: stored.payload)
        guard actual == id else { throw SpacesError.objectCorrupt(id.hex) }
        return stored
    }

    public func readPayload<T: Decodable>(_ id: ObjectID, expected: ObjectType? = nil) throws -> T {
        let stored = try read(id, expectedType: expected)
        do { return try JSONDecoder().decode(T.self, from: stored.payload) }
        catch { throw SpacesError.invalidObject("cannot decode \(id.hex) as \(T.self): \(error.localizedDescription)") }
    }

    /// Lists IDs of stored objects whose hex begins with `prefix`.
    /// Used for abbreviated-ID resolution.
    public func existingIDs(matchingPrefix prefix: String) throws -> [ObjectID] {
        guard !prefix.isEmpty else { return [] }
        var results: [ObjectID] = []
        let lowered = prefix.lowercased()
        if lowered.count <= 2 {
            let dir = root.appendingPathComponent(lowered)
            guard let files = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else { return [] }
            for f in files where !f.contains(".") {
                results.append(ObjectID(hex: lowered + f))
            }
            return results
        }
        let dirPrefix = String(lowered.prefix(2))
        let dir = root.appendingPathComponent(dirPrefix)
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else { return [] }
        let restPrefix = String(lowered.dropFirst(2))
        for f in files where f.hasPrefix(restPrefix) && !f.contains(".") {
            results.append(ObjectID(hex: dirPrefix + f))
        }
        return results
    }

    /// All object IDs in the store (used by gc, fsck, count-objects).
    public func allIDs() throws -> [ObjectID] {
        guard let top = try? FileManager.default.contentsOfDirectory(atPath: root.path) else { return [] }
        var ids: [ObjectID] = []
        for d in top where d.count == 2 && !d.contains(".") {
            let dir = root.appendingPathComponent(d)
            guard let files = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else { continue }
            for f in files where !f.contains(".") {
                ids.append(ObjectID(hex: d + f))
            }
        }
        return ids
    }

    /// Total bytes used by the object directory.
    public func diskUsage() throws -> Int64 {
        var total: Int64 = 0
        guard let enumerator = FileManager.default.enumerator(atPath: root.path) else { return 0 }
        for case let path as String in enumerator {
            let full = root.appendingPathComponent(path)
            if let attrs = try? FileManager.default.attributesOfItem(atPath: full.path),
               let size = attrs[.size] as? Int64 {
                total += size
            }
        }
        return total
    }

    /// Reachability walk: given seed object IDs, returns every object reachable
    /// through tree/commit/tag/snapshot payloads.
    public func reachable(from seeds: [ObjectID]) throws -> Set<ObjectID> {
        var seen = Set<ObjectID>()
        var stack = seeds
        while let id = stack.popLast() {
            guard !seen.contains(id) else { continue }
            seen.insert(id)
            guard let stored = try? read(id) else { continue }
            switch stored.type {
            case .tree:
                if let tree = try? JSONDecoder().decode(TreePayload.self, from: stored.payload) {
                    for e in tree.entries { stack.append(e.oid) }
                }
            case .commit:
                if let c = try? JSONDecoder().decode(CommitPayload.self, from: stored.payload) {
                    stack.append(c.tree); stack.append(contentsOf: c.parents)
                }
            case .tag:
                if let t = try? JSONDecoder().decode(TagPayload.self, from: stored.payload) {
                    stack.append(t.object)
                }
            case .snapshot:
                if let s = try? JSONDecoder().decode(SnapshotPayload.self, from: stored.payload) {
                    stack.append(s.tree)
                    if let it = s.indexTree { stack.append(it) }
                    stack.append(contentsOf: s.parents)
                }
            case .blob:
                break
            }
        }
        return seen
    }

    /// Removes objects not in `keep`. Returns number removed. Caller is
    /// responsible for ensuring `keep` is correct (see Repository.gc).
    @discardableResult
    public func prune(unreachable keep: Set<ObjectID>) throws -> Int {
        let all = try allIDs()
        var removed = 0
        for id in all where !keep.contains(id) {
            try? FileManager.default.removeItem(at: url(for: id))
            removed += 1
        }
        return removed
    }
}
