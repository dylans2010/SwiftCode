import Foundation





public struct WorktreeOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public struct WorktreeInfo: Sendable {
        public var name: String
        public var path: String
        public var head: String 
        public var isMain: Bool
    }

    private var worktreesMetaDir: URL {
        repo.metaURL.appendingPathComponent("worktrees")
    }

    
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

    public struct ResolvedWorktree: Sendable {
        public var name: String
        public var path: String
        public var branch: String?
        public var headOID: String
    }

    public func resolve(_ target: String) throws -> ResolvedWorktree {
        let worktrees = try list()
        guard let wt = worktrees.first(where: { $0.name == target || $0.path == target }) else {
            throw SpacesError.invalidArgument("no registered worktree '\(target)'; registered worktrees: \(worktrees.map { $0.name }.joined(separator: ", "))")
        }
        let isOID = wt.head.count == 40 && wt.head.allSatisfy { $0.isHexDigit }
        let branch = (!isOID && wt.head != "(detached)") ? wt.head : nil
        var oid: String? = isOID ? wt.head : nil
        if oid == nil, let branch, let refOID = try? repo.refs.readRef("refs/heads/\(branch)"),
           let resolved = refOID {
            oid = resolved.hex
        }
        if oid == nil, wt.isMain {
            oid = try repo.refs.headOID(objects: repo.objects)?.hex
        }
        return ResolvedWorktree(name: wt.name, path: wt.path, branch: branch,
                                headOID: oid ?? "(unknown)")
    }

    
    
    @discardableResult
    public func add(path: String, branch: String? = nil,
                    newBranch: String? = nil) throws -> WorktreeInfo { return try repo.withLock {
        let target = URL(fileURLWithPath: path).standardizedFileURL
        if FileManager.default.fileExists(atPath: target.path) {
            guard (try? FileManager.default.contentsOfDirectory(atPath: target.path).isEmpty) == true else {
                throw SpacesError.invalidArgument("worktree path not empty: \(path)")
            }
        }
        
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

        
        let name = target.lastPathComponent
        let metaDir = worktreesMetaDir.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: metaDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)

        
        try Data("ref: refs/heads/\(branchName)\n".utf8)
            .write(to: metaDir.appendingPathComponent("HEAD"))
        try Data(repo.metaURL.path.utf8)
            .write(to: metaDir.appendingPathComponent("commondir"))
        try Data(target.path.utf8)
            .write(to: metaDir.appendingPathComponent("gitdir"))

        
        
        
        
        let commit = try repo.commitObject(oid)
        try checkoutInto(target, treeOID: commit.tree)

        return WorktreeInfo(name: name, path: target.path, head: branchName, isMain: false)
        }
    }

    
    
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

    
    public func remove(_ nameOrPath: String) throws { return try repo.withLock {
        let worktrees = try list()
        guard let wt = worktrees.first(where: {
            $0.name == nameOrPath || $0.path == nameOrPath
        }) else { throw SpacesError.pathNotFound(nameOrPath) }
        guard !wt.isMain else {
            throw SpacesError.invalidArgument("cannot remove the main worktree")
        }
        
        
        let target = URL(fileURLWithPath: wt.path)
        try? FileManager.default.removeItem(at: target)
        try? FileManager.default.removeItem(
            at: worktreesMetaDir.appendingPathComponent(wt.name))
        }
    }
}
