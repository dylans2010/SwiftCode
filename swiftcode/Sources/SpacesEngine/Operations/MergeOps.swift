import Foundation

/// Three-way merge engine. Merges trees (not working files directly):
/// per-path resolution rules, then text-level 3-way line merge for
/// both-modified text files, producing conflict markers when needed.
public struct MergeEngine {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public enum MergeResult {
        case upToDate
        case fastForward(ObjectID)
        case merged(tree: ObjectID, conflicts: [String], cleanPaths: [String])
    }

    public struct ConflictInfo {
        public var path: String
        public var kind: ConflictKind
        public var baseOID: ObjectID?
        public var oursOID: ObjectID?
        public var theirsOID: ObjectID?

        public enum ConflictKind: String, Sendable {
            case content        // both modified text
            case binary         // both modified binary
            case deleteModify   // one deleted, other modified
            case addAdd         // both added differently
            case renameDelete   // rename vs delete
            case directoryFile  // file vs directory
        }
    }

    /// Computes the merge of `theirsOID` into the current HEAD without
    /// touching the worktree — returns the merged tree + conflicts.
    /// `baseOID` is the merge base (computed if nil).
    public func mergeTrees(oursHead: ObjectID, theirsOID: ObjectID,
                           baseOID: ObjectID? = nil) throws
        -> (tree: ObjectID, conflicts: [ConflictInfo], resolved: [String: Data]) {
        let base: ObjectID
        if let b = baseOID {
            base = b
        } else if let mb = try HistoryOps(repo: repo).mergeBase(oursHead, theirsOID) {
            base = mb
        } else {
            // Unrelated histories: merge against empty tree.
            base = try TreeBuilder.emptyTree(objects: repo.objects)
        }
        let baseCommit = try? repo.commitObject(base)
        let oursCommit = try repo.commitObject(oursHead)
        let theirsCommit = try repo.commitObject(theirsOID)
        let baseFlat = baseCommit != nil
            ? try TreeBuilder.flattenTree(repo: repo, treeOID: baseCommit!.tree)
            : [:]
        let oursFlat = try TreeBuilder.flattenTree(repo: repo, treeOID: oursCommit.tree)
        let theirsFlat = try TreeBuilder.flattenTree(repo: repo, treeOID: theirsCommit.tree)

        let allPaths = Set(baseFlat.keys).union(oursFlat.keys).union(theirsFlat.keys)
        var merged: [String: (oid: ObjectID, mode: FileMode)] = [:]
        var conflicts: [ConflictInfo] = []
        var resolvedContents: [String: Data] = [:] // path → merged bytes for clean text merges

        for path in allPaths.sorted() {
            let b = baseFlat[path], o = oursFlat[path], t = theirsFlat[path]

            // Same on all sides or unchanged relative to base.
            func same(_ x: (oid: ObjectID, mode: FileMode)?, _ y: (oid: ObjectID, mode: FileMode)?) -> Bool {
                switch (x, y) {
                case (nil, nil): return true
                case let (a?, b?): return a.oid == b.oid && a.mode == b.mode
                default: return false
                }
            }
            if same(o, t) { // includes both nil
                if let entry = o { merged[path] = entry }
                continue
            }
            if same(b, o) {
                // Only theirs changed.
                if let entry = t { merged[path] = entry }
                continue
            }
            if same(b, t) {
                // Only ours changed.
                if let entry = o { merged[path] = entry }
                continue
            }

            // Both sides changed differently (or one deleted).
            let oursDeleted = o == nil, theirsDeleted = t == nil
            if oursDeleted && theirsDeleted { continue }
            if oursDeleted || theirsDeleted {
                let survivor = oursDeleted ? t! : o!
                let deletedBy = oursDeleted ? "ours" : "theirs"
                // delete/modify conflict unless the modification is identical
                // to base (already handled above).
                conflicts.append(ConflictInfo(path: path,
                                              kind: .deleteModify,
                                              baseOID: b?.oid,
                                              oursOID: o?.oid,
                                              theirsOID: t?.oid))
                // Keep the modified version in worktree for resolution.
                merged[path] = survivor
                _ = deletedBy
                continue
            }

            // Both present, different content.
            let oData = try repo.blobData(o!.oid)
            let tData = try repo.blobData(t!.oid)
            let bData = b.map { try? repo.blobData($0.oid) } ?? nil
            let binary = DiffEngine.isBinary(oData) || DiffEngine.isBinary(tData)
                || (bData.map { DiffEngine.isBinary($0) } ?? false)
            if binary {
                conflicts.append(ConflictInfo(path: path, kind: .binary,
                                              baseOID: b?.oid, oursOID: o!.oid, theirsOID: t!.oid))
                // Keep ours in tree; conflict markers impossible for binary.
                merged[path] = o!
                continue
            }

            // Text 3-way merge.
            let baseText = bData.map { String(decoding: $0, as: UTF8.self) } ?? ""
            let oursText = String(decoding: oData, as: UTF8.self)
            let theirsText = String(decoding: tData, as: UTF8.self)
            let result = threeWayMerge(base: baseText, ours: oursText, theirs: theirsText)
            if result.conflicts.isEmpty {
                let data = Data(result.text.utf8)
                let oid = try repo.objects.write(type: .blob, payload: data)
                let mode = o!.mode == t!.mode ? o!.mode : .regular
                merged[path] = (oid, mode)
                resolvedContents[path] = data
            } else {
                // Write conflict-markered content, keep as unmerged.
                let data = Data(result.text.utf8)
                let oid = try repo.objects.write(type: .blob, payload: data)
                merged[path] = (oid, o!.mode)
                conflicts.append(ConflictInfo(path: path, kind: .content,
                                              baseOID: b?.oid, oursOID: o!.oid, theirsOID: t!.oid))
            }
        }

        // Directory/file conflicts: if merged map has both "a" as file and
        // "a/b" paths, that's a structural conflict — detect and report.
        var hasDirFile = false
        let paths = Set(merged.keys)
        for p in paths {
            var comps = p.split(separator: "/").map(String.init)
            while comps.count > 1 {
                comps.removeLast()
                if paths.contains(comps.joined(separator: "/")) { hasDirFile = true; break }
            }
            if hasDirFile { break }
        }
        if hasDirFile {
            conflicts.append(ConflictInfo(path: "(structural)", kind: .directoryFile,
                                          baseOID: nil, oursOID: nil, theirsOID: nil))
        }

        let treeOID = try TreeBuilder.writeTree(entries: merged, objects: repo.objects)
        return (treeOID, conflicts, resolvedContents)
    }

