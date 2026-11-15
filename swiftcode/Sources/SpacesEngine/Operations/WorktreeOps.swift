import Crypto
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

    private func metaDirName(for worktreePath: URL) -> String {
        let digest = SHA256.hash(data: Data(worktreePath.standardizedFileURL.path.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return String(hex.prefix(16))
    }

    private func metaDir(for worktreePath: URL) -> URL {
        worktreesMetaDir.appendingPathComponent(metaDirName(for: worktreePath))
    }

    private func headOfWorktree(at path: String, registryDir: URL) -> String {
        let linkedHead = URL(fileURLWithPath: path)
            .appendingPathComponent(".spaces").appendingPathComponent("HEAD")
        if let text = try? String(contentsOf: linkedHead, encoding: .utf8) {
            let h = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !h.isEmpty {
                return h.hasPrefix("ref: refs/heads/")
                    ? String(h.dropFirst("ref: refs/heads/".count)) : h
            }
        }
        if let headFile = try? String(contentsOf: registryDir.appendingPathComponent("HEAD"),
                                      encoding: .utf8) {
            let h = headFile.trimmingCharacters(in: .whitespacesAndNewlines)
            return h.hasPrefix("ref: refs/heads/")
                ? String(h.dropFirst("ref: refs/heads/".count)) : h
        }
        return "(detached)"
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
            guard let location = try? String(contentsOf: locationFile, encoding: .utf8) else {
                try? FileManager.default.removeItem(at: metaDir)
                continue
            }
            let worktreePath = location.trimmingCharacters(in: .whitespacesAndNewlines)
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: worktreePath, isDirectory: &isDir),
                  isDir.boolValue else {
                try? FileManager.default.removeItem(at: metaDir)
                continue
            }
            let head = headOfWorktree(at: worktreePath, registryDir: metaDir)
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

    public func openWorktree(_ target: String) throws -> Repository {
        let resolved = try resolve(target)
        let worktree = try Repository(worktree: URL(fileURLWithPath: resolved.path))
        _ = try worktree.recoverIfNeeded()
        return worktree
    }

    public func checkedOutBranches() throws -> [String: String] {
        var result: [String: String] = [:]
        for wt in try list() where !wt.isMain {
            let isOID = wt.head.count == 40 && wt.head.allSatisfy { $0.isHexDigit }
            if !isOID, wt.head != "(detached)" {
                result[wt.head] = wt.name
            }
        }
        if let current = try repo.refs.currentBranch() {
            result[current] = "main"
        }
        return result
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
        let branchName: String?
        if let nb = newBranch {
            branchName = nb
            oid = try BranchOps(repo: repo).create(nb)
        } else if let b = branch {
            let checkedOut = try checkedOutBranches()
            if let holder = checkedOut[b] {
                throw SpacesError.invalidArgument(
                    "branch '\(b)' is already checked out in worktree '\(holder)'")
            }
            guard let o = try repo.refs.readRef("refs/heads/\(b)") else {
                throw SpacesError.branchNotFound(b)
            }
            branchName = b
            oid = o
        } else if let h = try repo.refs.headOID(objects: repo.objects) {
            branchName = nil
            oid = h
        } else {
            throw SpacesError.branchNotFound("HEAD (unborn)")
        }

        let registryDir = metaDir(for: target)
        try FileManager.default.createDirectory(at: registryDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)

        let linkedMeta = target.appendingPathComponent(".spaces")
        try FileManager.default.createDirectory(at: linkedMeta, withIntermediateDirectories: true)
        for shared in ["objects", "refs", "hooks", "worktrees", "stash.json", "lfs"] {
            let link = linkedMeta.appendingPathComponent(shared)
            if !FileManager.default.fileExists(atPath: link.path) {
                try FileManager.default.createSymbolicLink(
                    atPath: link.path,
                    withDestinationPath: repo.metaURL.appendingPathComponent(shared).path)
            }
        }
        let mainConfig = repo.metaURL.appendingPathComponent("config.json")
        if let configData = try? Data(contentsOf: mainConfig) {
            try configData.write(to: linkedMeta.appendingPathComponent("config.json"))
        }
        let headText: String
        if let branchName {
            headText = "ref: refs/heads/\(branchName)\n"
        } else {
            headText = oid.hex + "\n"
        }
        try Data(headText.utf8).write(to: linkedMeta.appendingPathComponent("HEAD"))
        try Data(repo.metaURL.path.utf8)
            .write(to: registryDir.appendingPathComponent("commondir"))
        try Data(target.path.utf8)
            .write(to: registryDir.appendingPathComponent("gitdir"))
        try Data(headText.utf8)
            .write(to: registryDir.appendingPathComponent("HEAD"))

        let commit = try repo.commitObject(oid)
        try checkoutInto(target, treeOID: commit.tree)
        let flat = try TreeBuilder.flattenTree(repo: repo, treeOID: commit.tree)
        var index = Index()
        for (path, e) in flat {
            let url = target.appendingPathComponent(path)
            index.entries[path] = try Index.entry(forFileAt: url, oid: e.oid, mode: e.mode)
        }
        try index.save(to: linkedMeta.appendingPathComponent("index"))

        return WorktreeInfo(name: metaDirName(for: target), path: target.path,
                            head: branchName ?? oid.hex, isMain: false)
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
