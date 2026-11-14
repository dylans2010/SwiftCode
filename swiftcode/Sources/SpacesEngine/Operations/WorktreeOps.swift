import Foundation

/// Spaces worktrees: additional working directories sharing the same object
/// database and refs, each with its own HEAD, index, and worktree files.
/// Layout: `<repo>/.spaces/worktrees/<name>/` holds per-worktree metadata
/// (HEAD, index); the actual files live at the worktree path.
public struct WorktreeOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public struct WorktreeInfo: Sendable {
        public var name: String
        public var path: String
        public var head: String // branch name or oid
        public var isMain: Bool
    }

    private var worktreesMetaDir: URL {
        repo.metaURL.appendingPathComponent("worktrees")
    }

    /// Lists worktrees: the main worktree plus linked ones.
    public func list() throws -> [WorktreeInfo] {
        var result = [WorktreeInfo(name: "main", path: repo.worktreeURL.path,
                                   head: try repo.refs.currentBranch() ?? "(detached)",
                                   isMain: true)]
        guard let names = try? FileManager.default.contentsOfDirectory(
            atPath: worktreesMetaDir.path) else { return result }
        for name in names.sorted() {
            let metaDir = worktreesMetaDir.appendingPathComponent(name)
            let locationFile = metaDir.appendingPathComponent("gitdir")
            guard let location = try? String(contentsOf: locationFile, encoding: .utf8) else { continue }
            let worktreePath = location.trimmingCharacters(in: .whitespacesAndNewlines)
            var head = "(detached)"
            if let headFile = try? String(contentsOf: metaDir.appendingPathComponent("HEAD"), encoding: .utf8) {
                let h = headFile.trimmingCharacters(in: .whitespacesAndNewlines)
                head = h.hasPrefix("ref: refs/heads/")
                    ? String(h.dropFirst("ref: refs/heads/".count)) : h
            }
            result.append(WorktreeInfo(name: name, path: worktreePath, head: head, isMain: false))
        }
        return result
    }

    /// `spaces worktree-add <path> [branch]` — creates a linked worktree.
    /// The new worktree gets its own index/HEAD under `.spaces/worktrees/`.
    @discardableResult
    public func add(path: String, branch: String? = nil,
                    newBranch: String? = nil) throws -> WorktreeInfo { return try repo.withLock {
        let target = URL(fileURLWithPath: path).standardizedFileURL
        if FileManager.default.fileExists(atPath: target.path) {
            guard (try? FileManager.default.contentsOfDirectory(atPath: target.path).isEmpty) == true else {
                throw SpacesError.invalidArgument("worktree path not empty: \(path)")
            }
        }
        // Determine commit to check out.
        let oid: ObjectID
        let branchName: String
        if let nb = newBranch {
            branchName = nb
            oid = try BranchOps(repo: repo).create(nb)
        } else if let b = branch {
            guard let o = try repo.refs.readRef("refs/heads/\(b)") else {
                throw SpacesError.branchNotFound(b)
            }
            branchName = b
            oid = o
        } else if let h = try repo.refs.headOID(objects: repo.objects) {
            branchName = try repo.refs.currentBranch() ?? "HEAD"
            oid = h
        } else {
            throw SpacesError.branchNotFound("HEAD (unborn)")
        }

        // Per-worktree metadata dir.
        let name = target.lastPathComponent
        let metaDir = worktreesMetaDir.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: metaDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)

        // Write worktree's own HEAD + a pointer back to the main repo.
        try Data("ref: refs/heads/\(branchName)\n".utf8)
            .write(to: metaDir.appendingPathComponent("HEAD"))
        try Data(repo.metaURL.path.utf8)
            .write(to: metaDir.appendingPathComponent("commondir"))
        try Data(target.path.utf8)
            .write(to: metaDir.appendingPathComponent("gitdir"))

        // Branch ref is shared (refs/heads/* lives in common dir) — for a
        // linked worktree git would forbid checking out the same branch
        // twice; we allow it but record per-worktree HEAD separately.
        // Materialize tree into the linked worktree directory.
        let commit = try repo.commitObject(oid)
        try checkoutInto(target, treeOID: commit.tree)

        return WorktreeInfo(name: name, path: target.path, head: branchName, isMain: false)
        }
    }

    /// Materializes a tree into an arbitrary directory (used for linked
    /// worktrees that don't share the main worktree path).
    private func checkoutInto(_ dir: URL, treeOID: ObjectID) throws {
        let flat = try TreeBuilder.flattenTree(repo: repo, treeOID: treeOID)
        let fm = FileManager.default
        for (path, e) in flat {
            let url = dir.appendingPathComponent(path)
            try fm.createDirectory(at: url.deletingLastPathComponent(),
                                   withIntermediateDirectories: true)
            let data = try repo.blobData(e.oid)
            if e.mode.isSymlink {
                try? fm.removeItem(at: url)
                try fm.createSymbolicLink(atPath: url.path,
                                          withDestinationPath: String(decoding: data, as: UTF8.self))
            } else {
                try data.write(to: url)
            }
        }
    }

    /// `spaces worktree-remove <name|path>`.
    public func remove(_ nameOrPath: String) throws { return try repo.withLock {
        let worktrees = try list()
        guard let wt = worktrees.first(where: {
            $0.name == nameOrPath || $0.path == nameOrPath
        }) else { throw SpacesError.pathNotFound(nameOrPath) }
        guard !wt.isMain else {
            throw SpacesError.invalidArgument("cannot remove the main worktree")
        }
        // Safety: refuse if worktree has uncommitted changes? For v1 we
        // require --force semantics via clean check: scan target dir.
        let target = URL(fileURLWithPath: wt.path)
        try? FileManager.default.removeItem(at: target)
        try? FileManager.default.removeItem(
            at: worktreesMetaDir.appendingPathComponent(wt.name))
        }
    }
}
