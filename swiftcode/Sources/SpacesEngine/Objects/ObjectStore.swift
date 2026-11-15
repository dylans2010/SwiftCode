import Foundation

public final class ObjectStore: @unchecked Sendable {
    public let root: URL

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

    @discardableResult
    public func write(type: ObjectType, payload: Data) throws -> ObjectID {
        let id = ObjectID.compute(type: type, payload: payload)
        let destination = url(for: id)
        if FileManager.default.fileExists(atPath: destination.path) {
            do {
                _ = try read(id)
                return id
            } catch {
                let encoded = ObjectCoding.encode(StoredObject(type: type, payload: payload))
                try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(),
                                                        withIntermediateDirectories: true)
                try AtomicFileIO.writeAtomically(encoded, to: destination)
                return id
            }
        }
        let encoded = ObjectCoding.encode(StoredObject(type: type, payload: payload))
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try AtomicFileIO.writeAtomically(encoded, to: destination)
        return id
    }

    @discardableResult
    public func write<T: Encodable>(_ type: ObjectType, value: T) throws -> ObjectID {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try write(type: type, payload: encoder.encode(value))
    }

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

    private func idsInDirectory(_ dir: URL, idPrefix: String, filePrefix: String) throws -> [ObjectID] {
        guard FileManager.default.fileExists(atPath: dir.path) else { return [] }
        let files: [String]
        do {
            files = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        } catch {
            throw SpacesError.ioError("cannot list objects in \(dir.path): \(error.localizedDescription)")
        }
        return files
            .filter { $0.hasPrefix(filePrefix) && !$0.contains(".") }
            .map { ObjectID(hex: idPrefix + $0) }
    }

    public func existingIDs(matchingPrefix prefix: String) throws -> [ObjectID] {
        guard !prefix.isEmpty else { return [] }
        let lowered = prefix.lowercased()
        if lowered.count <= 2 {
            let dir = root.appendingPathComponent(lowered)
            return try idsInDirectory(dir, idPrefix: lowered, filePrefix: "")
        }
        let dirPrefix = String(lowered.prefix(2))
        let dir = root.appendingPathComponent(dirPrefix)
        let restPrefix = String(lowered.dropFirst(2))
        return try idsInDirectory(dir, idPrefix: dirPrefix, filePrefix: restPrefix)
    }

    public func allIDs() throws -> [ObjectID] {
        guard FileManager.default.fileExists(atPath: root.path) else { return [] }
        let top: [String]
        do {
            top = try FileManager.default.contentsOfDirectory(atPath: root.path)
        } catch {
            throw SpacesError.ioError("cannot list object store \(root.path): \(error.localizedDescription)")
        }
        var ids: [ObjectID] = []
        for d in top where d.count == 2 && !d.contains(".") {
            let dir = root.appendingPathComponent(d)
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue else { continue }
            ids.append(contentsOf: try idsInDirectory(dir, idPrefix: d, filePrefix: ""))
        }
        return ids
    }

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

    public func reachable(from seeds: [ObjectID]) throws -> Set<ObjectID> {
        var seen = Set<ObjectID>()
        var stack = seeds
        while let id = stack.popLast() {
            guard !seen.contains(id) else { continue }
            seen.insert(id)
            let stored: StoredObject
            do {
                stored = try read(id)
            } catch let error as SpacesError {
                if case .objectNotFound = error { continue }
                throw error
            }
            switch stored.type {
            case .tree:
                let tree: TreePayload
                do { tree = try JSONDecoder().decode(TreePayload.self, from: stored.payload) }
                catch { throw SpacesError.objectCorrupt(id.hex) }
                for e in tree.entries { stack.append(e.oid) }
            case .commit:
                let commit: CommitPayload
                do { commit = try JSONDecoder().decode(CommitPayload.self, from: stored.payload) }
                catch { throw SpacesError.objectCorrupt(id.hex) }
                stack.append(commit.tree)
                stack.append(contentsOf: commit.parents)
            case .tag:
                let tag: TagPayload
                do { tag = try JSONDecoder().decode(TagPayload.self, from: stored.payload) }
                catch { throw SpacesError.objectCorrupt(id.hex) }
                stack.append(tag.object)
            case .snapshot:
                let snapshot: SnapshotPayload
                do { snapshot = try JSONDecoder().decode(SnapshotPayload.self, from: stored.payload) }
                catch { throw SpacesError.objectCorrupt(id.hex) }
                stack.append(snapshot.tree)
                if let indexTree = snapshot.indexTree { stack.append(indexTree) }
                stack.append(contentsOf: snapshot.parents)
            case .blob:
                break
            }
        }
        return seen
    }

    @discardableResult
    public func prune(unreachable keep: Set<ObjectID>) throws -> Int {
        let all = try allIDs()
        var removed = 0
        var failures: [String] = []
        for id in all where !keep.contains(id) {
            do {
                try FileManager.default.removeItem(at: url(for: id))
                removed += 1
            } catch {
                failures.append(id.hex)
            }
        }
        if !failures.isEmpty {
            throw SpacesError.ioError("failed to prune \(failures.count) object(s): \(failures.prefix(5).joined(separator: ", "))")
        }
        return removed
    }
}