    /// `spaces merge <branch>` — full merge into current branch.
    public struct MergeOutcome {
        public var result: MergeResult
        public var conflicts: [ConflictInfo]
        public var commitOID: ObjectID?
    }

    @discardableResult
    public func merge(_ target: String, allowFF: Bool = true,
                      strategy: String = "ort") throws -> MergeOutcome {
        _ = strategy // reserved for future strategy selection
        return try repo.performTransaction(steps: ["merge:\(target)"]) {
            if repo.inMerge() { throw SpacesError.mergeInProgress }
            if repo.inRebase() { throw SpacesError.rebaseInProgress }
            guard let headOID = try repo.refs.headOID(objects: repo.objects) else {
                throw SpacesError.branchNotFound("HEAD (unborn)")
            }
            let theirsOID = try repo.resolveRevision(target)
            if theirsOID == headOID {
                return MergeOutcome(result: .upToDate, conflicts: [], commitOID: nil)
            }

            let headCommit = try repo.commitObject(headOID)
            let theirsCommit = try repo.commitObject(theirsOID)

            // Fast-forward check: head is ancestor of theirs.
            let base = try HistoryOps(repo: repo).mergeBase(headOID, theirsOID)
            if allowFF, base == headOID {
                // FF: move branch ref to theirs, update worktree+index.
                try checkoutCommit(theirsOID)
                if let sym = try repo.refs.symbolicHEAD() {
                    _ = try repo.refs.updateRef(sym, to: theirsOID)
                }
                try repo.appendReflog(refName: "HEAD", old: headOID, new: theirsOID,
                                      message: "merge \(target): fast-forward")
                return MergeOutcome(result: .fastForward(theirsOID), conflicts: [], commitOID: nil)
            }

            // Three-way merge.
            _ = try StagingOps(repo: repo).runHook(.preMerge, input: "")
            let merged = try mergeTrees(oursHead: headOID, theirsOID: theirsOID, baseOID: base)

            if merged.conflicts.isEmpty {
                // Clean merge → merge commit.
                let ident = repo.identity()
                let message = "Merge \(target) into \(try repo.refs.currentBranch() ?? "HEAD")"
                let payload = CommitPayload(tree: merged.tree,
                                            parents: [headOID, theirsOID],
                                            author: ident, committer: ident,
                                            message: message)
                let commitOID = try repo.objects.write(.commit, value: payload)
                if let sym = try repo.refs.symbolicHEAD() {
                    _ = try repo.refs.updateRef(sym, to: commitOID)
                } else {
                    try repo.refs.setHEAD(oid: commitOID)
                }
                try checkoutCommit(commitOID)
                try repo.appendReflog(refName: "HEAD", old: headOID, new: commitOID,
                                      message: "merge \(target)")
                _ = try StagingOps(repo: repo).runHook(.postMerge, input: "")
                return MergeOutcome(result: .merged(tree: merged.tree, conflicts: [],
                                                    cleanPaths: []),
                                    conflicts: [], commitOID: commitOID)
            }

            // Conflicted merge: write merged tree to worktree, mark conflicts,
            // set MERGE_HEAD, leave for user resolution.
            try checkoutTree(merged.tree, overlay: merged.resolved)
            // Write conflicts.json.
            let records = merged.conflicts.map {
                WorktreeScanner.ConflictRecord(path: $0.path, resolved: false,
                                               ours: nil, theirs: nil, base: nil)
            }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            try encoder.encode(records).write(
                to: repo.metaURL.appendingPathComponent("conflicts.json"))
            try repo.writeState("MERGE_HEAD", contents: theirsOID.hex + "\n")
            try repo.writeState("MERGE_MSG",
                                contents: "Merge \(target) into \(try repo.refs.currentBranch() ?? "HEAD")\n")
            return MergeOutcome(result: .merged(tree: merged.tree,
                                                conflicts: merged.conflicts.map(\.path),
                                                cleanPaths: []),
                                conflicts: merged.conflicts, commitOID: nil)
        }
    }

