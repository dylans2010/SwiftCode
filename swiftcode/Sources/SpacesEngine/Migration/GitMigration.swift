import Foundation

/// Git migration: import existing Git repositories into Spaces objects and
/// export Spaces repositories to Git format.
///
/// Interop note: this is the ONE subsystem allowed to invoke `git` — it
/// reads/writes Git's own formats for migration purposes only. Normal Spaces
/// operations never touch git.
public struct GitMigration {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    // MARK: - Import

    public struct ImportReport: Sendable, Encodable {
        public var objectsWritten: Int
        public var commits: Int
        public var branches: [String]
        public var tags: [String]
        public var warnings: [String]
    }

    /// Imports a Git repository at `gitPath` into this Spaces repository.
    /// Reads via `git cat-file --batch` and `git for-each-ref`; writes native
    /// Spaces objects. The source repo is never modified.
    @discardableResult
    public func importGit(at gitPath: String, dryRun: Bool = false) throws -> ImportReport {
        let git = try findGit()
        let gitDir = try resolveGitDir(git: git, path: gitPath)

        var report = ImportReport(objectsWritten: 0, commits: 0,
                                  branches: [], tags: [], warnings: [])

        // 1) Enumerate refs.
        let refsOut = try runGitRaw(git, ["-C", gitPath, "for-each-ref",
                                       "--format=%(refname) %(objectname)"])
        struct RefLine { var name: String; var oid: String }
        var refLines: [RefLine] = []
        for line in refsOut.components(separatedBy: "\n") where !line.isEmpty {
            let parts = line.split(separator: " ", maxSplits: 1).map(String.init)
            if parts.count == 2 { refLines.append(RefLine(name: parts[0], oid: parts[1])) }
        }

        // 2) Stream all objects via cat-file --batch-all-objects.
        // Format: "<oid> <type> <size>\n<contents>\n" per object.
        let batchCheck = try runGitRaw(git, ["-C", gitPath, "cat-file",
                                          "--batch-all-objects", "--batch-check=%(objectname) %(objecttype) %(objectsize)"])
        struct ObjInfo { var oid: String; var type: String; var size: Int }
        var infos: [ObjInfo] = []
        for line in batchCheck.components(separatedBy: "\n") where !line.isEmpty {
            let parts = line.split(separator: " ", maxSplits: 2).map(String.init)
            if parts.count == 3, let size = Int(parts[2]) {
                infos.append(ObjInfo(oid: parts[0], type: parts[1], size: size))
            }
        }

        // Map git oid → spaces oid.
        var oidMap: [String: ObjectID] = [:]

        // 3) Import blobs and trees first (bottom-up), then commits/tags.
        // Two passes: non-commit objects, then commits (need mapped parents),
        // then tag objects.
        for pass in ["blob", "tree"] {
            for info in infos where info.type == pass {
                let payload = try catFile(git: git, path: gitPath, oid: info.oid, size: info.size, type: info.type)
                if pass == "blob" {
                    let spacesOID = ObjectID.blob(payload)
                    if !dryRun { _ = try repo.objects.write(type: .blob, payload: payload) }
                    oidMap[info.oid] = spacesOID
                    report.objectsWritten += 1
                } else {
                    // Git tree binary format → Spaces tree JSON.
                    let treePayload = try convertGitTree(payload, oidMap: oidMap)
                    if let tp = treePayload {
                        let spacesOID = try repo.objects.write(.tree, value: tp)
                        oidMap[info.oid] = spacesOID
                        report.objectsWritten += 1
                    } else {
                        report.warnings.append("skipped unconvertible tree \(info.oid)")
                    }
                }
            }
        }

        // Git trees may reference trees imported later; iterate until stable.
        var pendingTrees = infos.filter { $0.type == "tree" && oidMap[$0.oid] == nil }
        var guardCount = 0
        while !pendingTrees.isEmpty && guardCount < 10 {
            guardCount += 1
            var stillPending: [ObjInfo] = []
            for info in pendingTrees {
                let payload = try catFile(git: git, path: gitPath, oid: info.oid, size: info.size, type: info.type)
                if let tp = try convertGitTree(payload, oidMap: oidMap) {
                    let spacesOID = try repo.objects.write(.tree, value: tp)
                    oidMap[info.oid] = spacesOID
                    report.objectsWritten += 1
                } else {
                    stillPending.append(info)
                }
            }
            pendingTrees = stillPending
        }
        if !pendingTrees.isEmpty {
            report.warnings.append("\(pendingTrees.count) trees could not be converted (missing subtrees)")
        }

        // 4) Commits — parents must be imported before children, so iterate
        // to a fixpoint: a commit is ready once every git-parent hex that is
        // itself a commit in this repo has a spaces OID in oidMap.
        let commitHexes = Set(infos.filter { $0.type == "commit" }.map { $0.oid })
        var pendingCommits = infos.filter { $0.type == "commit" }
        guardCount = 0
        while !pendingCommits.isEmpty && guardCount < 50 {
            guardCount += 1
            var still: [ObjInfo] = []
            var progress = false
            for info in pendingCommits {
                let payload = try catFile(git: git, path: gitPath, oid: info.oid, size: info.size, type: info.type)
                let parentHexes = gitCommitParentHexes(payload)
                let blocked = parentHexes.contains { commitHexes.contains($0) && oidMap[$0] == nil }
                if blocked { still.append(info); continue }
                guard let commitPayload = parseGitCommit(payload, oidMap: oidMap) else {
                    report.warnings.append("skipped unparseable commit \(info.oid)")
                    progress = true
                    continue
                }
                let spacesOID = try repo.objects.write(.commit, value: commitPayload)
                oidMap[info.oid] = spacesOID
                report.commits += 1
                report.objectsWritten += 1
                progress = true
            }
            pendingCommits = still
            if !progress && !pendingCommits.isEmpty { break }
        }
        for info in pendingCommits {
            report.warnings.append("skipped commit \(info.oid) (unresolved parents)")
        }

        // 5) Tag objects (annotated).
        for info in infos where info.type == "tag" {
            let payload = try catFile(git: git, path: gitPath, oid: info.oid, size: info.size, type: info.type)
            if let tagPayload = parseGitTagObject(payload, oidMap: oidMap) {
                let spacesOID = try repo.objects.write(.tag, value: tagPayload)
                oidMap[info.oid] = spacesOID
                report.objectsWritten += 1
            }
        }

        // 6) Refs.
        for ref in refLines {
            guard let spacesOID = oidMap[ref.oid] else {
                report.warnings.append("ref \(ref.name) target not imported")
                continue
            }
            let localName: String
            if ref.name.hasPrefix("refs/heads/") {
                localName = ref.name
                report.branches.append(String(ref.name.dropFirst("refs/heads/".count)))
            } else if ref.name.hasPrefix("refs/tags/") {
                localName = ref.name
                report.tags.append(String(ref.name.dropFirst("refs/tags/".count)))
            } else {
                continue
            }
            if !dryRun {
                _ = try repo.refs.updateRef(localName, to: spacesOID)
                try repo.appendReflog(refName: localName, old: nil, new: spacesOID,
                                      message: "imported from git")
            }
        }

        // 7) Set HEAD to default branch.
        if !dryRun {
            let defaultBranch = repo.config.core.defaultBranch
            if try repo.refs.readRef("refs/heads/\(defaultBranch)") != nil {
                try repo.refs.setHEAD(ref: "refs/heads/\(defaultBranch)")
            } else if let first = report.branches.first {
                try repo.refs.setHEAD(ref: "refs/heads/\(first)")
                // Materialize worktree.
                if let oid = try repo.refs.readRef("refs/heads/\(first)") {
                    let commit = try repo.commitObject(oid)
                    try MergeEngine(repo: repo).checkoutTree(commit.tree, overlay: [:])
                    let flat = try TreeBuilder.flattenTree(repo: repo, treeOID: commit.tree)
                    var index = Index()
                    for (path, e) in flat {
                        let url = try repo.worktreeURL(forRelativePath: path)
                        index.entries[path] = try Index.entry(forFileAt: url, oid: e.oid, mode: e.mode)
                    }
                    try repo.saveIndex(index)
                }
            }
            // Migration log.
            let log = "imported \(report.commits) commits, \(report.objectsWritten) objects from \(gitPath) at \(Int64(Date().timeIntervalSince1970))\n"
            try Data(log.utf8).write(to: repo.metaURL.appendingPathComponent("migration.log"),
                                     options: .atomic)
        }
        return report
    }

