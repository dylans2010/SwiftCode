import Foundation



public struct HistoryOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public struct CommitInfo: Sendable {
        public var oid: ObjectID
        public var parents: [ObjectID]
        public var author: Signature
        public var committer: Signature
        public var message: String
        public var summary: String
        public var timestamp: Int64
        
        public var refs: [String]
        public var isMerge: Bool { parents.count > 1 }
    }

    
    
    
    public func walk(start: ObjectID? = nil, firstParentOnly: Bool = false,
                     limit: Int = Int.max) throws -> [CommitInfo] {
        let startOID: ObjectID
        if let s = start {
            startOID = s
        } else if let h = try repo.refs.headOID(objects: repo.objects) {
            startOID = h
        } else {
            return []
        }

        
        var decorations: [ObjectID: [String]] = [:]
        for ref in try repo.refs.allRefs() {
            decorations[ref.oid, default: []].append(ref.shortName)
        }
        if let headOID = try repo.refs.headOID(objects: repo.objects),
           let branch = try repo.refs.currentBranch() {
            decorations[headOID, default: []].append("HEAD -> \(branch)")
        }

        var result: [CommitInfo] = []
        var visited = Set<ObjectID>()
        
        var queue: [(oid: ObjectID, commit: CommitPayload)] = []
        func push(_ oid: ObjectID) throws {
            guard visited.insert(oid).inserted else { return }
            let c = try repo.commitObject(oid)
            queue.append((oid, c))
        }
        try push(startOID)

        while !queue.isEmpty && result.count < limit {
            
            var best = 0
            for i in queue.indices where queue[i].1.committer.timestamp > queue[best].1.committer.timestamp {
                best = i
            }
            let item = queue.remove(at: best)
            let oid = item.oid, c = item.1
            result.append(CommitInfo(oid: oid, parents: c.parents, author: c.author,
                                     committer: c.committer, message: c.message,
                                     summary: c.summary, timestamp: c.committer.timestamp,
                                     refs: decorations[oid] ?? []))
            let parents = firstParentOnly ? Array(c.parents.prefix(1)) : c.parents
            for p in parents { try push(p) }
        }
        return result
    }

    
    public func log(firstParentOnly: Bool = false, limit: Int = 100,
                    all: Bool = false, path: String? = nil) throws -> [CommitInfo] {
        if all {
            
            var merged: [CommitInfo] = []
            var seen = Set<ObjectID>()
            for ref in try repo.refs.allRefs() where ref.kind == .branch || ref.kind == .tag {
                for c in try walk(start: ref.oid, limit: limit) where seen.insert(c.oid).inserted {
                    merged.append(c)
                }
            }
            merged.sort { $0.timestamp > $1.timestamp }
            return Array(merged.prefix(limit))
        }
        return try walk(firstParentOnly: firstParentOnly, limit: limit)
    }

    
    public struct ShowResult: Sendable {
        public var info: CommitInfo
        public var diffStat: (added: Int, removed: Int, files: Int)
        public var patch: String
    }

    public func show(_ rev: String = "HEAD") throws -> ShowResult {
        let oid = try repo.resolveRevision(rev)
        let info = try commitInfo(oid)
        let commit = try repo.commitObject(oid)
        var patch = ""
        var added = 0, removed = 0, files = 0
        if let parent = commit.parents.first {
            let parentTree = try repo.commitObject(parent).tree
            let diffs = try DiffOps(repo: repo).diffTrees(parentTree, commit.tree)
            for d in diffs {
                files += 1
                if let p = d.patch { patch += p }
                added += d.added; removed += d.removed
            }
        } else {
            
            let flat = try TreeBuilder.flattenTree(repo: repo, treeOID: commit.tree)
            files = flat.count
            for (path, e) in flat.sorted(by: { $0.key < $1.key }) {
                let data = try repo.blobData(e.oid)
                if DiffEngine.isBinary(data) {
                    patch += "diff --spaces a/\(path) b/\(path)\nBinary files differ\n"
                } else {
                    let lines = DiffEngine.splitLines(data)
                    added += lines.count
                    var body = "diff --spaces a/\(path) b/\(path)\nnew file\n"
                    body += "--- /dev/null\n+++ b/\(path)\n"
                    body += "@@ -0,0 +1,\(lines.count) @@\n"
                    for l in lines { body += "+\(l)\n" }
                    patch += body
                }
            }
        }
        return ShowResult(info: info, diffStat: (added, removed, files), patch: patch)
    }

    public func commitInfo(_ oid: ObjectID) throws -> CommitInfo {
        let c = try repo.commitObject(oid)
        var decorations: [String] = []
        for ref in try repo.refs.allRefs() where ref.oid == oid {
            decorations.append(ref.shortName)
        }
        return CommitInfo(oid: oid, parents: c.parents, author: c.author,
                          committer: c.committer, message: c.message,
                          summary: c.summary, timestamp: c.committer.timestamp,
                          refs: decorations)
    }

    
    public func describe() throws -> String {
        guard let head = try repo.refs.headOID(objects: repo.objects) else {
            throw SpacesError.branchNotFound("HEAD")
        }
        
        for tag in try repo.refs.tags() {
            if tag.oid == head {
                if let t = try? repo.tagObject(tag.oid), t.object == head {
                    return tag.shortName
                }
                return tag.shortName
            }
        }
        
        let history = try walk(limit: 10_000)
        for (i, c) in history.enumerated() {
            for tag in try repo.refs.tags() {
                var target = tag.oid
                if let t = try? repo.tagObject(tag.oid) { target = t.object }
                if target == c.oid {
                    return "\(tag.shortName)-\(i)-g\(String(c.oid.hex.prefix(7)))"
                }
            }
        }
        return "\(String(head.hex.prefix(7))) (no tags)"
    }

    
    public func mergeBase(_ a: ObjectID, _ b: ObjectID) throws -> ObjectID? {
        let ancestorsA = try ancestorSet(a)
        
        var queue = [b]
        var visited = Set<ObjectID>()
        while !queue.isEmpty {
            let oid = queue.removeFirst()
            guard visited.insert(oid).inserted else { continue }
            if ancestorsA.contains(oid) { return oid }
            queue.append(contentsOf: try repo.commitObject(oid).parents)
        }
        return nil
    }

    private func ancestorSet(_ start: ObjectID) throws -> Set<ObjectID> {
        var seen = Set<ObjectID>()
        var stack = [start]
        while let oid = stack.popLast() {
            guard seen.insert(oid).inserted else { continue }
            stack.append(contentsOf: try repo.commitObject(oid).parents)
        }
        return seen
    }

    
    public struct BlameLine: Sendable {
        public var line: String
        public var commit: ObjectID
        public var author: String
        public var timestamp: Int64
        public var final: Bool
    }

    public func blame(_ path: String, rev: String = "HEAD") throws -> [BlameLine] {
        let endOID = try repo.resolveRevision(rev)
        let endFlat = try TreeBuilder.flattenTree(
            repo: repo, treeOID: try repo.commitObject(endOID).tree)
        guard endFlat[path] != nil else { throw SpacesError.pathNotFound(path) }
        return try blameWithParents(path: path, endOID: endOID)
    }

    private func renamedPath(from parentOID: ObjectID, to childOID: ObjectID,
                             path: String) -> String {
        guard let parentCommit = try? repo.commitObject(parentOID),
              let childCommit = try? repo.commitObject(childOID),
              let diffs = try? DiffOps(repo: repo).diffTrees(parentCommit.tree, childCommit.tree) else {
            return path
        }
        for diff in diffs where diff.status == .renamed && diff.newPath == path {
            return diff.oldPath
        }
        return path
    }

    private func blameWithParents(path: String, endOID: ObjectID) throws -> [BlameLine] {
        var order: [ObjectID] = []
        var visited = Set<ObjectID>()
        var pathForCommit: [ObjectID: String] = [endOID: path]
        var stack: [(oid: ObjectID, expanded: Bool)] = [(endOID, false)]
        while let item = stack.popLast() {
            if item.expanded {
                order.append(item.oid)
                continue
            }
            guard visited.insert(item.oid).inserted else { continue }
            stack.append((item.oid, true))
            let commit = try repo.commitObject(item.oid)
            for parent in commit.parents.reversed() {
                if pathForCommit[parent] == nil,
                   let childPath = pathForCommit[item.oid] {
                    pathForCommit[parent] = renamedPath(from: parent, to: item.oid, path: childPath)
                }
                stack.append((parent, false))
            }
        }

        var remainingChildren: [ObjectID: Int] = [:]
        for oid in order {
            for parent in try repo.commitObject(oid).parents {
                remainingChildren[parent, default: 0] += 1
            }
        }

        var attributions: [ObjectID: [(oid: ObjectID, author: String, ts: Int64)]] = [:]
        var linesByCommit: [ObjectID: [String]] = [:]
        for oid in order {
            let commit = try repo.commitObject(oid)
            let lookupPath = pathForCommit[oid] ?? path
            let flat = try TreeBuilder.flattenTree(repo: repo, treeOID: commit.tree)
            let lines: [String]
            if let entry = flat[lookupPath] {
                lines = DiffEngine.splitLines(try repo.blobData(entry.oid))
            } else {
                lines = []
            }
            var attrs = lines.map { _ in
                (oid, commit.author.name, commit.author.timestamp)
            }
            var claimed = Array(repeating: false, count: lines.count)
            for parent in commit.parents {
                guard let parentLines = linesByCommit[parent],
                      let parentAttrs = attributions[parent],
                      !parentLines.isEmpty else { continue }
                let edits = DiffEngine.diff(parentLines, lines)
                for edit in edits {
                    if case .equal(let x, let y) = edit,
                       x < parentAttrs.count, y < attrs.count, !claimed[y] {
                        attrs[y] = parentAttrs[x]
                        claimed[y] = true
                    }
                }
            }
            attributions[oid] = attrs
            linesByCommit[oid] = lines
            for parent in commit.parents {
                remainingChildren[parent, default: 0] -= 1
                if remainingChildren[parent] == 0 {
                    attributions.removeValue(forKey: parent)
                    linesByCommit.removeValue(forKey: parent)
                }
            }
        }

        guard let finalLines = linesByCommit[endOID],
              let finalAttrs = attributions[endOID] else {
            throw SpacesError.pathNotFound(path)
        }
        return finalLines.indices.map { i in
            BlameLine(line: finalLines[i], commit: finalAttrs[i].oid,
                      author: finalAttrs[i].author, timestamp: finalAttrs[i].ts, final: true)
        }
    }
}