    /// `spaces merge-continue` — after resolving conflicts, creates the
    /// merge commit.
    @discardableResult
    public func mergeContinue(message: String? = nil) throws -> ObjectID {
        return try repo.performTransaction(steps: ["merge-continue"]) {
            guard repo.inMerge() else { throw SpacesError.noMergeInProgress }
            let unresolved = try WorktreeScanner(repo: repo).conflictedPaths()
            guard unresolved.isEmpty else {
                throw SpacesError.conflictsRemain(unresolved)
            }
            guard let mergeHeadText = repo.readState("MERGE_HEAD"),
                  let mergeOID = try? ObjectID(validating: mergeHeadText.trimmingCharacters(in: .whitespacesAndNewlines))
            else { throw SpacesError.internalInconsistency("MERGE_HEAD unreadable") }
            guard let headOID = try repo.refs.headOID(objects: repo.objects) else {
                throw SpacesError.branchNotFound("HEAD")
            }
            // Stage everything (resolved files were written to worktree).
            _ = try StagingOps(repo: repo).add(".", all: true)
            let staging = StagingOps(repo: repo)
            let msg = message ?? repo.readState("MERGE_MSG") ?? "Merge commit"
            // Build commit manually with two parents (StagingOps.commit would
            // read MERGE_HEAD itself — reuse it).
            let result = try staging.commit(message: msg)
            _ = mergeOID
            return result.oid
        }
    }

    /// `spaces merge-abort` — restores pre-merge state.
    public func mergeAbort() throws {
        try repo.performTransaction(steps: ["merge-abort"]) {
            guard repo.inMerge() else { throw SpacesError.noMergeInProgress }
            guard let headOID = try repo.refs.headOID(objects: repo.objects),
                  let headCommit = try? repo.commitObject(headOID) else {
                throw SpacesError.internalInconsistency("no HEAD commit")
            }
            // Reset worktree+index to HEAD tree.
            _ = try TreeBuilder.checkout(repo: repo, treeOID: headCommit.tree)
            let flat = try TreeBuilder.flattenTree(repo: repo, treeOID: headCommit.tree)
            var index = Index()
            for (path, e) in flat {
                let url = try repo.worktreeURL(forRelativePath: path)
                index.entries[path] = try Index.entry(forFileAt: url, oid: e.oid, mode: e.mode)
            }
            try repo.saveIndex(index)
            repo.clearState(["MERGE_HEAD", "MERGE_MSG", "MERGE_MODE", "conflicts.json"])
        }
    }