    // MARK: - Git object parsing

    private func catFile(git: String, path: String, oid: String, size: Int, type: String) throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: git)
        process.arguments = ["-C", path, "cat-file", type, oid]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw SpacesError.migrationError("git cat-file failed for \(oid)")
        }
        return data
    }

    /// Parses a git tree object (binary) into a Spaces TreePayload.
    /// Git tree entry: "<mode> <name>\0<20-byte-sha1>".
    private func convertGitTree(_ data: Data, oidMap: [String: ObjectID]) throws -> TreePayload? {
        var entries: [TreeEntry] = []
        var i = data.startIndex
        while i < data.endIndex {
            // Read mode until space.
            guard let spaceIdx = data[i...].firstIndex(of: 0x20) else { return nil }
            let modeStr = String(decoding: data[i..<spaceIdx], as: UTF8.self)
            guard let nulIdx = data[(spaceIdx + 1)...].firstIndex(of: 0x00) else { return nil }
            let name = String(decoding: data[(spaceIdx + 1)..<nulIdx], as: UTF8.self)
            let shaStart = data.index(after: nulIdx)
            guard shaStart + 20 <= data.endIndex else { return nil }
            let sha = data[shaStart..<(shaStart + 20)]
            let gitOID = sha.map { String(format: "%02x", $0) }.joined()
            i = shaStart + 20

            guard let spacesOID = oidMap[gitOID] else { return nil } // subtree not yet imported
            let mode: FileMode
            switch modeStr {
            case "40000": mode = .directory
            case "120000": mode = .symlink
            case "100755": mode = .executable
            default: mode = .regular
            }
            entries.append(TreeEntry(name: name, mode: mode, oid: spacesOID))
        }
        entries.sort {
            func sk(_ e: TreeEntry) -> String { e.mode.isDirectory ? e.name + "/" : e.name }
            return sk($0) < sk($1)
        }
        return TreePayload(entries: entries)
    }

    /// Parses a git commit object into a Spaces CommitPayload.
    /// Format: headers (tree, parent, author, committer, ...) then message.
    private func parseGitCommit(_ data: Data, oidMap: [String: ObjectID]) -> CommitPayload? {
        let text = String(decoding: data, as: UTF8.self)
        let allParts = text.components(separatedBy: "\n\n")
        guard allParts.count >= 2 else { return nil }
        let headers = allParts[0].components(separatedBy: "\n")
        let message = allParts.dropFirst().joined(separator: "\n\n")

        var treeOID: ObjectID?
        var parents: [ObjectID] = []
        var author: Signature?
        var committer: Signature?

        for line in headers {
            if line.hasPrefix("tree ") {
                let hex = String(line.dropFirst(5))
                // Git SHA-1 hex → we can't map object IDs across hash
                // algorithms; look up in oidMap.
                treeOID = oidMap[hex]
            } else if line.hasPrefix("parent ") {
                let hex = String(line.dropFirst(7))
                if let mapped = oidMap[hex] { parents.append(mapped) }
            } else if line.hasPrefix("author ") {
                author = parseGitSignature(String(line.dropFirst(7)))
            } else if line.hasPrefix("committer ") {
                committer = parseGitSignature(String(line.dropFirst(10)))
            }
        }
        guard let tree = treeOID, let a = author, let c = committer else { return nil }
        return CommitPayload(tree: tree, parents: parents, author: a, committer: c,
                             message: message, metadata: CommitMetadata())
    }

    /// Extracts the `parent <hex>` header values from a raw git commit object.
    private func gitCommitParentHexes(_ data: Data) -> [String] {
        let text = String(decoding: data, as: UTF8.self)
        var hexes: [String] = []
        for line in text.components(separatedBy: "\n") {
            if line.hasPrefix("parent ") { hexes.append(String(line.dropFirst(7))) }
            else if line.isEmpty { break }
        }
        return hexes
    }

    /// Parses "Name <email> timestamp tz" git signature.
    private func parseGitSignature(_ s: String) -> Signature? {
        // Format: "Name <email> 1234567890 +0000"
        guard let lt = s.firstIndex(of: "<"), let gt = s.firstIndex(of: ">") else { return nil }
        let name = String(s[..<lt]).trimmingCharacters(in: .whitespaces)
        let email = String(s[s.index(after: lt)..<gt])
        let rest = s[s.index(after: gt)...].trimmingCharacters(in: .whitespaces)
        let ts = Int64(rest.split(separator: " ").first ?? "0") ?? 0
        return Signature(name: name, email: email, timestamp: ts)
    }

    /// Parses a git tag object.
    private func parseGitTagObject(_ data: Data, oidMap: [String: ObjectID]) -> TagPayload? {
        let text = String(decoding: data, as: UTF8.self)
        let allParts = text.components(separatedBy: "\n\n")
        guard allParts.count >= 2 else { return nil }
        let headers = allParts[0].components(separatedBy: "\n")
        let tagMessage = allParts.dropFirst().joined(separator: "\n\n")
        var objectHex: String?
        var objectType: ObjectType = .commit
        var tagger: Signature?
        var tagName = ""
        for line in headers {
            if line.hasPrefix("object ") { objectHex = String(line.dropFirst(7)) }
            else if line.hasPrefix("type ") {
                objectType = ObjectType(rawValue: String(line.dropFirst(5))) ?? .commit
            }
            else if line.hasPrefix("tag ") { tagName = String(line.dropFirst(4)) }
            else if line.hasPrefix("tagger ") { tagger = parseGitSignature(String(line.dropFirst(7))) }
        }
        guard let hex = objectHex, let oid = oidMap[hex] else { return nil }
        return TagPayload(object: oid, objectType: objectType, name: tagName,
                          tagger: tagger, message: tagMessage)
    }

    // MARK: - Export

    public struct ExportReport: Sendable, Encodable {
        public var gitDir: String
        public var objectsWritten: Int
        public var refsWritten: [String]
        public var warnings: [String]
    }

    /// Exports this Spaces repository to a Git-format repository at
    /// `destPath` (creates `<destPath>/.git`). Uses `git hash-object -w`,
    /// `git mktree`, `git commit-tree`, `git update-ref` in the destination —
    /// the migration subsystem may use git to write git formats.
    @discardableResult
    public func exportGit(to destPath: String, only: [String] = []) throws -> ExportReport {
        let git = try findGit()
        let dest = URL(fileURLWithPath: destPath)
        try FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
        // `git init` creates a proper .git (objects/, refs/, HEAD, config) —
        // hash-object/mktree/commit-tree require it.
        _ = try runGitRaw(git, ["-C", destPath, "init", "-q"])
        let gitDir = dest.appendingPathComponent(".git")

        var report = ExportReport(gitDir: gitDir.path, objectsWritten: 0,
                                  refsWritten: [], warnings: [])

        // Collect commits to export (all history or selected branches).
        var seeds: [ObjectID] = []
        if only.isEmpty {
            for ref in try repo.refs.allRefs() where ref.kind == .branch || ref.kind == .tag {
                seeds.append(ref.oid)
            }
        } else {
            for name in only {
                seeds.append(try repo.resolveRevision(name))
            }
        }
        let reachable = try repo.objects.reachable(from: seeds)

        // Export objects oldest-first: trees/blobs before commits that use
        // them isn't required by git, but commit-tree needs tree OIDs in git
        // format — we must write git objects and map spaces oid → git oid.
        var oidMap: [ObjectID: String] = [:]

        // 1) Blobs.
        for id in reachable.sorted() {
            guard let stored = try? repo.objects.read(id), stored.type == .blob else { continue }
            let gitOID = try writeGitBlob(git: git, gitDir: dest.path, payload: stored.payload)
            oidMap[id] = gitOID
            report.objectsWritten += 1
        }

        // 2) Trees (need children mapped — iterate until stable).
        var pendingTrees = reachable.filter { id in
            (try? repo.objects.read(id).type) == .tree
        }
        var guardCount = 0
        while !pendingTrees.isEmpty && guardCount < 20 {
            guardCount += 1
            var still = Set<ObjectID>()
            for id in pendingTrees {
                guard let stored = try? repo.objects.read(id, expectedType: .tree),
                      let tree = try? JSONDecoder().decode(TreePayload.self, from: stored.payload) else {
                    still.insert(id); continue
                }
                // All children must be mapped.
                var ready = true
                for e in tree.entries where !e.mode.isDirectory {
                    if oidMap[e.oid] == nil { ready = false; break }
                }
                // Directory children are trees — check they have git oids too
                // (trees are written bottom-up via iteration).
                for e in tree.entries where e.mode.isDirectory {
                    if oidMap[e.oid] == nil { ready = false; break }
                }
                if !ready { still.insert(id); continue }
                let gitOID = try writeGitTree(git: git, gitDir: dest.path, tree: tree, oidMap: oidMap)
                oidMap[id] = gitOID
                report.objectsWritten += 1
            }
            pendingTrees = still
        }
        if !pendingTrees.isEmpty {
            report.warnings.append("\(pendingTrees.count) trees not exported")
        }

        // 3) Commits — parents must be written before children, so iterate
        // to a fixpoint rather than relying on object-ID order.
        var commitOIDMap: [ObjectID: String] = [:]
        var pendingCommits = reachable.filter { id in
            (try? repo.objects.read(id).type) == .commit
        }
        guardCount = 0
        while !pendingCommits.isEmpty && guardCount < 50 {
            guardCount += 1
            var still = Set<ObjectID>()
            for id in pendingCommits {
                guard let stored = try? repo.objects.read(id, expectedType: .commit),
                      let commit = try? JSONDecoder().decode(CommitPayload.self, from: stored.payload),
                      let treeGitOID = oidMap[commit.tree],
                      commit.parents.allSatisfy({ commitOIDMap[$0] != nil }) else {
                    still.insert(id); continue
                }
                let parents = commit.parents.compactMap { commitOIDMap[$0] }
                let gitOID = try writeGitCommit(git: git, gitDir: dest.path,
                                                commit: commit, treeGitOID: treeGitOID,
                                                parentGitOIDs: parents)
                commitOIDMap[id] = gitOID
                report.objectsWritten += 1
            }
            pendingCommits = still
        }
        if !pendingCommits.isEmpty {
            report.warnings.append("\(pendingCommits.count) commits not exported")
        }

        // 4) Tags.
        var tagOIDMap: [ObjectID: String] = [:]
        for id in reachable.sorted() {
            guard let stored = try? repo.objects.read(id), stored.type == .tag,
                  let tag = try? JSONDecoder().decode(TagPayload.self, from: stored.payload) else { continue }
            let targetGitOID = tag.objectType == .commit ? commitOIDMap[tag.object] : oidMap[tag.object]
            guard let target = targetGitOID else { continue }
            let gitOID = try writeGitTagObject(git: git, gitDir: dest.path, tag: tag,
                                               targetGitOID: target)
            tagOIDMap[id] = gitOID
            report.objectsWritten += 1
        }

        // 5) Refs.
        for ref in try repo.refs.allRefs() {
            var gitOID: String? = nil
            switch ref.kind {
            case .branch, .remote:
                gitOID = commitOIDMap[ref.oid]
            case .tag:
                // Annotated tag → tag object; lightweight → commit.
                if let t = tagOIDMap[ref.oid] { gitOID = t }
                else { gitOID = commitOIDMap[ref.oid] }
            default: break
            }
            guard let oid = gitOID else { continue }
            let gitRefName = ref.name // same naming convention
            try runGitRaw(git, ["-C", dest.path, "update-ref", gitRefName, oid])
            report.refsWritten.append(gitRefName)
        }
        // HEAD.
        if let sym = try repo.refs.symbolicHEAD() {
            let branch = String(sym.dropFirst("refs/heads/".count))
            try? runGitRaw(git, ["-C", dest.path, "symbolic-ref", "HEAD",
                                 "refs/heads/\(branch)"])
        }

        // Init marker: ensure .git looks like a repo.
        try? runGitRaw(git, ["-C", dest.path, "rev-parse", "--git-dir"])
        return report
    }

    // MARK: - Git object writers

    private func writeGitBlob(git: String, gitDir: String, payload: Data) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: git)
        process.arguments = ["-C", gitDir, "hash-object", "-w", "--stdin"]
        let inPipe = Pipe(), outPipe = Pipe()
        process.standardInput = inPipe
        process.standardOutput = outPipe
        process.standardError = Pipe()
        try process.run()
        inPipe.fileHandleForWriting.write(payload)
        try? inPipe.fileHandleForWriting.close()
        process.waitUntilExit()
        let out = String(decoding: outPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        guard process.terminationStatus == 0 else {
            throw SpacesError.migrationError("git hash-object failed")
        }
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func writeGitTree(git: String, gitDir: String, tree: TreePayload,
                              oidMap: [ObjectID: String]) throws -> String {
        // `git mktree` input format: "<mode> <type> <oid>\t<name>"
        var input = ""
        for e in tree.entries {
            guard let childOID = oidMap[e.oid] else {
                throw SpacesError.migrationError("tree child not exported: \(e.name)")
            }
            let type = e.mode.isDirectory ? "tree" : "blob"
            input += "\(e.mode.rawValue) \(type) \(childOID)\t\(e.name)\n"
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: git)
        process.arguments = ["-C", gitDir, "mktree"]
        let inPipe = Pipe(), outPipe = Pipe()
        process.standardInput = inPipe
        process.standardOutput = outPipe
        process.standardError = Pipe()
        try process.run()
        inPipe.fileHandleForWriting.write(Data(input.utf8))
        try? inPipe.fileHandleForWriting.close()
        process.waitUntilExit()
        let out = String(decoding: outPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        guard process.terminationStatus == 0 else {
            throw SpacesError.migrationError("git mktree failed")
        }
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func writeGitCommit(git: String, gitDir: String, commit: CommitPayload,
                                treeGitOID: String, parentGitOIDs: [String]) throws -> String {
        // commit-tree takes tree/parents as arguments and identity from
        // GIT_AUTHOR_*/GIT_COMMITTER_* env vars; stdin is the message body.
        var input = ""
        for (k, v) in commit.metadata.trailers.sorted(by: { $0.key < $1.key }) {
            input += "\(k): \(v)\n"
        }
        input += "\(commit.message)\n"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: git)
        process.arguments = ["-C", gitDir, "commit-tree", treeGitOID]
        if !parentGitOIDs.isEmpty {
            process.arguments!.append(contentsOf: parentGitOIDs.flatMap { ["-p", $0] })
        }
        var env = ProcessInfo.processInfo.environment
        applyGitIdentity(&env, prefix: "GIT_AUTHOR_", sig: commit.author)
        applyGitIdentity(&env, prefix: "GIT_COMMITTER_", sig: commit.committer)
        process.environment = env
        let inPipe = Pipe(), outPipe = Pipe()
        process.standardInput = inPipe
        process.standardOutput = outPipe
        process.standardError = Pipe()
        try process.run()
        inPipe.fileHandleForWriting.write(Data(input.utf8))
        try? inPipe.fileHandleForWriting.close()
        process.waitUntilExit()
        let out = String(decoding: outPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        guard process.terminationStatus == 0 else {
            throw SpacesError.migrationError("git commit-tree failed")
        }
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func writeGitTagObject(git: String, gitDir: String, tag: TagPayload,
                                   targetGitOID: String) throws -> String {
        var input = "object \(targetGitOID)\n"
        input += "type \(tag.objectType.rawValue)\n"
        input += "tag \(tag.name)\n"
        if let tagger = tag.tagger {
            input += "tagger \(gitSignature(tagger))\n"
        }
        input += "\n\(tag.message)\n"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: git)
        process.arguments = ["-C", gitDir, "mktag"]
        let inPipe = Pipe(), outPipe = Pipe()
        process.standardInput = inPipe
        process.standardOutput = outPipe
        process.standardError = Pipe()
        try process.run()
        inPipe.fileHandleForWriting.write(Data(input.utf8))
        try? inPipe.fileHandleForWriting.close()
        process.waitUntilExit()
        let out = String(decoding: outPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        guard process.terminationStatus == 0 else {
            throw SpacesError.migrationError("git mktag failed")
        }
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Sets GIT_<ROLE>_NAME/EMAIL/DATE for commit-tree/mktag identity.
    private func applyGitIdentity(_ env: inout [String: String], prefix: String,
                                  sig: Signature) {
        env[prefix + "NAME"] = sig.name
        env[prefix + "EMAIL"] = sig.email
        let tz = TimeZone.current.secondsFromGMT(for: Date(timeIntervalSince1970: TimeInterval(sig.timestamp)))
        let sign = tz >= 0 ? "+" : "-"
        let absTz = abs(tz)
        env[prefix + "DATE"] = "@\(sig.timestamp) \(sign)\(String(format: "%02d%02d", absTz / 3600, (absTz % 3600) / 60))"
    }

    private func gitSignature(_ s: Signature) -> String {
        // "Name <email> epoch tz"
        let tz = TimeZone.current.secondsFromGMT(for: Date(timeIntervalSince1970: TimeInterval(s.timestamp)))
        let sign = tz >= 0 ? "+" : "-"
        let absTz = abs(tz)
        let hh = absTz / 3600, mm = (absTz % 3600) / 60
        return "\(s.name) <\(s.email)> \(s.timestamp) \(sign)\(String(format: "%02d%02d", hh, mm))"
    }

    // MARK: - Git helpers

    private func findGit() throws -> String {
        for path in ["/usr/bin/git", "/opt/homebrew/bin/git", "/usr/local/bin/git"] {
            if FileManager.default.isExecutableFile(atPath: path) { return path }
        }
        // PATH lookup.
        if let pathEnv = ProcessInfo.processInfo.environment["PATH"] {
            for dir in pathEnv.components(separatedBy: ":") {
                let candidate = dir + "/git"
                if FileManager.default.isExecutableFile(atPath: candidate) { return candidate }
            }
        }
        throw SpacesError.migrationError("git executable not found (required only for import/export)")
    }

    private func resolveGitDir(git: String, path: String) throws -> String {
        // git rev-parse --git-dir
        let out = try runGitRaw(git, ["-C", path, "rev-parse", "--git-dir"])
        var dir = out.trimmingCharacters(in: .whitespacesAndNewlines)
        if !dir.hasPrefix("/") {
            dir = URL(fileURLWithPath: path).appendingPathComponent(dir).path
        }
        return dir
    }

    @discardableResult
    private func runGitRaw(_ git: String, _ args: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: git)
        process.arguments = args
        let outPipe = Pipe(), errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        try process.run()
        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let out = String(decoding: outData, as: UTF8.self)
        let err = String(decoding: errData, as: UTF8.self)
        guard process.terminationStatus == 0 else {
            throw SpacesError.migrationError("git \(args.joined(separator: " ")) failed: \(err)")
        }
        return out
    }
}
