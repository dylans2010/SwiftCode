import Foundation

/// Diff operations: worktree↔index, index↔HEAD, commit↔commit, tree↔tree,
/// patch generation and application.
public struct DiffOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public struct FileDiff: Sendable {
        public var oldPath: String
        public var newPath: String
        public var oldOID: ObjectID?
        public var newOID: ObjectID?
        public var oldMode: FileMode?
        public var newMode: FileMode?
        public var status: StatusKind
        public var isBinary: Bool
        public var added: Int
        public var removed: Int
        public var patch: String?

        public enum StatusKind: String, Sendable {
            case added, deleted, modified, renamed, typechanged
        }
    }

    /// Diffs two flattened trees. Rename detection pairs delete+add with
    /// identical OIDs.
    public func diffTrees(_ oldTree: ObjectID, _ newTree: ObjectID) throws -> [FileDiff] {
        let oldFlat = try TreeBuilder.flattenTree(repo: repo, treeOID: oldTree)
        let newFlat = try TreeBuilder.flattenTree(repo: repo, treeOID: newTree)
        return try diffFlats(oldFlat, newFlat)
    }

    public func diffFlats(_ oldFlat: [String: (oid: ObjectID, mode: FileMode)],
                          _ newFlat: [String: (oid: ObjectID, mode: FileMode)]) throws -> [FileDiff] {
        var diffs: [FileDiff] = []
        var consumedNew = Set<String>()

        // Detect renames: deleted old paths whose OID appears in added new paths.
        var addedByOID: [ObjectID: [String]] = [:]
        for (path, e) in newFlat where oldFlat[path] == nil {
            addedByOID[e.oid, default: []].append(path)
        }
        var renamePairs: [String: String] = [:] // old -> new
        for (oldPath, oldE) in oldFlat where newFlat[oldPath] == nil {
            if var candidates = addedByOID[oldE.oid], !candidates.isEmpty {
                let newPath = candidates.removeFirst()
                addedByOID[oldE.oid] = candidates
                renamePairs[oldPath] = newPath
                consumedNew.insert(newPath)
            }
        }

        // Old-side entries.
        for (path, oldE) in oldFlat.sorted(by: { $0.key < $1.key }) {
            if let newPath = renamePairs[path] {
                let newE = newFlat[newPath]!
                diffs.append(try makeDiff(oldPath: path, newPath: newPath,
                                          oldE: oldE, newE: newE, status: .renamed))
                continue
            }
            if let newE = newFlat[path] {
                if newE.oid != oldE.oid || newE.mode != oldE.mode {
                    let status: FileDiff.StatusKind = newE.mode != oldE.mode && newE.oid == oldE.oid ? .typechanged : .modified
                    diffs.append(try makeDiff(oldPath: path, newPath: path,
                                              oldE: oldE, newE: newE, status: status))
                }
            } else {
                diffs.append(try makeDiff(oldPath: path, newPath: path,
                                          oldE: oldE, newE: nil, status: .deleted))
            }
        }
        // New-side additions.
        for (path, newE) in newFlat.sorted(by: { $0.key < $1.key }) {
            if oldFlat[path] == nil && !consumedNew.contains(path) {
                diffs.append(try makeDiff(oldPath: path, newPath: path,
                                          oldE: nil, newE: newE, status: .added))
            }
        }
        return diffs
    }

    private func makeDiff(oldPath: String, newPath: String,
                          oldE: (oid: ObjectID, mode: FileMode)?,
                          newE: (oid: ObjectID, mode: FileMode)?,
                          status: FileDiff.StatusKind) throws -> FileDiff {
        var isBinary = false
        var added = 0, removed = 0
        var patch: String? = nil

        let oldData = try oldE.map { try repo.blobData($0.oid) }
        let newData = try newE.map { try repo.blobData($0.oid) }
        if let d = oldData, DiffEngine.isBinary(d) { isBinary = true }
        if let d = newData, DiffEngine.isBinary(d) { isBinary = true }

        if !isBinary {
            let aLines = oldData.map { DiffEngine.splitLines($0) } ?? []
            let bLines = newData.map { DiffEngine.splitLines($0) } ?? []
            if aLines != bLines {
                let edits = DiffEngine.diff(aLines, bLines)
                let hunks = DiffEngine.hunks(edits: edits, a: aLines, b: bLines)
                let st = DiffEngine.stats(hunks: hunks)
                added = st.added; removed = st.removed
                patch = DiffEngine.unifiedPatch(hunks: hunks,
                                                aPath: oldPath, bPath: newPath)
            }
        }

        return FileDiff(oldPath: oldPath, newPath: newPath,
                        oldOID: oldE?.oid, newOID: newE?.oid,
                        oldMode: oldE?.mode, newMode: newE?.mode,
                        status: status, isBinary: isBinary,
                        added: added, removed: removed, patch: patch)
    }

    /// `spaces diff` (worktree vs index, or index vs HEAD with stagedOnly).
    public func workingDiff(stagedOnly: Bool = false) throws -> [FileDiff] {
        let index = try repo.index()
        var indexFlat: [String: (oid: ObjectID, mode: FileMode)] = [:]
        for (p, e) in index.entries { indexFlat[p] = (e.oid, e.mode) }

        if stagedOnly {
            // Index vs HEAD.
            let headFlat = try headTreeFlat()
            return try diffFlats(headFlat, indexFlat)
        }

        // Worktree vs index: build worktree flat for tracked + modified files.
        var workFlat = indexFlat
        let scanner = WorktreeScanner(repo: repo)
        let files = try scanner.scan()
        for f in files {
            if index.entries[f.relativePath] != nil {
                if !Index.statMatches(index.entries[f.relativePath]!, fileAt: f.url) {
                    let (oid, mode) = try scanner.hashEntry(
                        WorktreeScanner.FileEntry(relativePath: f.relativePath, url: f.url,
                                                  isDirectory: false, isSymlink: f.isSymlink,
                                                  size: f.size, mode: f.mode))
                    workFlat[f.relativePath] = (oid, mode)
                }
            }
        }
        // Tracked-in-index but missing from worktree → treat as deletion.
        let present = Set(files.map { $0.relativePath })
        for path in index.entries.keys where !present.contains(path) {
            workFlat.removeValue(forKey: path)
        }
        return try diffFlats(indexFlat, workFlat)
    }

    /// `spaces diff <commit> [commit]` — arbitrary revision diff.
    public func commitDiff(_ from: String, _ to: String = "HEAD") throws -> [FileDiff] {
        let fromOID = try repo.resolveRevision(from)
        let toOID = try repo.resolveRevision(to)
        let fromCommit = try repo.commitObject(fromOID)
        let toCommit = try repo.commitObject(toOID)
        return try diffTrees(fromCommit.tree, toCommit.tree)
    }

    /// Diff a single file between two revisions or worktree.
    public func fileDiff(path: String, from: String? = nil, to: String? = nil) throws -> FileDiff? {
        // Resolve flats.
        var oldFlat: [String: (oid: ObjectID, mode: FileMode)] = [:]
        var newFlat: [String: (oid: ObjectID, mode: FileMode)] = [:]
        if let f = from {
            let oid = try repo.resolveRevision(f)
            oldFlat = try TreeBuilder.flattenTree(repo: repo,
                                                  treeOID: repo.commitObject(oid).tree)
        } else {
            // Worktree/index side handled by caller typically.
        }
        if let t = to {
            let oid = try repo.resolveRevision(t)
            newFlat = try TreeBuilder.flattenTree(repo: repo,
                                                  treeOID: repo.commitObject(oid).tree)
        }
        let diffs = try diffFlats(oldFlat, newFlat)
        return diffs.first { $0.oldPath == path || $0.newPath == path }
    }

    /// Renders diffs as a combined patch string.
    public static func renderPatch(_ diffs: [FileDiff]) -> String {
        diffs.compactMap { $0.patch }.joined()
    }

    /// Applies a unified patch (as produced by `unifiedPatch`) to file
    /// contents. Returns new contents or nil if the patch doesn't apply.
    /// Supports the subset Spaces emits: @@ hunks with context/add/del.
    public static func applyPatch(to content: String, patch: String) -> String? {
        let patchLines = patch.components(separatedBy: "\n")
        let contentLines = DiffEngine.splitLines(Data(content.utf8))
        var result: [String] = []
        var i = 0 // content index
        var p = 0 // patch index

        // Skip headers until first @@.
        while p < patchLines.count && !patchLines[p].hasPrefix("@@") { p += 1 }

        while p < patchLines.count {
            guard patchLines[p].hasPrefix("@@") else { p += 1; continue }
            // Parse @@ -a,b +c,d @@
            let header = patchLines[p]
            guard let range = parseHunkHeader(header) else { return nil }
            p += 1
            // Copy unchanged lines up to hunk start (aStart is 1-based).
            let targetA = range.aStart - 1
            while i < targetA && i < contentLines.count {
                result.append(contentLines[i]); i += 1
            }
            // Apply hunk body.
            var aSeen = 0
            while p < patchLines.count && !patchLines[p].hasPrefix("@@") {
                let line = patchLines[p]
                if line.isEmpty && p == patchLines.count - 1 { p += 1; break }
                let prefix = line.first
                let text = String(line.dropFirst())
                switch prefix {
                case " ":
                    guard i < contentLines.count, contentLines[i] == text else { return nil }
                    result.append(contentLines[i]); i += 1; aSeen += 1
                case "-":
                    guard i < contentLines.count, contentLines[i] == text else { return nil }
                    i += 1; aSeen += 1
                case "+":
                    result.append(text)
                case "\\":
                    break // "\ No newline at end of file"
                default:
                    if line.isEmpty { result.append("") } else { return nil }
                }
                p += 1
            }
            _ = aSeen
        }
        while i < contentLines.count { result.append(contentLines[i]); i += 1 }
        return result.joined(separator: "\n") + (result.isEmpty ? "" : "\n")
    }

    private static func parseHunkHeader(_ header: String) -> (aStart: Int, aCount: Int, bStart: Int, bCount: Int)? {
        // @@ -l,c +l,c @@
        guard let dash = header.firstIndex(of: "-"),
              let plus = header.firstIndex(of: "+") else { return nil }
        let aPart = header[header.index(after: dash)..<plus]
            .trimmingCharacters(in: .whitespaces)
        let bPart = header[header.index(after: plus)...]
            .components(separatedBy: " @@").first?
            .trimmingCharacters(in: .whitespaces) ?? ""
        func parse(_ s: String) -> (Int, Int)? {
            let parts = s.split(separator: ",")
            guard let start = Int(parts[0]) else { return nil }
            let count = parts.count > 1 ? Int(parts[1]) ?? 1 : 1
            return (start, count)
        }
        guard let a = parse(aPart), let b = parse(bPart) else { return nil }
        return (a.0, a.1, b.0, b.1)
    }

    private func headTreeFlat() throws -> [String: (oid: ObjectID, mode: FileMode)] {
        guard let head = try repo.headCommit() else { return [:] }
        return try TreeBuilder.flattenTree(repo: repo, treeOID: head.tree)
    }
}
