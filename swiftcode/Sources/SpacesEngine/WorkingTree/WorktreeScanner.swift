import Foundation







public struct WorktreeScanner: Sendable {
    public let repo: Repository

    public init(repo: Repository) { self.repo = repo }

    
    public struct FileEntry: Sendable {
        public var relativePath: String
        public var url: URL
        public var isDirectory: Bool
        public var isSymlink: Bool
        public var size: Int64
        public var mode: FileMode
    }

    
    
    public func scan() throws -> [FileEntry] {
        var results: [FileEntry] = []
        var engine = IgnoreEngine.loadRootRules(worktree: repo.worktreeURL)
        try scanDirectory(repo.worktreeURL, prefix: "", engine: &engine, into: &results)
        return results.sorted { $0.relativePath < $1.relativePath }
    }

    private func scanDirectory(_ dir: URL, prefix: String,
                               engine: inout IgnoreEngine,
                               into results: inout [FileEntry]) throws {
        let contents = try FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey],
            options: [.skipsHiddenFiles])
        
        
        
        
        let all = (try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey],
            options: [])) ?? []
        _ = contents
        for url in all {
            let name = url.lastPathComponent
            let rel = prefix.isEmpty ? name : prefix + "/" + name
            if IgnoreEngine.isAlwaysIgnored(rel) { continue }

            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey])
            let isSymlink = values?.isSymbolicLink ?? false
            let isDir = (values?.isDirectory ?? false) && !isSymlink

            
            var localEngine = engine
            if !isDir, (name == RepositoryFormat.gitignoreFileName || name == RepositoryFormat.ignoreFileName) {
                
                
                
            }
            if isDir {
                
                if engine.isIgnored(rel, isDirectory: true) { continue }
                
                var nested = localEngine
                for ignoreName in [RepositoryFormat.gitignoreFileName, RepositoryFormat.ignoreFileName] {
                    let ignoreURL = url.appendingPathComponent(ignoreName)
                    if FileManager.default.fileExists(atPath: ignoreURL.path) {
                        nested.addFile(at: ignoreURL, relativeTo: repo.worktreeURL)
                    }
                }
                try scanDirectory(url, prefix: rel, engine: &nested, into: &results)
            } else {
                if engine.isIgnored(rel, isDirectory: false) { continue }
                let mode: FileMode = isSymlink ? .symlink : .regular
                let size = Int64(values?.fileSize ?? 0)
                results.append(FileEntry(relativePath: rel, url: url,
                                         isDirectory: false, isSymlink: isSymlink,
                                         size: size, mode: mode))
            }
        }
    }

    
    
    public func hashEntry(_ entry: FileEntry) throws -> (oid: ObjectID, mode: FileMode) {
        if entry.isSymlink {
            let target = try FileManager.default.destinationOfSymbolicLink(atPath: entry.url.path)
            let oid = try repo.objects.write(type: .blob, payload: Data(target.utf8))
            return (oid, .symlink)
        }
        
        let attrs = try FileManager.default.attributesOfItem(atPath: entry.url.path)
        let perms = (attrs[.posixPermissions] as? Int) ?? 0o644
        let mode: FileMode = (perms & 0o111) != 0 ? .executable : .regular
        let data = try Data(contentsOf: entry.url)
        let oid = try repo.objects.write(type: .blob, payload: data)
        return (oid, mode)
    }

    

    public enum ChangeKind: String, Sendable {
        case added, modified, deleted, renamed, untracked, typechanged
    }

    public struct FileStatus: Sendable {
        public var path: String
        public var indexStatus: ChangeKind?   
        public var worktreeStatus: ChangeKind? 
        public var oldPath: String?

        public var isStaged: Bool { indexStatus != nil && indexStatus != .untracked }
        public var isUnstaged: Bool { worktreeStatus != nil }
        public var isUntracked: Bool { indexStatus == .untracked || (indexStatus == nil && worktreeStatus == .untracked) }
    }

    public struct StatusReport: Sendable {
        public var entries: [FileStatus]
        public var branch: String?
        public var headOID: ObjectID?
        public var ahead: Int = 0
        public var behind: Int = 0
        public var inMerge: Bool
        public var inRebase: Bool
        public var unmerged: [String] = []

        public var staged: [FileStatus] { entries.filter { $0.isStaged } }
        public var unstaged: [FileStatus] { entries.filter { $0.isUnstaged && !$0.isUntracked } }
        public var untrackedFiles: [FileStatus] { entries.filter { $0.indexStatus == .untracked } }
        public var isClean: Bool { entries.allSatisfy { !$0.isStaged && !$0.isUnstaged && $0.indexStatus != .untracked } }
    }

    
    public func flattenTree(_ treeOID: ObjectID, prefix: String = "") throws -> [String: (oid: ObjectID, mode: FileMode)] {
        var result: [String: (oid: ObjectID, mode: FileMode)] = [:]
        for entry in try repo.treeEntries(treeOID) {
            let path = prefix.isEmpty ? entry.name : prefix + "/" + entry.name
            if entry.mode.isDirectory {
                result.merge(try flattenTree(entry.oid, prefix: path)) { a, _ in a }
            } else {
                result[path] = (entry.oid, entry.mode)
            }
        }
        return result
    }

    
    
    
    public func status() throws -> StatusReport {
        let index = try repo.index()
        let headTree: [String: (oid: ObjectID, mode: FileMode)]
        if let head = try repo.headCommit() {
            headTree = try flattenTree(head.tree)
        } else {
            headTree = [:]
        }

        
        
        var statuses: [FileStatus] = []
        let scanned = try scan()

        
        var stagedPaths = Set<String>()
        let allIndexPaths = Set(index.entries.keys)
        let allHeadPaths = Set(headTree.keys)
        for path in allIndexPaths {
            let ie = index.entries[path]!
            if let h = headTree[path] {
                if h.oid != ie.oid || h.mode != ie.mode {
                    statuses.append(FileStatus(path: path, indexStatus: .modified, worktreeStatus: nil))
                    stagedPaths.insert(path)
                }
            } else {
                statuses.append(FileStatus(path: path, indexStatus: .added, worktreeStatus: nil))
                stagedPaths.insert(path)
            }
        }
        for path in allHeadPaths where !allIndexPaths.contains(path) {
            statuses.append(FileStatus(path: path, indexStatus: .deleted, worktreeStatus: nil))
            stagedPaths.insert(path)
        }

        
        var seen = Set<String>()
        for entry in scanned {
            let path = entry.relativePath
            seen.insert(path)
            if let ie = index.entries[path] {
                
                let needsHash = !Index.statMatches(ie, fileAt: entry.url)
                if needsHash {
                    let (oid, mode) = try hashEntry(entry)
                    if oid != ie.oid || mode != ie.mode {
                        if !stagedPaths.contains(path) {
                            statuses.append(FileStatus(path: path, indexStatus: nil, worktreeStatus: .modified))
                        } else {
                            
                            if let i = statuses.firstIndex(where: { $0.path == path }) {
                                statuses[i].worktreeStatus = .modified
                            }
                        }
                    }
                }
            } else {
                
                statuses.append(FileStatus(path: path, indexStatus: .untracked, worktreeStatus: nil))
            }
        }

        
        for path in allIndexPaths where !seen.contains(path) {
            
            if let i = statuses.firstIndex(where: { $0.path == path && $0.indexStatus == .deleted }) {
                continue
            }
            statuses.append(FileStatus(path: path, indexStatus: nil, worktreeStatus: .deleted))
        }

        
        statuses = applyRenameDetection(statuses, index: index, headTree: headTree)

        
        var ahead = 0, behind = 0
        if let sym = try repo.refs.symbolicHEAD(),
           let upstream = repo.config.branchTracking[String(sym.dropFirst("refs/heads/".count))],
           let slash = upstream.firstIndex(of: "/") {
            let remote = String(upstream[..<slash])
            let branch = String(upstream[upstream.index(after: slash)...])
            let upstreamRef = "refs/remotes/\(remote)/\(branch)"
            if let upOID = try repo.refs.readRef(upstreamRef),
               let headOID = try repo.refs.headOID(objects: repo.objects) {
                let (a, b) = try countAheadBehind(head: headOID, upstream: upOID)
                ahead = a; behind = b
            }
        }

        
        var unmerged: [String] = []
        if repo.inMerge() || repo.inCherryPick() {
            unmerged = try conflictedPaths()
        }

        return StatusReport(entries: statuses.sorted { $0.path < $1.path },
                            branch: try repo.refs.currentBranch(),
                            headOID: try repo.refs.headOID(objects: repo.objects),
                            ahead: ahead, behind: behind,
                            inMerge: repo.inMerge(), inRebase: repo.inRebase(),
                            unmerged: unmerged)
    }

    
    public func conflictedPaths() throws -> [String] {
        
        let url = repo.metaURL.appendingPathComponent("conflicts.json")
        guard let data = try? Data(contentsOf: url),
              let arr = try? JSONDecoder().decode([ConflictRecord].self, from: data) else { return [] }
        return arr.filter { !$0.resolved }.map { $0.path }
    }

    public struct ConflictRecord: Codable, Sendable {
        public var path: String
        public var resolved: Bool
        public var ours: String?
        public var theirs: String?
        public var base: String?
    }

    
    
    public func countAheadBehind(head: ObjectID, upstream: ObjectID) throws -> (ahead: Int, behind: Int) {
        func ancestors(of start: ObjectID) throws -> Set<ObjectID> {
            var seen = Set<ObjectID>()
            var stack = [start]
            while let oid = stack.popLast() {
                guard seen.insert(oid).inserted else { continue }
                let commit = try repo.commitObject(oid)
                stack.append(contentsOf: commit.parents)
            }
            return seen
        }
        let headAncestors = try ancestors(of: head)
        let upAncestors = try ancestors(of: upstream)
        return (headAncestors.subtracting(upAncestors).count,
                upAncestors.subtracting(headAncestors).count)
    }

    
    
    private func applyRenameDetection(_ statuses: [FileStatus], index: Index,
                                      headTree: [String: (oid: ObjectID, mode: FileMode)]) -> [FileStatus] {
        var result = statuses
        var consumed = Set<Int>()
        
        var addsByOID: [ObjectID: [Int]] = [:]
        for (i, s) in result.enumerated() where s.indexStatus == .added {
            if let oid = index.entries[s.path]?.oid { addsByOID[oid, default: []].append(i) }
        }
        for (i, s) in result.enumerated() where s.indexStatus == .deleted {
            guard let h = headTree[s.path],
                  var candidates = addsByOID[h.oid], !candidates.isEmpty else { continue }
            let addIndex = candidates.removeFirst()
            guard !consumed.contains(addIndex) else { continue }
            consumed.insert(addIndex)
            result[i].indexStatus = .renamed
            result[i].oldPath = result[i].path
            result[i].path = result[addIndex].path
        }
        return result.enumerated().compactMap { consumed.contains($0.offset) ? nil : $0.element }
            .sorted { $0.path < $1.path }
    }
}