    /// `spaces cherry-pick <rev>` / `spaces revert <rev>`.
    /// Both apply a commit's diff onto HEAD as a new commit.
    @discardableResult
    public func cherryPick(_ rev: String, revert: Bool = false) throws -> ObjectID? {
        return try repo.performTransaction(steps: [revert ? "revert:\(rev)" : "cherry-pick:\(rev)"]) {
            if repo.inMerge() || repo.inRebase() { throw SpacesError.invalidArgument("operation in progress") }
            let oid = try repo.resolveRevision(rev)
            let commit = try repo.commitObject(oid)
            guard let parent = commit.parents.first else {
                throw SpacesError.invalidArgument("root commit cannot be cherry-picked/reverted")
            }
            let parentCommit = try repo.commitObject(parent)

            // Compute diff parent→commit, apply to HEAD tree.
            guard let headOID = try repo.refs.headOID(objects: repo.objects) else {
                throw SpacesError.branchNotFound("HEAD")
            }
            let headTree = try repo.commitObject(headOID).tree
            let sourceTree = revert ? commit.tree : commit.tree
            let baseTree = revert ? commit.tree : parentCommit.tree
            _ = sourceTree

            // 3-way merge: base=parent(or commit for revert), ours=HEAD, theirs=commit(or parent for revert).
            let theirsOID = revert ? parent : oid
            let baseOID = revert ? oid : parent
            let merged = try mergeTrees(oursHead: headOID, theirsOID: theirsOID, baseOID: baseOID)

            if !merged.conflicts.isEmpty {
                try checkoutTree(merged.tree, overlay: merged.resolved)
                let records = merged.conflicts.map {
                    WorktreeScanner.ConflictRecord(path: $0.path, resolved: false,
                                                   ours: nil, theirs: nil, base: nil)
                }
                let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
                try encoder.encode(records).write(
                    to: repo.metaURL.appendingPathComponent("conflicts.json"))
                try repo.writeState(revert ? "REVERT_HEAD" : "CHERRY_PICK_HEAD",
                                    contents: oid.hex + "\n")
                return nil
            }

            // Clean: create commit with HEAD as only parent.
            let ident = repo.identity()
            let verb = revert ? "Revert" : "Cherry-pick"
            let origSummary = commit.summary
            let message = revert
                ? "Revert \"\(origSummary)\"\n\nThis reverts commit \(oid.hex)."
                : commit.message
            let payload = CommitPayload(tree: merged.tree, parents: [headOID],
                                        author: ident, committer: ident, message: message)
            let newOID = try repo.objects.write(.commit, value: payload)
            if let sym = try repo.refs.symbolicHEAD() {
                _ = try repo.refs.updateRef(sym, to: newOID)
            } else {
                try repo.refs.setHEAD(oid: newOID)
            }
            try checkoutCommit(newOID)
            try repo.appendReflog(refName: "HEAD", old: headOID, new: newOID,
                                  message: "\(verb.lowercased()) \(rev)")
            return newOID
        }
    }

    public func cherryPickContinue() throws -> ObjectID? {
        return try repo.performTransaction(steps: ["cherry-pick-continue"]) {
            guard repo.inCherryPick() else { throw SpacesError.invalidArgument("no cherry-pick/revert in progress") }
            let unresolved = try WorktreeScanner(repo: repo).conflictedPaths()
            guard unresolved.isEmpty else { throw SpacesError.conflictsRemain(unresolved) }
            _ = try StagingOps(repo: repo).add(".", all: true)
            // Determine which state file is set.
            let isRevert = repo.inRevertState()
            let stateName = isRevert ? "REVERT_HEAD" : "CHERRY_PICK_HEAD"
            guard let text = repo.readState(stateName),
                  let origOID = try? ObjectID(validating: text.trimmingCharacters(in: .whitespacesAndNewlines))
            else { throw SpacesError.internalInconsistency("state unreadable") }
            let origCommit = try repo.commitObject(origOID)
            let ident = repo.identity()
            let message = isRevert
                ? "Revert \"\(origCommit.summary)\"\n\nThis reverts commit \(origOID.hex)."
                : origCommit.message
            let staging = StagingOps(repo: repo)
            let treeOID = try staging.writeIndexTree()
            guard let headOID = try repo.refs.headOID(objects: repo.objects) else {
                throw SpacesError.branchNotFound("HEAD")
            }
            let payload = CommitPayload(tree: treeOID, parents: [headOID],
                                        author: ident, committer: ident, message: message)
            let newOID = try repo.objects.write(.commit, value: payload)
            if let sym = try repo.refs.symbolicHEAD() {
                _ = try repo.refs.updateRef(sym, to: newOID)
            }
            repo.clearState(["CHERRY_PICK_HEAD", "REVERT_HEAD", "conflicts.json"])
            try checkoutCommit(newOID)
            return newOID
        }
    }

