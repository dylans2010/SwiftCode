import Foundation

/// Builds nested tree objects from a flat path→entry map, and materializes a
/// tree back into the worktree.
public enum TreeBuilder {

    /// Builds (and stores) tree objects for the given flat listing.
    /// `entries`: repo-relative path → (oid, mode). Returns the root tree OID.
    /// An empty listing produces the canonical empty tree.
    @discardableResult
    public static func writeTree(entries listing: [String: (oid: ObjectID, mode: FileMode)],
                                 objects: ObjectStore) throws -> ObjectID {
        func sortKey(_ e: TreeEntry) -> String { e.mode.isDirectory ? e.name + "/" : e.name }

        /// Emits the tree object for one directory level and returns its
        /// entries. `items` maps names to either a blob entry or a subtree
        /// described by the paths beneath it.
        func emitLevel(_ items: [String: (oid: ObjectID, mode: FileMode)],
                       subdirs: [String: [String: (oid: ObjectID, mode: FileMode)]]) throws -> [TreeEntry] {
            var out: [TreeEntry] = []
            for (name, file) in items {
                out.append(TreeEntry(name: name, mode: file.mode, oid: file.oid))
            }
            for (name, sub) in subdirs {
                // Split subpaths into files-at-this-level and deeper dirs.
                var files: [String: (oid: ObjectID, mode: FileMode)] = [:]
                var deeper: [String: [String: (oid: ObjectID, mode: FileMode)]] = [:]
                for (rel, entry) in sub {
                    if let slash = rel.firstIndex(of: "/") {
                        let head = String(rel[..<slash])
                        let tail = String(rel[rel.index(after: slash)...])
                        deeper[head, default: [:]][tail] = entry
                    } else {
                        files[rel] = entry
                    }
                }
                let childEntries = try emitLevel(files, subdirs: deeper)
                let payload = TreePayload(entries: childEntries.sorted { sortKey($0) < sortKey($1) })
                let oid = try objects.write(.tree, value: payload)
                out.append(TreeEntry(name: name, mode: .directory, oid: oid))
            }
            return out.sorted { sortKey($0) < sortKey($1) }
        }

        var topFiles: [String: (oid: ObjectID, mode: FileMode)] = [:]
        var topDirs: [String: [String: (oid: ObjectID, mode: FileMode)]] = [:]
        for (path, entry) in listing {
            if let slash = path.firstIndex(of: "/") {
                let head = String(path[..<slash])
                let tail = String(path[path.index(after: slash)...])
                topDirs[head, default: [:]][tail] = entry
            } else {
                topFiles[path] = entry
            }
        }
        let top = try emitLevel(topFiles, subdirs: topDirs)
        return try objects.write(.tree, value: TreePayload(entries: top))
    }

    /// Empty-tree OID for an empty listing (canonical, deterministic).
    public static func emptyTree(objects: ObjectStore) throws -> ObjectID {
        try objects.write(.tree, value: TreePayload(entries: []))
    }

    /// Materializes a tree into the worktree: writes blobs, creates dirs,
    /// removes files not present in the tree. Returns list of written paths.
    /// Caller must hold the repo lock.
    @discardableResult
    public static func checkout(repo: Repository, treeOID: ObjectID,
                                removeUntracked: Bool = false) throws -> [String] {
        let flat = try flattenTree(repo: repo, treeOID: treeOID)
        var written: [String] = []
        let fm = FileManager.default

        // Remove tracked files absent from target tree.
        let index = try repo.index()
        for path in index.entries.keys where flat[path] == nil {
            let url = try repo.worktreeURL(forRelativePath: path)
            try? fm.removeItem(at: url)
            written.append(path)
        }

        for (path, entry) in flat {
            let url = try repo.worktreeURL(forRelativePath: path)
            try fm.createDirectory(at: url.deletingLastPathComponent(),
                                   withIntermediateDirectories: true)
            let data = try repo.blobData(entry.oid)
            if entry.mode.isSymlink {
                let target = String(decoding: data, as: UTF8.self)
                try? fm.removeItem(at: url)
                try fm.createSymbolicLink(atPath: url.path, withDestinationPath: target)
            } else {
                try data.write(to: url)
                if entry.mode == .executable {
                    try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
                }
            }
            written.append(path)
        }
        return written.sorted()
    }

    public static func flattenTree(repo: Repository, treeOID: ObjectID,
                                   prefix: String = "") throws -> [String: (oid: ObjectID, mode: FileMode)] {
        var result: [String: (oid: ObjectID, mode: FileMode)] = [:]
        for entry in try repo.treeEntries(treeOID) {
            let path = prefix.isEmpty ? entry.name : prefix + "/" + entry.name
            if entry.mode.isDirectory {
                result.merge(try flattenTree(repo: repo, treeOID: entry.oid, prefix: path)) { a, _ in a }
            } else {
                result[path] = (entry.oid, entry.mode)
            }
        }
        return result
    }
}
