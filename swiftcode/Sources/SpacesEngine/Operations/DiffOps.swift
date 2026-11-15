import Foundation



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
        public var oldSize: Int? = nil
        public var newSize: Int? = nil
        public var oldDigest: String? = nil
        public var newDigest: String? = nil
        public var similarityRatio: Double? = nil

        public enum StatusKind: String, Sendable {
            case added, deleted, modified, renamed, typechanged
        }
    }

    public struct DirectoryComparison: Sendable {
        public var directory: String
        public var added: Int
        public var removed: Int
        public var changed: Int
    }

    public func diffTrees(_ oldTree: ObjectID, _ newTree: ObjectID) throws -> [FileDiff] {
        let oldFlat = try TreeBuilder.flattenTree(repo: repo, treeOID: oldTree)
        let newFlat = try TreeBuilder.flattenTree(repo: repo, treeOID: newTree)
        return try diffFlats(oldFlat, newFlat)
    }

    public func diffFlats(_ oldFlat: [String: (oid: ObjectID, mode: FileMode)],
                          _ newFlat: [String: (oid: ObjectID, mode: FileMode)]) throws -> [FileDiff] {
        var diffs: [FileDiff] = []
        var consumedNew = Set<String>()

        var addedByOID: [ObjectID: [String]] = [:]
        for (path, e) in newFlat where oldFlat[path] == nil {
            addedByOID[e.oid, default: []].append(path)
        }
        var renamePairs: [String: String] = [:]
        for (oldPath, oldE) in oldFlat where newFlat[oldPath] == nil {
            if var candidates = addedByOID[oldE.oid], !candidates.isEmpty {
                let newPath = candidates.removeFirst()
                addedByOID[oldE.oid] = candidates
                renamePairs[oldPath] = newPath
                consumedNew.insert(newPath)
            }
        }

        var renameSimilarity: [String: Double] = [:]
        for (oldPath, oldE) in oldFlat.sorted(by: { $0.key < $1.key })
        where newFlat[oldPath] == nil && renamePairs[oldPath] == nil {
            guard let oldData = try? repo.blobData(oldE.oid),
                  !DiffEngine.isBinary(oldData) else { continue }
            var best: (path: String, ratio: Double)? = nil
            for (newPath, newE) in newFlat.sorted(by: { $0.key < $1.key })
            where oldFlat[newPath] == nil && !consumedNew.contains(newPath) {
                guard let newData = try? repo.blobData(newE.oid),
                      !DiffEngine.isBinary(newData) else { continue }
                let ratio = byteSimilarity(old: oldData, new: newData)
                if ratio >= 0.5 && (best == nil || ratio > best!.ratio) {
                    best = (newPath, ratio)
                }
            }
            if let match = best {
                renamePairs[oldPath] = match.path
                renameSimilarity[oldPath] = match.ratio
                consumedNew.insert(match.path)
            }
        }

        for (path, oldE) in oldFlat.sorted(by: { $0.key < $1.key }) {
            if let newPath = renamePairs[path] {
                let newE = newFlat[newPath]!
                diffs.append(try makeDiff(oldPath: path, newPath: newPath,
                                          oldE: oldE, newE: newE, status: .renamed,
                                          similarity: renameSimilarity[path] ?? 1.0))
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
                          status: FileDiff.StatusKind,
                          similarity: Double? = nil) throws -> FileDiff {
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
                        added: added, removed: removed, patch: patch,
                        oldSize: oldData?.count, newSize: newData?.count,
                        oldDigest: oldE?.oid.hex, newDigest: newE?.oid.hex,
                        similarityRatio: similarity)
    }

    private func byteSimilarity(old: Data, new: Data) -> Double {
        let aLines = DiffEngine.splitLines(old)
        let bLines = DiffEngine.splitLines(new)
        if aLines.isEmpty && bLines.isEmpty { return 1.0 }
        if aLines.isEmpty || bLines.isEmpty { return 0.0 }
        var counts: [String: Int] = [:]
        for line in aLines { counts[line, default: 0] += 1 }
        var shared = 0
        for line in bLines {
            if let remaining = counts[line], remaining > 0 {
                counts[line] = remaining - 1
                shared += 1
            }
        }
        return Double(shared) / Double(max(aLines.count, bLines.count))
    }

    public func compareDirectories(from: ObjectID, to: ObjectID) throws -> [DirectoryComparison] {
        let diffs = try diffTrees(from, to)
        var byDirectory: [String: DirectoryComparison] = [:]
        for diff in diffs {
            let path = diff.status == .deleted ? diff.oldPath : diff.newPath
            for directory in ancestorDirectories(of: path) {
                var entry = byDirectory[directory] ?? DirectoryComparison(directory: directory, added: 0, removed: 0, changed: 0)
                switch diff.status {
                case .added: entry.added += 1
                case .deleted: entry.removed += 1
                default: entry.changed += 1
                }
                byDirectory[directory] = entry
            }
        }
        return byDirectory.values.sorted { $0.directory < $1.directory }
    }

    private func ancestorDirectories(of path: String) -> [String] {
        var directories = [""]
        var parts = path.split(separator: "/").map(String.init)
        guard !parts.isEmpty else { return directories }
        parts.removeLast()
        var current = ""
        for part in parts {
            current = current.isEmpty ? part : current + "/" + part
            directories.append(current)
        }
        return directories
    }

    
    public func workingDiff(stagedOnly: Bool = false) throws -> [FileDiff] {
        let index = try repo.index()
        var indexFlat: [String: (oid: ObjectID, mode: FileMode)] = [:]
        for (p, e) in index.entries { indexFlat[p] = (e.oid, e.mode) }

        if stagedOnly {
            
            let headFlat = try headTreeFlat()
            return try diffFlats(headFlat, indexFlat)
        }

        
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
        
        let present = Set(files.map { $0.relativePath })
        for path in index.entries.keys where !present.contains(path) {
            workFlat.removeValue(forKey: path)
        }
        return try diffFlats(indexFlat, workFlat)
    }

    
    public func commitDiff(_ from: String, _ to: String = "HEAD") throws -> [FileDiff] {
        let fromOID = try repo.resolveRevision(from)
        let toOID = try repo.resolveRevision(to)
        let fromCommit = try repo.commitObject(fromOID)
        let toCommit = try repo.commitObject(toOID)
        return try diffTrees(fromCommit.tree, toCommit.tree)
    }

    public func compareRevisions(from: String, to: String = "HEAD") throws -> [FileDiff] {
        try commitDiff(from, to)
    }

    
    public func fileDiff(path: String, from: String? = nil, to: String? = nil) throws -> FileDiff? {
        let oldFlat: [String: (oid: ObjectID, mode: FileMode)]
        if let f = from {
            let oid = try repo.resolveRevision(f)
            oldFlat = try TreeBuilder.flattenTree(repo: repo,
                                                  treeOID: repo.commitObject(oid).tree)
        } else if let head = try repo.headCommit() {
            oldFlat = try TreeBuilder.flattenTree(repo: repo, treeOID: head.tree)
        } else {
            oldFlat = [:]
        }
        let newFlat: [String: (oid: ObjectID, mode: FileMode)]
        if let t = to {
            let oid = try repo.resolveRevision(t)
            newFlat = try TreeBuilder.flattenTree(repo: repo,
                                                  treeOID: repo.commitObject(oid).tree)
        } else {
            let index = try repo.index()
            var indexFlat: [String: (oid: ObjectID, mode: FileMode)] = [:]
            for (p, e) in index.entries { indexFlat[p] = (e.oid, e.mode) }
            newFlat = indexFlat
        }
        let diffs = try diffFlats(oldFlat, newFlat)
        return diffs.first { $0.oldPath == path || $0.newPath == path }
    }

    
    public static func renderPatch(_ diffs: [FileDiff]) -> String {
        diffs.compactMap { $0.patch }.joined()
    }

    
    
    
    public static func applyPatch(to content: String, patch: String) -> String? {
        let patchLines = patch.components(separatedBy: "\n")
        let contentLines = DiffEngine.splitLines(Data(content.utf8))
        var result: [String] = []
        var i = 0 
        var p = 0 

        
        while p < patchLines.count && !patchLines[p].hasPrefix("@@") { p += 1 }

        while p < patchLines.count {
            guard patchLines[p].hasPrefix("@@") else { p += 1; continue }
            
            let header = patchLines[p]
            guard let range = parseHunkHeader(header) else { return nil }
            p += 1
            
            let targetA = range.aStart - 1
            while i < targetA && i < contentLines.count {
                result.append(contentLines[i]); i += 1
            }
            
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
                    break 
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
