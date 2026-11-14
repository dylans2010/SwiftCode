import Foundation

/// History traversal: log walking (first-parent/all/graph data), commit show,
/// describe, ancestry, blame.
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
        /// Refs pointing at this commit (branches, tags, HEAD).
        public var refs: [String]
        public var isMerge: Bool { parents.count > 1 }
    }

    /// Walks history from `start` (default HEAD) following all parents (or
    /// first-parent only). Yields commits in reverse chronological order
    /// (commit timestamp desc, ties by insertion).
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

        // Collect ref tips for decoration.
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
        // Priority by committer timestamp.
        var queue: [(oid: ObjectID, commit: CommitPayload)] = []
        func push(_ oid: ObjectID) throws {
            guard visited.insert(oid).inserted else { return }
            let c = try repo.commitObject(oid)
            queue.append((oid, c))
        }
        try push(startOID)

        while !queue.isEmpty && result.count < limit {
            // Pop max timestamp.
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

    /// `spaces log` entry point.
    public func log(firstParentOnly: Bool = false, limit: Int = 100,
                    all: Bool = false, path: String? = nil) throws -> [CommitInfo] {
        if all {
            // Walk from every ref tip.
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

    /// `spaces show <rev>` — commit metadata + diff stat vs first parent.
    public struct ShowResult {
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
            // Root commit: everything added.
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

    /// `spaces describe` — nearest tag reachable from HEAD plus distance.
    public func describe() throws -> String {
        guard let head = try repo.refs.headOID(objects: repo.objects) else {
            throw SpacesError.branchNotFound("HEAD")
        }
        // Exact tag match?
        for tag in try repo.refs.tags() {
            if tag.oid == head {
                if let t = try? repo.tagObject(tag.oid), t.object == head {
                    return tag.shortName
                }
                return tag.shortName
            }
        }
        // Walk history for annotated tag targets.
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

    /// `spaces ancestry <a> <b>` — merge base of two commits.
    public func mergeBase(_ a: ObjectID, _ b: ObjectID) throws -> ObjectID? {
        let ancestorsA = try ancestorSet(a)
        // BFS from b, first hit in ancestorsA.
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

    /// `spaces blame <path> [rev]` — line-level authorship.
    public struct BlameLine {
        public var line: String
        public var commit: ObjectID
        public var author: String
        public var timestamp: Int64
        public var final: Bool
    }

    public func blame(_ path: String, rev: String = "HEAD") throws -> [BlameLine] {
        let endOID = try repo.resolveRevision(rev)
        return try preciseBlame(path: path, endOID: endOID)
    }

    /// Builds the first-parent commit chain (newest→oldest) and delegates to
    /// the forward attribution pass.
    private func preciseBlame(path: String, endOID: ObjectID) throws -> [BlameLine] {
        var commits: [(oid: ObjectID, payload: CommitPayload)] = []
        var current = endOID
        while true {
            let p = try repo.commitObject(current)
            commits.append((current, p))
            guard let parent = p.parents.first else { break }
            current = parent
        }
        return try blameForward(commits: commits, path: path, endOID: endOID)
    }

    /// Forward blame: oldest→newest, each line carries (oid, author, ts).
    /// Lines added by a commit get that commit's attribution; carried lines
    /// keep theirs.
    private func blameForward(commits: [(oid: ObjectID, payload: CommitPayload)],
                              path: String, endOID: ObjectID) throws -> [BlameLine] {
        func content(_ c: (oid: ObjectID, payload: CommitPayload)) throws -> (lines: [String], present: Bool) {
            let flat = try TreeBuilder.flattenTree(repo: repo, treeOID: c.payload.tree)
            guard let e = flat[path] else { return ([], false) }
            return (DiffEngine.splitLines(try repo.blobData(e.oid)), true)
        }

        // Oldest commit first.
        var ordered = commits.reversed() // oldest→newest
        guard var current = ordered.first else { return [] }
        var (lines, present) = try content(current)
        guard present else { throw SpacesError.pathNotFound(path) }
        var attrs = lines.map { _ in
            (current.oid, current.payload.author.name, current.payload.author.timestamp)
        }

        for next in ordered.dropFirst() {
            let (newLines, newPresent) = try content(next)
            guard newPresent else { break } // file deleted; stop
            let edits = DiffEngine.diff(lines, newLines)
            // Edits carry absolute indices, so direct assignment works.
            var newAttrs = Array(repeating: (oid: next.oid,
                                             author: next.payload.author.name,
                                             ts: next.payload.author.timestamp),
                                 count: newLines.count)
            var seen = Array(repeating: false, count: newLines.count)
            for e in edits {
                switch e {
                case .equal(let x, let y):
                    if x < attrs.count && y < newAttrs.count {
                        newAttrs[y] = attrs[x]
                        seen[y] = true
                    }
                case .insert(let y):
                    if y < newAttrs.count {
                        newAttrs[y] = (next.oid, next.payload.author.name,
                                       next.payload.author.timestamp)
                        seen[y] = true
                    }
                case .delete:
                    break
                }
            }
            // Any line not covered by an edit keeps the newer commit's
            // attribution (defensive; shouldn't happen with a correct diff).
            for i in newAttrs.indices where !seen[i] {
                newAttrs[i] = (next.oid, next.payload.author.name, next.payload.author.timestamp)
            }
            lines = newLines
            attrs = newAttrs
            current = next
        }

        return lines.indices.map { i in
            BlameLine(line: lines[i], commit: attrs[i].0, author: attrs[i].1,
                      timestamp: attrs[i].2, final: true)
        }
    }
}
