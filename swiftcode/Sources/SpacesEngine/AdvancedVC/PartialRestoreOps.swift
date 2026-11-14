import Foundation

public struct PartialRestoreOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    @discardableResult
    public func restoreFrom(rev: String, paths: [String]) throws -> [String] {
        guard !paths.isEmpty else {
            throw SpacesError.invalidArgument("at least one path is required")
        }
        let oid = try repo.resolveRevision(rev)
        let commit = try repo.commitObject(oid)
        let flat = try TreeBuilder.flattenTree(repo: repo, treeOID: commit.tree)
        for path in paths {
            guard flat[path] != nil else {
                throw SpacesError.pathNotFound(path)
            }
        }
        return try repo.performTransaction(steps: ["partial-restore:\(rev)"]) {
            var restored: [String] = []
            var index = try repo.index()
            for path in paths {
                let entry = flat[path]!
                let data = try repo.blobData(entry.oid)
                let url = try repo.worktreeURL(forRelativePath: path)
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                        withIntermediateDirectories: true)
                if entry.mode.isSymlink {
                    let target = String(decoding: data, as: UTF8.self)
                    try? FileManager.default.removeItem(at: url)
                    try FileManager.default.createSymbolicLink(atPath: url.path, withDestinationPath: target)
                } else {
                    try data.write(to: url)
                    if entry.mode == .executable {
                        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
                    }
                }
                index.entries[path] = try Index.entry(forFileAt: url, oid: entry.oid, mode: entry.mode)
                restored.append(path)
            }
            try repo.saveIndex(index)
            return restored.sorted()
        }
    }
}
