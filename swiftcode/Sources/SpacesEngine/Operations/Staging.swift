import Foundation

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif



public struct StagingOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    private let scanner = WorktreeScanner.self

    
    @discardableResult
    public func hashWorktreeFile(_ path: String) throws -> ObjectID {
        let url = try repo.worktreeURL(forRelativePath: path)
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else {
            throw SpacesError.pathNotFound(path)
        }
        guard !isDir.boolValue else { throw SpacesError.pathIsDirectory(path) }

        let fm = FileManager.default
        let attrs = try fm.attributesOfItem(atPath: url.path)
        let isSymlink = (attrs[.type] as? FileAttributeType) == .typeSymbolicLink
        let data: Data
        let mode: FileMode
        if isSymlink {
            let target = try fm.destinationOfSymbolicLink(atPath: url.path)
            data = Data(target.utf8)
            mode = .symlink
        } else {
            data = try Data(contentsOf: url)
            let perms = (attrs[.posixPermissions] as? Int) ?? 0o644
            mode = (perms & 0o111) != 0 ? .executable : .regular
        }
        let oid = try repo.objects.write(type: .blob, payload: data)

        var index = try repo.index()
        index.entries[path] = try Index.entry(forFileAt: url, oid: oid, mode: mode)
        try repo.saveIndex(index)
        markConflictResolved(path)
        return oid
    }

    
    
    func markConflictResolved(_ path: String) {
        let url = repo.metaURL.appendingPathComponent("conflicts.json")
        guard let data = try? Data(contentsOf: url),
              var records = try? JSONDecoder().decode([WorktreeScanner.ConflictRecord].self, from: data)
        else { return }
        var changed = false
        for i in records.indices where records[i].path == path && !records[i].resolved {
            records[i].resolved = true
            changed = true
        }
        guard changed else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try? encoder.encode(records).write(to: url)
    }

    
    
    
    @discardableResult
    public func add(_ pathSpec: String, all: Bool = false) throws -> [String] { return try repo.withLock {
        let index = try repo.index()
        var staged: [String] = []

        if all {
            
            let scanner = WorktreeScanner(repo: repo)
            let files = try scanner.scan()
            var present = Set<String>()
            for f in files {
                present.insert(f.relativePath)
                if index.entries[f.relativePath] == nil ||
                   !Index.statMatches(index.entries[f.relativePath]!, fileAt: f.url) {
                    _ = try hashWorktreeFile(f.relativePath)
                    staged.append(f.relativePath)
                }
            }
            
            var newIndex = try repo.index()
            for path in newIndex.entries.keys where !present.contains(path) {
                newIndex.entries.removeValue(forKey: path)
                staged.append(path)
            }
            try repo.saveIndex(newIndex)
            return staged.sorted()
        }

        
        let fm = FileManager.default
        let base = repo.worktreeURL.appendingPathComponent(pathSpec)
        var isDir: ObjCBool = false
        if fm.fileExists(atPath: base.path, isDirectory: &isDir) {
            if isDir.boolValue {
                
                let scanner = WorktreeScanner(repo: repo)
                let all = try scanner.scan()
                for f in all where f.relativePath == pathSpec || f.relativePath.hasPrefix(pathSpec + "/") {
                    _ = try hashWorktreeFile(f.relativePath)
                    staged.append(f.relativePath)
                }
            } else {
                _ = try hashWorktreeFile(pathSpec)
                staged.append(pathSpec)
            }
        } else {
            
            var idx = try repo.index()
            if idx.entries[pathSpec] != nil {
                idx.entries.removeValue(forKey: pathSpec)
                try repo.saveIndex(idx)
                staged.append(pathSpec)
            } else {
                throw SpacesError.pathNotFound(pathSpec)
            }
        }
        _ = fm
        return staged.sorted()
        }
    }

    
    public func remove(_ path: String, cachedOnly: Bool = false) throws { return try repo.withLock {
        var index = try repo.index()
        guard index.entries[path] != nil else { throw SpacesError.pathNotFound(path) }
        index.entries.removeValue(forKey: path)
        try repo.saveIndex(index)
        if !cachedOnly {
            _ = try? RecoveryVaultOps(repo: repo).vaultRetain(paths: [path], reason: "remove")
            let url = try repo.worktreeURL(forRelativePath: path)
            try? FileManager.default.removeItem(at: url)
        }
        }
    }

    
    public func move(_ old: String, _ new: String) throws { return try repo.withLock {
        var index = try repo.index()
        guard let entry = index.entries[old] else { throw SpacesError.pathNotFound(old) }
        let oldURL = try repo.worktreeURL(forRelativePath: old)
        let newURL = try repo.worktreeURL(forRelativePath: new)
        try FileManager.default.createDirectory(at: newURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: oldURL, to: newURL)
        index.entries.removeValue(forKey: old)
        index.entries[new] = entry
        try repo.saveIndex(index)
        }
    }

    
    public func unstage(_ path: String) throws { return try repo.withLock {
        var index = try repo.index()
        guard index.entries[path] != nil else { throw SpacesError.pathNotFound(path) }
        let headTree = try headFlattened()
        if let h = headTree[path] {
            
            let url = try repo.worktreeURL(forRelativePath: path)
            if FileManager.default.fileExists(atPath: url.path) {
                index.entries[path] = try Index.entry(forFileAt: url, oid: h.oid, mode: h.mode)
            } else {
                index.entries.removeValue(forKey: path)
            }
        } else {
            index.entries.removeValue(forKey: path)
        }
        try repo.saveIndex(index)
        }
    }

    
    
    public func restoreWorktree(_ path: String) throws { return try repo.withLock {
        let index = try repo.index()
        guard let entry = index.entries[path] else { throw SpacesError.pathNotFound(path) }
        let data = try repo.blobData(entry.oid)
        let url = try repo.worktreeURL(forRelativePath: path)
        _ = try? RecoveryVaultOps(repo: repo).vaultRetain(paths: [path], reason: "restore")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        if entry.mode.isSymlink {
            try? FileManager.default.removeItem(at: url)
            try FileManager.default.createSymbolicLink(
                atPath: url.path, withDestinationPath: String(decoding: data, as: UTF8.self))
        } else {
            try data.write(to: url)
            if entry.mode == .executable {
                try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
            }
        }
        }
    }

    
    @discardableResult
    public func clean(dryRun: Bool = false, directories: Bool = true) throws -> [String] { return try repo.withLock {
        let status = try WorktreeScanner(repo: repo).status()
        var removed: [String] = []
        for s in status.untrackedFiles {
            let url = try repo.worktreeURL(forRelativePath: s.path)
            if dryRun {
                removed.append(s.path)
            } else {
                _ = try? RecoveryVaultOps(repo: repo).vaultRetain(paths: [s.path], reason: "clean")
                try? FileManager.default.removeItem(at: url)
                removed.append(s.path)
            }
        }
        _ = directories
        return removed.sorted()
        }
    }

    

    
    public func writeIndexTree() throws -> ObjectID {
        var listing: [String: (oid: ObjectID, mode: FileMode)] = [:]
        let index = try repo.index()
        for (path, e) in index.entries {
            listing[path] = (e.oid, e.mode)
        }
        if listing.isEmpty { return try TreeBuilder.emptyTree(objects: repo.objects) }
        return try TreeBuilder.writeTree(entries: listing, objects: repo.objects)
    }

    public struct CommitResult {
        public var oid: ObjectID
        public var summary: String
        public var filesChanged: Int
    }

    @discardableResult
    public func commit(message: String, stageAll: Bool = false,
                       amend: Bool = false, author: Signature? = nil,
                       trailers: [String: String] = [:]) throws -> CommitResult {
        try commitCore(message: message, stageAll: stageAll, amend: amend, author: author,
                       trailers: trailers, metadata: CommitMetadata(trailers: trailers))
    }

    @discardableResult
    public func commitWithMetadata(message: String, metadata: CommitMetadata,
                                   stageAll: Bool = false, amend: Bool = false,
                                   author: Signature? = nil) throws -> CommitResult {
        try commitCore(message: message, stageAll: stageAll, amend: amend, author: author,
                       trailers: metadata.trailers, metadata: metadata)
    }

    public func writeScopedTree(paths: [String]) throws -> ObjectID {
        let index = try repo.index()
        let headFlat = try headFlattened()
        var scoped = headFlat
        for path in paths {
            if let entry = index.entries[path] {
                let headEntry = headFlat[path]
                guard entry.oid != headEntry?.oid || entry.mode != headEntry?.mode else {
                    throw SpacesError.invalidArgument("no staged change for \(path)")
                }
                scoped[path] = (entry.oid, entry.mode)
            } else {
                guard headFlat[path] != nil else {
                    throw SpacesError.invalidArgument("no staged change for \(path)")
                }
                scoped.removeValue(forKey: path)
            }
        }
        if scoped.isEmpty { return try TreeBuilder.emptyTree(objects: repo.objects) }
        return try TreeBuilder.writeTree(entries: scoped, objects: repo.objects)
    }

    @discardableResult
    public func commit(message: String, onlyPaths: [String]) throws -> CommitResult {
        try commitCore(message: message, onlyPaths: onlyPaths, metadata: CommitMetadata())
    }

    @discardableResult
    public func commitCore(message: String, stageAll: Bool = false,
                           amend: Bool = false, author: Signature? = nil,
                           trailers: [String: String] = [:],
                           metadata: CommitMetadata, onlyPaths: [String]? = nil) throws -> CommitResult {
        try repo.performTransaction(steps: ["commit"]) {
            if let only = onlyPaths {
                guard !amend else {
                    throw SpacesError.invalidArgument("scoped commit cannot amend")
                }
                guard !stageAll else {
                    throw SpacesError.invalidArgument("scoped commit cannot stage all files")
                }
                guard !only.isEmpty else {
                    throw SpacesError.invalidArgument("at least one path is required")
                }
                guard !repo.inMerge() else {
                    throw SpacesError.invalidArgument("cannot finalize a scoped staged commit while a merge is in progress")
                }
            }

            if amend && repo.inMerge() {
                throw SpacesError.invalidArgument("cannot amend a merge in progress")
            }

            var index = try repo.index()
            if stageAll {
                _ = try add(".", all: true)
                index = try repo.index()
            }

            var parents: [ObjectID] = []
            var headOID: ObjectID? = nil
            if amend {
                guard let head = try repo.refs.headOID(objects: repo.objects) else {
                    throw SpacesError.nothingToCommit
                }
                headOID = head
                parents = try repo.commitObject(head).parents
            } else {
                if let head = try repo.refs.headOID(objects: repo.objects) {
                    parents.append(head)
                }
                if repo.inMerge(), let mergeHead = repo.readState("MERGE_HEAD"),
                   let oid = try? ObjectID(validating: mergeHead.trimmingCharacters(in: .whitespacesAndNewlines)) {
                    parents.append(oid)
                }
            }

            let treeOID: ObjectID
            if let only = onlyPaths {
                treeOID = try writeScopedTree(paths: only)
            } else {
                treeOID = try writeIndexTree()
            }

            let isEmptyRoot = parents.isEmpty && index.entries.isEmpty
            var unchangedFromHead = false
            if parents.count == 1,
               let headCommit = try? repo.commitObject(parents[0]) {
                unchangedFromHead = headCommit.tree == treeOID
            }
            if !amend, trailers["allow-empty"] == nil,
               isEmptyRoot || unchangedFromHead {
                throw SpacesError.nothingToCommit
            }

            var changed = 0
            let newFlat = try TreeBuilder.flattenTree(repo: repo, treeOID: treeOID)
            if let first = parents.first {
                let oldFlat = try TreeBuilder.flattenTree(repo: repo, treeOID: repo.commitObject(first).tree)
                changed = Set(oldFlat.keys).union(newFlat.keys).filter { oldFlat[$0]?.oid != newFlat[$0]?.oid }.count
            } else {
                changed = newFlat.count
            }

            try runHook(.preCommit, input: message)

            let ident = repo.identity()
            let meta = metadata
            let payload = CommitPayload(tree: treeOID, parents: parents,
                                        author: author ?? ident, committer: ident,
                                        message: message, metadata: meta)
            let oid = try repo.objects.write(.commit, value: payload)

            let oldHead = try repo.refs.headOID(objects: repo.objects)
            if let sym = try repo.refs.symbolicHEAD() {
                let old = try repo.refs.updateRef(sym, to: oid)
                try repo.appendReflog(refName: sym, old: old, new: oid,
                                      message: amend ? "commit (amend)" : "commit: \(payload.summary)")
            } else {
                try repo.refs.setHEAD(oid: oid)
            }
            _ = oldHead; _ = headOID

            if repo.inMerge() && parents.count > 1 {
                repo.clearState(["MERGE_HEAD", "MERGE_MSG", "MERGE_MODE", "conflicts.json"])
                try? FileManager.default.removeItem(at: repo.metaURL.appendingPathComponent("rebase-merge"))
            }

            try runHook(.postCommit, input: message)

            return CommitResult(oid: oid, summary: payload.summary, filesChanged: changed)
        }
    }

    
    @discardableResult
    public func amend(message: String? = nil, stageAll: Bool = true) throws -> CommitResult {
        var msg = message
        if msg == nil, let head = try repo.refs.headOID(objects: repo.objects) {
            msg = try repo.commitObject(head).message
        }
        return try commit(message: msg ?? "", stageAll: stageAll, amend: true)
    }

    

    func headFlattened() throws -> [String: (oid: ObjectID, mode: FileMode)] {
        guard let head = try repo.headCommit() else { return [:] }
        return try TreeBuilder.flattenTree(repo: repo, treeOID: head.tree)
    }

    

    public enum HookEvent: String, Sendable {
        case preCommit = "pre-commit"
        case postCommit = "post-commit"
        case prePush = "pre-push"
        case postPush = "post-push"
        case preMerge = "pre-merge"
        case postMerge = "post-merge"
        case preRebase = "pre-rebase"
        case postCheckout = "post-checkout"
        case postRewrite = "post-rewrite"
    }

    
    
    @discardableResult
    public func runHook(_ event: HookEvent, input: String = "",
                        timeout: TimeInterval = 30) throws -> (code: Int32, output: String)? {
        let hookURL = repo.metaURL.appendingPathComponent("hooks").appendingPathComponent(event.rawValue)
        guard FileManager.default.isExecutableFile(atPath: hookURL.path) else { return nil }
        let process = Process()
        process.executableURL = hookURL
        process.currentDirectoryURL = repo.worktreeURL
        let inPipe = Pipe(), outPipe = Pipe(), errPipe = Pipe()
        process.standardInput = inPipe
        process.standardOutput = outPipe
        process.standardError = errPipe
        try process.run()
        let outLock = NSLock()
        let errLock = NSLock()
        var outData = Data()
        var errData = Data()
        outPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }
            outLock.lock()
            outData.append(chunk)
            outLock.unlock()
        }
        errPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }
            errLock.lock()
            errData.append(chunk)
            errLock.unlock()
        }
        DispatchQueue.global(qos: .utility).async {
            inPipe.fileHandleForWriting.write(Data(input.utf8))
            try? inPipe.fileHandleForWriting.close()
        }
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if process.isRunning {
            process.terminate()
            let killDeadline = Date().addingTimeInterval(2)
            while process.isRunning && Date() < killDeadline {
                Thread.sleep(forTimeInterval: 0.05)
            }
            if process.isRunning {
                kill(process.processIdentifier, SIGKILL)
                process.waitUntilExit()
            }
            outPipe.fileHandleForReading.readabilityHandler = nil
            errPipe.fileHandleForReading.readabilityHandler = nil
            throw SpacesError.hookFailed(event.rawValue, -1,
                                        "hook '\(event.rawValue)' timed out after \(Int(timeout))s")
        }
        process.waitUntilExit()
        Thread.sleep(forTimeInterval: 0.1)
        outPipe.fileHandleForReading.readabilityHandler = nil
        errPipe.fileHandleForReading.readabilityHandler = nil
        outLock.lock()
        let out = String(decoding: outData, as: UTF8.self)
        outLock.unlock()
        errLock.lock()
        let err = String(decoding: errData, as: UTF8.self)
        errLock.unlock()
        if process.terminationStatus != 0 {
            throw SpacesError.hookFailed(event.rawValue, process.terminationStatus,
                                       (err + out).trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return (process.terminationStatus, out)
    }
}
