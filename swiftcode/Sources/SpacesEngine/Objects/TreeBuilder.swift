import Foundation

public enum TreeBuilder {

    @discardableResult
    public static func writeTree(entries listing: [String: (oid: ObjectID, mode: FileMode)],
                                 objects: ObjectStore) throws -> ObjectID {
        func sortKey(_ e: TreeEntry) -> String { e.mode.isDirectory ? e.name + "/" : e.name }

        let paths = Set(listing.keys)
        for path in paths {
            let components = path.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
            guard !components.isEmpty, components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else {
                throw SpacesError.invalidArgument("invalid tree path '\(path)'")
            }
            var prefix = ""
            for component in components.dropLast() {
                prefix = prefix.isEmpty ? component : prefix + "/" + component
                if paths.contains(prefix) {
                    throw SpacesError.invalidObject("path '\(prefix)' is both a file and a directory")
                }
            }
        }

        func emitLevel(_ items: [String: (oid: ObjectID, mode: FileMode)],
                       subdirs: [String: [String: (oid: ObjectID, mode: FileMode)]]) throws -> [TreeEntry] {
            var out: [TreeEntry] = []
            for (name, file) in items {
                out.append(TreeEntry(name: name, mode: file.mode, oid: file.oid))
            }
            for (name, sub) in subdirs {
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

    public static func emptyTree(objects: ObjectStore) throws -> ObjectID {
        try objects.write(.tree, value: TreePayload(entries: []))
    }

    @discardableResult
    public static func checkout(repo: Repository, treeOID: ObjectID,
                                removeUntracked: Bool = false) throws -> [String] {
        let flat = try flattenTree(repo: repo, treeOID: treeOID)
        for path in flat.keys {
            guard !isMetadataPath(path) else {
                throw SpacesError.pathOutsideRepository(path)
            }
        }
        var written: [String] = []
        let fm = FileManager.default

        let index = try repo.index()
        for path in index.entries.keys where flat[path] == nil {
            let url = try repo.worktreeURL(forRelativePath: path)
            if !isDirectory(url) {
                try? fm.removeItem(at: url)
            }
            written.append(path)
        }

        if removeUntracked {
            let scanned = try WorktreeScanner(repo: repo).scan()
            let indexed = Set(index.entries.keys)
            for entry in scanned where flat[entry.relativePath] == nil && !indexed.contains(entry.relativePath) {
                if !isDirectory(entry.url) {
                    try? fm.removeItem(at: entry.url)
                }
                written.append(entry.relativePath)
            }
        }

        for (path, entry) in flat {
            let url = try repo.worktreeURL(forRelativePath: path)
            try assertNoSymlinkedParent(for: url, under: repo.worktreeURL)
            try fm.createDirectory(at: url.deletingLastPathComponent(),
                                   withIntermediateDirectories: true)
            let data = try repo.blobData(entry.oid)
            if fm.fileExists(atPath: url.path) {
                guard !isDirectory(url) else {
                    throw SpacesError.pathIsDirectory(url.path)
                }
                try fm.removeItem(at: url)
            }
            if entry.mode.isSymlink {
                guard let target = String(data: data, encoding: .utf8) else {
                    throw SpacesError.objectCorrupt("symlink \(path) target is not valid UTF-8")
                }
                try fm.createSymbolicLink(atPath: url.path, withDestinationPath: target)
            } else {
                try AtomicFileIO.writeAtomically(data, to: url)
                try fm.setAttributes([.posixPermissions: entry.mode == .executable ? 0o755 : 0o644],
                                     ofItemAtPath: url.path)
            }
            written.append(path)
        }

        var newIndex = Index()
        for (path, entry) in flat {
            let url = try repo.worktreeURL(forRelativePath: path)
            newIndex.entries[path] = try Index.entry(forFileAt: url, oid: entry.oid, mode: entry.mode)
        }
        try repo.saveIndex(newIndex)
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

    private static func isMetadataPath(_ path: String) -> Bool {
        path == RepositoryFormat.metadataDirectoryName
            || path.hasPrefix(RepositoryFormat.metadataDirectoryName + "/")
    }

    private static func isDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { return false }
        return isDir.boolValue
    }

    private static func assertNoSymlinkedParent(for url: URL, under worktree: URL) throws {
        let base = worktree.standardizedFileURL.pathComponents
        let parentComponents = url.standardizedFileURL.deletingLastPathComponent().pathComponents
        guard parentComponents.count >= base.count,
              Array(parentComponents.prefix(base.count)) == base else {
            throw SpacesError.pathOutsideRepository(url.path)
        }
        var current = worktree.standardizedFileURL
        for component in parentComponents.dropFirst(base.count) {
            current = current.appendingPathComponent(component)
            if let attrs = try? FileManager.default.attributesOfItem(atPath: current.path),
               (attrs[.type] as? FileAttributeType) == .typeSymbolicLink {
                throw SpacesError.pathOutsideRepository("refusing to write through symlinked directory \(current.path)")
            }
        }
    }
}