    public func cherryPickAbort() throws {
        try repo.performTransaction(steps: ["cherry-pick-abort"]) {
            guard repo.inCherryPick() else { throw SpacesError.invalidArgument("no cherry-pick/revert in progress") }
            guard let headOID = try repo.refs.headOID(objects: repo.objects),
                  let headCommit = try? repo.commitObject(headOID) else {
                throw SpacesError.internalInconsistency("no HEAD")
            }
            _ = try TreeBuilder.checkout(repo: repo, treeOID: headCommit.tree)
            let flat = try TreeBuilder.flattenTree(repo: repo, treeOID: headCommit.tree)
            var index = Index()
            for (path, e) in flat {
                let url = try repo.worktreeURL(forRelativePath: path)
                index.entries[path] = try Index.entry(forFileAt: url, oid: e.oid, mode: e.mode)
            }
            try repo.saveIndex(index)
            repo.clearState(["CHERRY_PICK_HEAD", "REVERT_HEAD", "conflicts.json"])
        }
    }

    // MARK: - Tree checkout helpers

    /// Writes a commit's tree to worktree+index.
    func checkoutCommit(_ oid: ObjectID) throws {
        let commit = try repo.commitObject(oid)
        try checkoutTree(commit.tree, overlay: [:])
    }

    /// Materializes a tree into worktree and rebuilds the index from it.
    /// `overlay` provides pre-merged contents for conflicted paths.
    func checkoutTree(_ treeOID: ObjectID,
                      overlay: [String: Data]) throws {
        _ = try TreeBuilder.checkout(repo: repo, treeOID: treeOID)
        // Apply overlay contents (already-conflict-markered text).
        for (path, data) in overlay {
            let url = try repo.worktreeURL(forRelativePath: path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try data.write(to: url)
        }
        // Rebuild index from tree.
        let flat = try TreeBuilder.flattenTree(repo: repo, treeOID: treeOID)
        var index = Index()
        for (path, e) in flat {
            let url = try repo.worktreeURL(forRelativePath: path)
            if let overlayData = overlay[path] {
                let oid = try repo.objects.write(type: .blob, payload: overlayData)
                index.entries[path] = try Index.entry(forFileAt: url, oid: oid, mode: e.mode)
            } else {
                index.entries[path] = try Index.entry(forFileAt: url, oid: e.oid, mode: e.mode)
            }
        }
        try repo.saveIndex(index)
    }
}

extension Repository {
    func inRevertState() -> Bool {
        FileManager.default.fileExists(atPath: revertHeadURL.path)
    }
}


/// Result of a three-way text merge.
public struct ThreeWayMergeResult {
    public var text: String
    public var conflicts: [ConflictRegion]
}

public struct ConflictRegion {
    public var path: String = ""
    public var oursStart: Int
    public var oursEnd: Int
    public var theirsStart: Int
    public var theirsEnd: Int
}

/// A changed region in base coordinates: base[start..<end] is replaced by
/// `replacement`. Zero-width regions (start == end) are pure insertions.
struct MergeRegion {
    var start: Int
    var end: Int
    var replacement: [String]
}

/// Computes per-side changed regions vs base using the line diff.
func mergeRegions(base: [String], other: [String]) -> [MergeRegion] {
    let edits = DiffEngine.diff(base, other)
    var regs: [MergeRegion] = []
    var basePos = 0
    var cur: MergeRegion? = nil
    for e in edits {
        switch e {
        case .equal(let x, _):
            if var c = cur { c.end = basePos; regs.append(c); cur = nil }
            basePos = x + 1
        case .delete(let x):
            if cur == nil { cur = MergeRegion(start: x, end: x, replacement: []) }
            cur!.end = x + 1
            basePos = x + 1
        case .insert(let y):
            if cur == nil { cur = MergeRegion(start: basePos, end: basePos, replacement: []) }
            cur!.replacement.append(other[y])
        }
    }
    if var c = cur { c.end = basePos; regs.append(c) }
    return regs
}

/// Reconstructs `other`'s version of base[s..<e] by applying that side's
/// regions which fall inside the block.
func applyRegions(base: [String], regs: [MergeRegion], s: Int, e: Int) -> [String] {
    var out: [String] = []
    var cur = s
    for r in regs where r.start >= s && r.end <= e {
        out.append(contentsOf: base[cur..<r.start])
        out.append(contentsOf: r.replacement)
        cur = r.end
    }
    out.append(contentsOf: base[cur..<e])
    return out
}

/// diff3-style three-way line merge producing conflict markers.
/// Returns merged text plus conflict regions.
public func threeWayMerge(base: String, ours: String, theirs: String) -> ThreeWayMergeResult {
    let baseLines = DiffEngine.splitLines(Data(base.utf8))
    let oursLines = DiffEngine.splitLines(Data(ours.utf8))
    let theirsLines = DiffEngine.splitLines(Data(theirs.utf8))

    if oursLines == theirsLines {
        return ThreeWayMergeResult(text: ours, conflicts: [])
    }
    if oursLines == baseLines {
        return ThreeWayMergeResult(text: theirs, conflicts: [])
    }
    if theirsLines == baseLines {
        return ThreeWayMergeResult(text: ours, conflicts: [])
    }

    let oursRegs = mergeRegions(base: baseLines, other: oursLines)
    let theirsRegs = mergeRegions(base: baseLines, other: theirsLines)

    var output: [String] = []
    var conflicts: [ConflictRegion] = []
    var i = 0
    var oi = 0, ti = 0

    while i <= baseLines.count {
        let oNext = oi < oursRegs.count ? oursRegs[oi].start : Int.max
        let tNext = ti < theirsRegs.count ? theirsRegs[ti].start : Int.max
        let nextStart = min(oNext, tNext)
        if nextStart == Int.max {
            if i < baseLines.count { output.append(contentsOf: baseLines[i...]) }
            break
        }
        if nextStart > i {
            output.append(contentsOf: baseLines[i..<min(nextStart, baseLines.count)])
            i = min(nextStart, baseLines.count)
        }

        // Union-close the block: absorb every region (either side) whose
        // start <= current block end.
        var blockEnd = i
        var oBlock: [MergeRegion] = []
        var tBlock: [MergeRegion] = []
        var grew = true
        while grew {
            grew = false
            while oi < oursRegs.count && oursRegs[oi].start <= blockEnd {
                let r = oursRegs[oi]
                oBlock.append(r)
                blockEnd = max(blockEnd, r.end)
                oi += 1
                grew = true
            }
            while ti < theirsRegs.count && theirsRegs[ti].start <= blockEnd {
                let r = theirsRegs[ti]
                tBlock.append(r)
                blockEnd = max(blockEnd, r.end)
                ti += 1
                grew = true
            }
        }
        let e = min(blockEnd, baseLines.count)
        let baseSlice = Array(baseLines[i..<e])
        let oursResult = applyRegions(base: baseLines, regs: oBlock, s: i, e: e)
        let theirsResult = applyRegions(base: baseLines, regs: tBlock, s: i, e: e)

        if oursResult == theirsResult {
            output.append(contentsOf: oursResult)
        } else if oursResult == baseSlice {
            output.append(contentsOf: theirsResult)
        } else if theirsResult == baseSlice {
            output.append(contentsOf: oursResult)
        } else {
            output.append("<<<<<<< ours")
            output.append(contentsOf: oursResult)
            output.append("=======")
            output.append(contentsOf: theirsResult)
            output.append(">>>>>>> theirs")
            conflicts.append(ConflictRegion(oursStart: i, oursEnd: e,
                                             theirsStart: i, theirsEnd: e))
        }
        i = e
        if e == i && oBlock.isEmpty && tBlock.isEmpty { break } // safety
    }

    return ThreeWayMergeResult(text: output.joined(separator: "\n") + "\n",
                               conflicts: conflicts)
}
