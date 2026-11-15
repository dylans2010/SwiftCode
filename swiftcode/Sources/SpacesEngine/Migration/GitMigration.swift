import Foundation



public struct GitMigration {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public static let gitlinkMarkerPrefix = "spaces-gitlink:"

    public struct GitlinkEntry: Sendable, Codable {
        public var path: String
        public var target: String
        public init(path: String, target: String) {
            self.path = path
            self.target = target
        }
    }

    public struct LFSPointerEntry: Sendable, Codable {
        public var path: String
        public var oid: String
        public var size: Int64
        public var objectImported: Bool
        public init(path: String, oid: String, size: Int64, objectImported: Bool) {
            self.path = path
            self.oid = oid
            self.size = size
            self.objectImported = objectImported
        }
    }

    public struct ImportReport: Sendable, Encodable {
        public var objectsWritten: Int
        public var commits: Int
        public var branches: [String]
        public var tags: [String]
        public var warnings: [String]
        public var gitlinks: [GitlinkEntry] = []
        public var lfsPointers: [LFSPointerEntry] = []
        public var notesImported: Int = 0
        public var notesRefs: [String] = []
        public var gpgSignatures: [String] = []
    }

    private struct LFSPointer: Sendable {
        var oid: String
        var size: Int64
    }

    private struct CollectedLFSPointer: Sendable {
        var pointer: LFSPointer
        var objectImported: Bool
    }

    @discardableResult
    public func importGit(at gitPath: String, dryRun: Bool = false) throws -> ImportReport {
        let git = try findGit()
        let gitDir = try resolveGitDir(git: git, path: gitPath)
        let commonDir = resolveGitCommonDir(git: git, path: gitPath, gitDir: gitDir)

        var report = ImportReport(objectsWritten: 0, commits: 0,
                                  branches: [], tags: [], warnings: [])

        let refsOut = try runGitRaw(git, ["-C", gitPath, "for-each-ref",
                                       "--format=%(refname) %(objectname)"])
        struct RefLine { var name: String; var oid: String }
        var refLines: [RefLine] = []
        for line in refsOut.components(separatedBy: "\n") where !line.isEmpty {
            let parts = line.split(separator: " ", maxSplits: 1).map(String.init)
            if parts.count == 2 { refLines.append(RefLine(name: parts[0], oid: parts[1])) }
        }

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
        let commitHexes = Set(infos.filter { $0.type == "commit" }.map { $0.oid })

        if let remotesOut = runGitOptional(git, ["-C", gitPath, "remote"]) {
            let names = remotesOut.components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            if !names.isEmpty {
                report.warnings.append("source git remotes (\(names.joined(separator: ", "))) were not imported into Spaces configuration; re-add them with spaces remote add")
            }
        }
        if let configOut = runGitOptional(git, ["-C", gitPath, "config", "--local", "--list"]) {
            let keyCount = configOut.components(separatedBy: "\n").filter { !$0.isEmpty }.count
            if keyCount > 0 {
                report.warnings.append("source git configuration (\(keyCount) local keys) was not imported; Spaces keeps its own configuration")
            }
        }
        let sourceHooksDir = URL(fileURLWithPath: gitDir).appendingPathComponent("hooks")
        if let hookFiles = try? FileManager.default.contentsOfDirectory(atPath: sourceHooksDir.path) {
            let installed = hookFiles.filter { !$0.hasSuffix(".sample") }.sorted()
            if !installed.isEmpty {
                report.warnings.append("source git hooks (\(installed.joined(separator: ", "))) were not imported")
            }
        }
        let sourceLogsDir = URL(fileURLWithPath: gitDir).appendingPathComponent("logs")
        if FileManager.default.fileExists(atPath: sourceLogsDir.path) {
            report.warnings.append("source git reflogs were not imported; Spaces reflogs start from this import")
        }

        var oidMap: [String: ObjectID] = [:]
        var lfsPointersByBlob: [String: CollectedLFSPointer] = [:]

        for pass in ["blob", "tree"] {
            for info in infos where info.type == pass {
                let payload = try catFile(git: git, path: gitPath, oid: info.oid, size: info.size, type: info.type)
                if pass == "blob" {
                    let spacesOID = ObjectID.blob(payload)
                    if !dryRun { _ = try repo.objects.write(type: .blob, payload: payload) }
                    oidMap[info.oid] = spacesOID
                    report.objectsWritten += 1
                    if let pointer = parseLFSPointer(payload) {
                        var imported = false
                        if let sourcePath = localLFSObjectPath(oid: pointer.oid, gitDir: gitDir, commonDir: commonDir) {
                            if dryRun {
                                imported = true
                            } else {
                                let lfsDir = repo.metaURL.appendingPathComponent("lfs/objects")
                                try? FileManager.default.createDirectory(at: lfsDir, withIntermediateDirectories: true)
                                let dest = lfsDir.appendingPathComponent(pointer.oid)
                                if !FileManager.default.fileExists(atPath: dest.path) {
                                    try? FileManager.default.copyItem(atPath: sourcePath, toPath: dest.path)
                                }
                                imported = FileManager.default.fileExists(atPath: dest.path)
                            }
                        }
                        lfsPointersByBlob[info.oid] = CollectedLFSPointer(pointer: pointer, objectImported: imported)
                    }
                } else {
                    var gitlinkMarkers = 0
                    let treePayload = try convertGitTree(payload, oidMap: oidMap, dryRun: dryRun, gitlinkMarkers: &gitlinkMarkers)
                    if let tp = treePayload {
                        let spacesOID: ObjectID
                        if dryRun {
                            spacesOID = try computedObjectID(.tree, value: tp)
                        } else {
                            spacesOID = try repo.objects.write(.tree, value: tp)
                        }
                        oidMap[info.oid] = spacesOID
                        report.objectsWritten += 1 + gitlinkMarkers
                    } else {
                        report.warnings.append("skipped unconvertible tree \(info.oid)")
                    }
                }
            }
        }

        var pendingTrees = infos.filter { $0.type == "tree" && oidMap[$0.oid] == nil }
        var guardCount = 0
        while !pendingTrees.isEmpty && guardCount < 10 {
            guardCount += 1
            var stillPending: [ObjInfo] = []
            for info in pendingTrees {
                let payload = try catFile(git: git, path: gitPath, oid: info.oid, size: info.size, type: info.type)
                var gitlinkMarkers = 0
                if let tp = try convertGitTree(payload, oidMap: oidMap, dryRun: dryRun, gitlinkMarkers: &gitlinkMarkers) {
                    let spacesOID: ObjectID
                    if dryRun {
                        spacesOID = try computedObjectID(.tree, value: tp)
                    } else {
                        spacesOID = try repo.objects.write(.tree, value: tp)
                    }
                    oidMap[info.oid] = spacesOID
                    report.objectsWritten += 1 + gitlinkMarkers
                } else {
                    stillPending.append(info)
                }
            }
            pendingTrees = stillPending
        }
        if !pendingTrees.isEmpty {
            report.warnings.append("\(pendingTrees.count) trees could not be converted (missing subtrees)")
        }

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
                guard let commitPayload = parseGitCommit(payload, oidMap: oidMap, gitOID: info.oid, warnings: &report.warnings) else {
                    report.warnings.append("skipped unparseable commit \(info.oid)")
                    progress = true
                    continue
                }
                let spacesOID: ObjectID
                if dryRun {
                    spacesOID = try computedObjectID(.commit, value: commitPayload)
                } else {
                    spacesOID = try repo.objects.write(.commit, value: commitPayload)
                }
                oidMap[info.oid] = spacesOID
                report.commits += 1
                report.objectsWritten += 1
                if commitPayload.metadata.signature != nil {
                    report.gpgSignatures.append(info.oid)
                }
                progress = true
            }
            pendingCommits = still
            if !progress && !pendingCommits.isEmpty { break }
        }
        for info in pendingCommits {
            report.warnings.append("skipped commit \(info.oid) (unresolved parents)")
        }

        for info in infos where info.type == "tag" {
            let payload = try catFile(git: git, path: gitPath, oid: info.oid, size: info.size, type: info.type)
            if let tagPayload = parseGitTagObject(payload, oidMap: oidMap) {
                let spacesOID: ObjectID
                if dryRun {
                    spacesOID = try computedObjectID(.tag, value: tagPayload)
                } else {
                    spacesOID = try repo.objects.write(.tag, value: tagPayload)
                }
                oidMap[info.oid] = spacesOID
                report.objectsWritten += 1
            } else {
                report.warnings.append("skipped unparseable tag object \(info.oid)")
            }
        }

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
            } else if ref.name.hasPrefix("refs/notes/") {
                continue
            } else {
                report.warnings.append("skipped ref \(ref.name) (outside refs/heads/ and refs/tags/)")
                continue
            }
            if !dryRun {
                _ = try repo.refs.updateRef(localName, to: spacesOID)
                try repo.appendReflog(refName: localName, old: nil, new: spacesOID,
                                      message: "imported from git")
            }
        }

        var gitlinkEntries: [GitlinkEntry] = []
        var lfsEntries: [LFSPointerEntry] = []
        var seenGitlinkPaths = Set<String>()
        var seenLFSPaths = Set<String>()
        for ref in refLines where ref.name.hasPrefix("refs/heads/") || ref.name.hasPrefix("refs/tags/") {
            guard let listing = runGitOptional(git, ["-C", gitPath, "ls-tree", "-r", ref.name]) else { continue }
            for line in listing.components(separatedBy: "\n") where !line.isEmpty {
                guard let tabIdx = line.firstIndex(of: "\t") else { continue }
                let meta = String(line[..<tabIdx])
                let path = String(line[line.index(after: tabIdx)...])
                let fields = meta.split(separator: " ").map(String.init)
                guard fields.count == 3 else { continue }
                let mode = fields[0], type = fields[1], oid = fields[2]
                if mode == "160000" {
                    if seenGitlinkPaths.insert(path).inserted {
                        gitlinkEntries.append(GitlinkEntry(path: path, target: oid))
                        if !commitHexes.contains(oid) {
                            report.warnings.append("gitlink \(path) points at commit \(oid) which is not present in the source repository")
                        }
                    }
                } else if type == "blob", let collected = lfsPointersByBlob[oid] {
                    if seenLFSPaths.insert(path).inserted {
                        lfsEntries.append(LFSPointerEntry(path: path, oid: collected.pointer.oid, size: collected.pointer.size, objectImported: collected.objectImported))
                        if !collected.objectImported {
                            report.warnings.append("LFS object \(collected.pointer.oid) (\(collected.pointer.size) bytes) for \(path) is not present in the source repository; the pointer file was imported but the file content was not (remote LFS transfer is not implemented)")
                        }
                    }
                }
            }
        }
        report.gitlinks = gitlinkEntries
        report.lfsPointers = lfsEntries
        if !gitlinkEntries.isEmpty {
            report.warnings.append("imported \(gitlinkEntries.count) gitlink(s) as tracked marker entries (see migration/gitlinks.json); submodule contents are not checked out")
        }

        var notesByCommit: [String: [String]] = [:]
        var notesCount = 0
        for ref in refLines where ref.name.hasPrefix("refs/notes/") {
            let shortName = String(ref.name.dropFirst("refs/notes/".count))
            report.notesRefs.append(ref.name)
            guard let listing = runGitOptional(git, ["-C", gitPath, "notes", "--ref=" + shortName, "list"]) else {
                report.warnings.append("could not list git notes for \(ref.name); its notes were not imported")
                continue
            }
            for line in listing.components(separatedBy: "\n") where !line.isEmpty {
                let fields = line.split(separator: " ").map(String.init)
                guard fields.count == 2 else { continue }
                let noteOID = fields[0], targetHex = fields[1]
                guard let spacesOID = oidMap[targetHex] else {
                    report.warnings.append("note in \(ref.name) targets unimported commit \(targetHex); the note was skipped")
                    continue
                }
                guard let noteData = try? catFile(git: git, path: gitPath, oid: noteOID, size: 0, type: "blob") else {
                    report.warnings.append("note blob \(noteOID) in \(ref.name) could not be read; the note was skipped")
                    continue
                }
                var text = String(decoding: noteData, as: UTF8.self)
                while text.hasSuffix("\n") { text = String(text.dropLast()) }
                notesByCommit[spacesOID.hex, default: []].append(text)
                notesCount += 1
            }
        }
        report.notesImported = notesCount

        if !dryRun {
            if !gitlinkEntries.isEmpty || !lfsEntries.isEmpty {
                let migrationDir = repo.metaURL.appendingPathComponent("migration")
                try? FileManager.default.createDirectory(at: migrationDir, withIntermediateDirectories: true)
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.sortedKeys]
                if !gitlinkEntries.isEmpty, let data = try? encoder.encode(gitlinkEntries) {
                    try? data.write(to: migrationDir.appendingPathComponent("gitlinks.json"), options: .atomic)
                }
                if !lfsEntries.isEmpty, let data = try? encoder.encode(lfsEntries) {
                    try? data.write(to: migrationDir.appendingPathComponent("lfs-pointers.json"), options: .atomic)
                }
            }
            if !notesByCommit.isEmpty {
                let notesURL = repo.metaURL.appendingPathComponent("notes.json")
                var existing: [String: [String]] = [:]
                if let data = try? Data(contentsOf: notesURL),
                   let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) {
                    existing = decoded
                }
                for (key, values) in notesByCommit {
                    existing[key, default: []].append(contentsOf: values)
                }
                if let data = try? JSONEncoder().encode(existing) {
                    try? data.write(to: notesURL, options: .atomic)
                }
            }
            let defaultBranch = repo.config.core.defaultBranch
            if try repo.refs.readRef("refs/heads/\(defaultBranch)") != nil {
                try repo.refs.setHEAD(ref: "refs/heads/\(defaultBranch)")
            } else if let first = report.branches.first {
                try repo.refs.setHEAD(ref: "refs/heads/\(first)")

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

            let log = "imported \(report.commits) commits, \(report.objectsWritten) objects from \(gitPath) at \(Int64(Date().timeIntervalSince1970))\n"
            try Data(log.utf8).write(to: repo.metaURL.appendingPathComponent("migration.log"),
                                     options: .atomic)
        }
        return report
    }

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

    private func parseLFSPointer(_ data: Data) -> LFSPointer? {
        guard data.count < 512 else { return nil }
        let text = String(decoding: data, as: UTF8.self)
        let lines = text.components(separatedBy: "\n")
        guard let first = lines.first, first.hasPrefix("version ") else { return nil }
        var oid: String? = nil
        var size: Int64? = nil
        for line in lines {
            if line.hasPrefix("oid sha256:") {
                oid = String(line.dropFirst("oid sha256:".count))
            } else if line.hasPrefix("size ") {
                size = Int64(String(line.dropFirst(5)))
            }
        }
        guard let foundOID = oid, foundOID.count == 64, foundOID.allSatisfy({ $0.isHexDigit }),
              let foundSize = size else { return nil }
        return LFSPointer(oid: foundOID, size: foundSize)
    }

    private func localLFSObjectPath(oid: String, gitDir: String, commonDir: String) -> String? {
        let first = String(oid.prefix(2))
        let second = String(oid.dropFirst(2).prefix(2))
        for base in [gitDir, commonDir] {
            for candidate in [base + "/lfs/objects/" + first + "/" + second + "/" + oid,
                              base + "/lfs/objects/" + oid] {
                if FileManager.default.fileExists(atPath: candidate) { return candidate }
            }
        }
        return nil
    }

    private func resolveGitCommonDir(git: String, path: String, gitDir: String) -> String {
        guard let out = runGitOptional(git, ["-C", path, "rev-parse", "--git-common-dir"]) else { return gitDir }
        let trimmed = out.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("/") { return trimmed }
        return URL(fileURLWithPath: path).appendingPathComponent(trimmed).path
    }

    private func convertGitTree(_ data: Data, oidMap: [String: ObjectID], dryRun: Bool, gitlinkMarkers: inout Int) throws -> TreePayload? {
        var entries: [TreeEntry] = []
        var i = data.startIndex
        while i < data.endIndex {
            guard let spaceIdx = data[i...].firstIndex(of: 0x20) else { return nil }
            let modeStr = String(decoding: data[i..<spaceIdx], as: UTF8.self)
            guard let nulIdx = data[(spaceIdx + 1)...].firstIndex(of: 0x00) else { return nil }
            let name = String(decoding: data[(spaceIdx + 1)..<nulIdx], as: UTF8.self)
            let shaStart = data.index(after: nulIdx)
            guard shaStart + 20 <= data.endIndex else { return nil }
            let sha = data[shaStart..<(shaStart + 20)]
            let gitOID = sha.map { String(format: "%02x", $0) }.joined()
            i = shaStart + 20

            if modeStr == "160000" {
                let marker = Data((GitMigration.gitlinkMarkerPrefix + gitOID + "\n").utf8)
                let spacesOID: ObjectID
                if dryRun {
                    spacesOID = ObjectID.blob(marker)
                } else {
                    spacesOID = try repo.objects.write(type: .blob, payload: marker)
                }
                gitlinkMarkers += 1
                entries.append(TreeEntry(name: name, mode: .regular, oid: spacesOID))
                continue
            }
            guard let spacesOID = oidMap[gitOID] else { return nil }
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

    private func parseGitCommit(_ data: Data, oidMap: [String: ObjectID], gitOID: String, warnings: inout [String]) -> CommitPayload? {
        let text = String(decoding: data, as: UTF8.self)
        let allParts = text.components(separatedBy: "\n\n")
        guard allParts.count >= 2 else { return nil }
        let rawHeaders = allParts[0].components(separatedBy: "\n")
        let message = allParts.dropFirst().joined(separator: "\n\n")

        var headers: [(key: String, value: String)] = []
        for line in rawHeaders {
            if line.hasPrefix(" "), let last = headers.indices.last {
                headers[last].value += "\n" + String(line.dropFirst())
            } else if let spaceIdx = line.firstIndex(of: " ") {
                headers.append((key: String(line[..<spaceIdx]), value: String(line[line.index(after: spaceIdx)...])))
            } else {
                headers.append((key: line, value: ""))
            }
        }

        var treeOID: ObjectID?
        var parents: [ObjectID] = []
        var author: Signature?
        var committer: Signature?
        var authorOffset: Int?
        var committerOffset: Int?
        var signatureBlocks: [String] = []

        for header in headers {
            switch header.key {
            case "tree":
                treeOID = oidMap[header.value]
            case "parent":
                if let mapped = oidMap[header.value] { parents.append(mapped) }
            case "author":
                author = parseGitSignature(header.value)
                authorOffset = gitSignatureOffsetMinutes(header.value)
            case "committer":
                committer = parseGitSignature(header.value)
                committerOffset = gitSignatureOffsetMinutes(header.value)
            case "gpgsig":
                signatureBlocks.append(header.value)
            case "gpgsig-sha256":
                warnings.append("commit \(gitOID) carries a gpgsig-sha256 header which was not preserved; only the gpgsig payload is kept")
            case "mergetag":
                warnings.append("commit \(gitOID) contains an embedded mergetag which was not imported as a tag object")
            case "encoding":
                warnings.append("commit \(gitOID) declares encoding \(header.value); its message was imported as UTF-8")
            default:
                break
            }
        }
        guard let tree = treeOID, let a = author, let c = committer else { return nil }
        var metadata = CommitMetadata()
        if let off = authorOffset {
            metadata.trailers["X-Spaces-Author-TZ"] = gitOffsetToken(minutes: off)
        }
        if let off = committerOffset {
            metadata.trailers["X-Spaces-Committer-TZ"] = gitOffsetToken(minutes: off)
        }
        if !signatureBlocks.isEmpty {
            metadata.signature = signatureBlocks.joined(separator: "\n")
        }
        return CommitPayload(tree: tree, parents: parents, author: a, committer: c,
                             message: message, metadata: metadata)
    }

    private func computedObjectID<T: Encodable>(_ type: ObjectType, value: T) throws -> ObjectID {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return ObjectID.compute(type: type, payload: try encoder.encode(value))
    }

    private func gitSignatureOffsetMinutes(_ s: String) -> Int? {
        guard let gt = s.firstIndex(of: ">") else { return nil }
        let rest = s[s.index(after: gt)...].trimmingCharacters(in: .whitespaces)
        let parts = rest.split(separator: " ")
        guard parts.count == 2, let token = parts.last else { return nil }
        return gitOffsetTokenMinutes(String(token))
    }

    private func gitOffsetTokenMinutes(_ token: String) -> Int? {
        guard token.count == 5 else { return nil }
        let sign = token.first
        guard sign == "+" || sign == "-" else { return nil }
        let digits = token.dropFirst()
        guard digits.count == 4, digits.allSatisfy({ $0.isNumber }),
              let hh = Int(digits.prefix(2)), let mm = Int(digits.suffix(2)),
              hh < 24, mm < 60 else { return nil }
        let total = hh * 60 + mm
        return sign == "-" ? -total : total
    }

    private func gitOffsetToken(minutes: Int) -> String {
        let sign = minutes < 0 ? "-" : "+"
        let absMinutes = abs(minutes)
        return String(format: "%@%02d%02d", sign, absMinutes / 60, absMinutes % 60)
    }

    private func localOffsetMinutes(for sig: Signature) -> Int {
        TimeZone.current.secondsFromGMT(for: Date(timeIntervalSince1970: TimeInterval(sig.timestamp))) / 60
    }

    private func gitIdentityLine(keyword: String, sig: Signature, offsetMinutes: Int) -> String {
        "\(keyword) \(sig.name) <\(sig.email)> \(sig.timestamp) \(gitOffsetToken(minutes: offsetMinutes))\n"
    }

    private func gitCommitParentHexes(_ data: Data) -> [String] {
        let text = String(decoding: data, as: UTF8.self)
        var hexes: [String] = []
        for line in text.components(separatedBy: "\n") {
            if line.hasPrefix("parent ") { hexes.append(String(line.dropFirst(7))) }
            else if line.isEmpty { break }
        }
        return hexes
    }

    private func parseGitSignature(_ s: String) -> Signature? {
        guard let lt = s.firstIndex(of: "<"), let gt = s.firstIndex(of: ">") else { return nil }
        let name = String(s[..<lt]).trimmingCharacters(in: .whitespaces)
        let email = String(s[s.index(after: lt)..<gt])
        let rest = s[s.index(after: gt)...].trimmingCharacters(in: .whitespaces)
        let ts = Int64(rest.split(separator: " ").first ?? "0") ?? 0
        return Signature(name: name, email: email, timestamp: ts)
    }

    private func parseGitTagObject(_ data: Data, oidMap: [String: ObjectID]) -> TagPayload? {
        let text = String(decoding: data, as: UTF8.self)
        let allParts = text.components(separatedBy: "\n\n")
        guard allParts.count >= 2 else { return nil }
        let headers = allParts[0].components(separatedBy: "\n")
        var tagMessage = allParts.dropFirst().joined(separator: "\n\n")
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
        var signature: String? = nil
        if let sigRange = tagMessage.range(of: "-----BEGIN PGP SIGNATURE-----") {
            signature = String(tagMessage[sigRange.lowerBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            tagMessage = String(tagMessage[..<sigRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return TagPayload(object: oid, objectType: objectType, name: tagName,
                          tagger: tagger, message: tagMessage, signature: signature)
    }

    public struct ExportReport: Sendable, Encodable {
        public var gitDir: String
        public var objectsWritten: Int
        public var refsWritten: [String]
        public var warnings: [String]
        public var updatedExisting: Bool = false
        public var hooksExported: [String] = []
        public var reflogsExported: [String] = []
        public var configKeysWritten: [String] = []
    }

    @discardableResult
    public func exportGit(to destPath: String, only: [String] = [], force: Bool = false) throws -> ExportReport {
        let git = try findGit()
        let dest = URL(fileURLWithPath: destPath)
        let dotGit = dest.appendingPathComponent(".git")
        var existingGitDir: URL? = nil
        if isGitDirectory(dotGit) {
            existingGitDir = dotGit
        } else if isGitDirectory(dest) {
            existingGitDir = dest
        }

        let prefix: [String]
        let gitDir: URL
        var report: ExportReport
        if let existing = existingGitDir {
            gitDir = existing
            prefix = existing == dest ? ["--git-dir", dest.path] : ["-C", dest.path]
            report = ExportReport(gitDir: gitDir.path, objectsWritten: 0,
                                  refsWritten: [], warnings: [])
            report.updatedExisting = true
            report.warnings.append("destination already contains a git repository; updating refs and objects in place and leaving other refs untouched")
        } else {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: dest.path, isDirectory: &isDir), isDir.boolValue {
                let contents = try FileManager.default.contentsOfDirectory(atPath: dest.path)
                if !contents.isEmpty, !force {
                    throw SpacesError.invalidArgument("destination not empty: \(destPath)")
                }
            }
            try FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
            _ = try runGitRaw(git, ["-C", destPath, "init", "-q"])
            gitDir = dest.appendingPathComponent(".git")
            prefix = ["-C", dest.path]
            report = ExportReport(gitDir: gitDir.path, objectsWritten: 0,
                                  refsWritten: [], warnings: [])
        }

        for (name, cfg) in repo.config.remotes.sorted(by: { $0.key < $1.key }) {
            _ = try runGitRaw(git, prefix + ["config", "remote.\(name).url", cfg.url])
            if let pushURL = cfg.pushURL {
                _ = try runGitRaw(git, prefix + ["config", "remote.\(name).pushurl", pushURL])
            }
            let fetchSpec = cfg.fetchSpec.replacingOccurrences(of: "{remote}", with: name)
            _ = try runGitRaw(git, prefix + ["config", "remote.\(name).fetch", fetchSpec])
            report.configKeysWritten.append("remote.\(name).url")
            report.configKeysWritten.append("remote.\(name).fetch")
            if cfg.pushURL != nil { report.configKeysWritten.append("remote.\(name).pushurl") }
        }
        if let user = repo.config.user {
            try writeGitConfig(git, prefix: prefix, key: "user.name", value: user.name)
            try writeGitConfig(git, prefix: prefix, key: "user.email", value: user.email)
            report.configKeysWritten.append("user.name")
            report.configKeysWritten.append("user.email")
        }
        try writeGitConfig(git, prefix: prefix, key: "init.defaultBranch", value: repo.config.core.defaultBranch)
        report.configKeysWritten.append("init.defaultBranch")
        try writeGitConfig(git, prefix: prefix, key: "core.filemode", value: repo.config.core.fileMode ? "true" : "false")
        try writeGitConfig(git, prefix: prefix, key: "core.autocrlf", value: repo.config.core.autocrlf ? "true" : "false")
        try writeGitConfig(git, prefix: prefix, key: "core.symlinks", value: repo.config.core.symlinks ? "true" : "false")
        try writeGitConfig(git, prefix: prefix, key: "core.longpaths", value: repo.config.core.longPaths ? "true" : "false")
        report.configKeysWritten.append("core.filemode")
        report.configKeysWritten.append("core.autocrlf")
        report.configKeysWritten.append("core.symlinks")
        report.configKeysWritten.append("core.longpaths")
        for (branch, upstream) in repo.config.branchTracking.sorted(by: { $0.key < $1.key }) {
            guard let slash = upstream.firstIndex(of: "/") else { continue }
            let remoteName = String(upstream[..<slash])
            let remoteBranch = String(upstream[upstream.index(after: slash)...])
            guard !remoteName.isEmpty, !remoteBranch.isEmpty else { continue }
            try writeGitConfig(git, prefix: prefix, key: "branch.\(branch).remote", value: remoteName)
            try writeGitConfig(git, prefix: prefix, key: "branch.\(branch).merge", value: "refs/heads/\(remoteBranch)")
            report.configKeysWritten.append("branch.\(branch).remote")
            report.configKeysWritten.append("branch.\(branch).merge")
        }

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

        var oidMap: [ObjectID: String] = [:]

        for id in reachable.sorted() {
            guard let stored = try? repo.objects.read(id), stored.type == .blob else { continue }
            let gitOID = try writeGitBlob(git: git, prefix: prefix, payload: stored.payload)
            oidMap[id] = gitOID
            report.objectsWritten += 1
        }

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

                var ready = true
                for e in tree.entries where !e.mode.isDirectory {
                    if oidMap[e.oid] == nil { ready = false; break }
                }

                for e in tree.entries where e.mode.isDirectory {
                    if oidMap[e.oid] == nil { ready = false; break }
                }
                if !ready { still.insert(id); continue }
                let gitOID = try writeGitTree(git: git, prefix: prefix, tree: tree, oidMap: oidMap)
                oidMap[id] = gitOID
                report.objectsWritten += 1
            }
            pendingTrees = still
        }
        if !pendingTrees.isEmpty {
            report.warnings.append("\(pendingTrees.count) trees not exported")
        }

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
                let gitOID: String
                if let signature = commit.metadata.signature {
                    if signature.hasPrefix("-----BEGIN PGP SIGNATURE-----") {
                        gitOID = try writeGitCommitRaw(git: git, prefix: prefix, commit: commit,
                                                       treeGitOID: treeGitOID, parentGitOIDs: parents)
                    } else {
                        report.warnings.append("commit \(id.hex) has a Spaces signature which git cannot represent; the signature was not exported")
                        gitOID = try writeGitCommit(git: git, prefix: prefix, commit: commit,
                                                    treeGitOID: treeGitOID, parentGitOIDs: parents)
                    }
                } else {
                    gitOID = try writeGitCommit(git: git, prefix: prefix, commit: commit,
                                                treeGitOID: treeGitOID, parentGitOIDs: parents)
                }
                commitOIDMap[id] = gitOID
                report.objectsWritten += 1
            }
            pendingCommits = still
        }
        if !pendingCommits.isEmpty {
            report.warnings.append("\(pendingCommits.count) commits not exported")
        }

        var tagOIDMap: [ObjectID: String] = [:]
        for id in reachable.sorted() {
            guard let stored = try? repo.objects.read(id), stored.type == .tag,
                  let tag = try? JSONDecoder().decode(TagPayload.self, from: stored.payload) else { continue }
            let targetGitOID = tag.objectType == .commit ? commitOIDMap[tag.object] : oidMap[tag.object]
            guard let target = targetGitOID else {
                report.warnings.append("tag \(tag.name) target was not exported; the tag was skipped")
                continue
            }
            if let signature = tag.signature, !signature.hasPrefix("-----BEGIN PGP SIGNATURE-----") {
                report.warnings.append("tag \(tag.name) has a Spaces signature which git cannot represent; the signature was not exported")
            }
            let gitOID = try writeGitTagObject(git: git, prefix: prefix, tag: tag,
                                               targetGitOID: target)
            tagOIDMap[id] = gitOID
            report.objectsWritten += 1
        }

        for ref in try repo.refs.allRefs() {
            var gitOID: String? = nil
            switch ref.kind {
            case .branch, .remote:
                gitOID = commitOIDMap[ref.oid]
            case .tag:
                if let t = tagOIDMap[ref.oid] { gitOID = t }
                else { gitOID = commitOIDMap[ref.oid] }
            default: break
            }
            guard let oid = gitOID else { continue }
            let gitRefName = ref.name
            try runGitRaw(git, prefix + ["-c", "core.logAllRefUpdates=false", "update-ref", gitRefName, oid])
            report.refsWritten.append(gitRefName)
        }

        if let sym = try repo.refs.symbolicHEAD() {
            let branch = String(sym.dropFirst("refs/heads/".count))
            try? runGitRaw(git, prefix + ["symbolic-ref", "HEAD",
                                 "refs/heads/\(branch)"])
        }

        let hooksDir = repo.metaURL.appendingPathComponent("hooks")
        if let hookFiles = try? FileManager.default.contentsOfDirectory(atPath: hooksDir.path) {
            for name in hookFiles.sorted() where !name.hasSuffix(".sample") {
                let src = hooksDir.appendingPathComponent(name)
                var isDir: ObjCBool = false
                guard FileManager.default.fileExists(atPath: src.path, isDirectory: &isDir), !isDir.boolValue else { continue }
                let dst = gitDir.appendingPathComponent("hooks").appendingPathComponent(name)
                try? FileManager.default.createDirectory(at: dst.deletingLastPathComponent(), withIntermediateDirectories: true)
                if FileManager.default.fileExists(atPath: dst.path) {
                    report.warnings.append("export overwrote existing hook \(name) in the target repository")
                    try? FileManager.default.removeItem(at: dst)
                }
                do {
                    try FileManager.default.copyItem(at: src, to: dst)
                } catch {
                    report.warnings.append("hook \(name) could not be exported: \(error.localizedDescription)")
                    continue
                }
                if let perms = (try? FileManager.default.attributesOfItem(atPath: src.path))?[.posixPermissions] as? Int {
                    try? FileManager.default.setAttributes([.posixPermissions: perms], ofItemAtPath: dst.path)
                }
                report.hooksExported.append(name)
            }
        }

        var reflogSkipped = 0
        let headReflogCount = try exportReflog(logURL: gitDir.appendingPathComponent("logs/HEAD"),
                                               entries: (try? repo.readReflog(refName: "HEAD", limit: 10000)) ?? [],
                                               commitOIDMap: commitOIDMap, skipped: &reflogSkipped)
        if headReflogCount > 0 { report.reflogsExported.append("HEAD") }
        for ref in try repo.refs.allRefs() where ref.kind == .branch {
            let count = try exportReflog(logURL: gitDir.appendingPathComponent("logs").appendingPathComponent(ref.name),
                                         entries: (try? repo.readReflog(refName: ref.name, limit: 10000)) ?? [],
                                         commitOIDMap: commitOIDMap, skipped: &reflogSkipped)
            if count > 0 { report.reflogsExported.append(ref.name) }
        }
        if reflogSkipped > 0 {
            report.warnings.append("\(reflogSkipped) reflog entries referenced objects not present in the export and were skipped")
        }

        try? runGitRaw(git, prefix + ["rev-parse", "--git-dir"])
        return report
    }

    private func isGitDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.appendingPathComponent("HEAD").path, isDirectory: &isDir), !isDir.boolValue else { return false }
        guard FileManager.default.fileExists(atPath: url.appendingPathComponent("objects").path, isDirectory: &isDir), isDir.boolValue else { return false }
        guard FileManager.default.fileExists(atPath: url.appendingPathComponent("refs").path, isDirectory: &isDir), isDir.boolValue else { return false }
        return true
    }

    private func writeGitConfig(_ git: String, prefix: [String], key: String, value: String) throws {
        _ = try runGitRaw(git, prefix + ["config", key, value])
    }

    private func exportReflog(logURL: URL, entries: [ReflogEntry], commitOIDMap: [ObjectID: String], skipped: inout Int) throws -> Int {
        guard !entries.isEmpty else { return 0 }
        var lines: [String] = []
        for entry in entries.reversed() {
            let oldHex: String
            if let old = entry.old {
                guard let mapped = commitOIDMap[old] else { skipped += 1; continue }
                oldHex = mapped
            } else {
                oldHex = String(repeating: "0", count: 40)
            }
            let newHex: String
            if let new = entry.new {
                guard let mapped = commitOIDMap[new] else { skipped += 1; continue }
                newHex = mapped
            } else {
                newHex = String(repeating: "0", count: 40)
            }
            lines.append("\(oldHex) \(newHex) \(entry.ident) \(entry.timestamp) +0000\t\(entry.message)\n")
        }
        guard !lines.isEmpty else { return 0 }
        try FileManager.default.createDirectory(at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        var combined = ""
        var existingLines = Set<String>()
        if let current = try? String(contentsOf: logURL, encoding: .utf8) {
            combined = current
            existingLines = Set(current.components(separatedBy: "\n"))
        }
        let missing = lines.filter { !existingLines.contains(String($0.dropLast())) }
        guard !missing.isEmpty else { return 0 }
        if !combined.isEmpty, !combined.hasSuffix("\n") { combined += "\n" }
        combined += missing.joined()
        try Data(combined.utf8).write(to: logURL, options: .atomic)
        return missing.count
    }

    private func writeGitBlob(git: String, prefix: [String], payload: Data) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: git)
        process.arguments = prefix + ["hash-object", "-w", "--stdin"]
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

    private func gitlinkTarget(for oid: ObjectID) throws -> String? {
        guard let stored = try? repo.objects.read(oid), stored.type == .blob else { return nil }
        let text = String(decoding: stored.payload, as: UTF8.self)
        guard text.hasPrefix(GitMigration.gitlinkMarkerPrefix) else { return nil }
        let target = String(text.dropFirst(GitMigration.gitlinkMarkerPrefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        guard target.count == 40, target.allSatisfy({ $0.isHexDigit }) else {
            throw SpacesError.migrationError("gitlink marker blob \(oid.hex) has a malformed target")
        }
        return target
    }

    private func writeGitTree(git: String, prefix: [String], tree: TreePayload,
                              oidMap: [ObjectID: String]) throws -> String {
        var input = ""
        for e in tree.entries {
            guard let childOID = oidMap[e.oid] else {
                throw SpacesError.migrationError("tree child not exported: \(e.name)")
            }
            if e.mode.isDirectory {
                input += "\(e.mode.rawValue) tree \(childOID)\t\(e.name)\n"
            } else if let gitlink = try gitlinkTarget(for: e.oid) {
                input += "160000 commit \(gitlink)\t\(e.name)\n"
            } else {
                input += "\(e.mode.rawValue) blob \(childOID)\t\(e.name)\n"
            }
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: git)
        process.arguments = prefix + ["mktree"]
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

    private func writeGitCommit(git: String, prefix: [String], commit: CommitPayload,
                                treeGitOID: String, parentGitOIDs: [String]) throws -> String {
        var input = ""
        for (k, v) in commit.metadata.trailers.sorted(by: { $0.key < $1.key }) {
            input += "\(k): \(v)\n"
        }
        input += "\(commit.message)\n"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: git)
        process.arguments = prefix + ["commit-tree", treeGitOID]
        if !parentGitOIDs.isEmpty {
            process.arguments!.append(contentsOf: parentGitOIDs.flatMap { ["-p", $0] })
        }
        var env = ProcessInfo.processInfo.environment
        let authorOffset = commit.metadata.trailers["X-Spaces-Author-TZ"]
            .flatMap(gitOffsetTokenMinutes)
        let committerOffset = commit.metadata.trailers["X-Spaces-Committer-TZ"]
            .flatMap(gitOffsetTokenMinutes)
        applyGitIdentity(&env, prefix: "GIT_AUTHOR_", sig: commit.author, offsetMinutes: authorOffset)
        applyGitIdentity(&env, prefix: "GIT_COMMITTER_", sig: commit.committer, offsetMinutes: committerOffset)
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

    private func writeGitCommitRaw(git: String, prefix: [String], commit: CommitPayload,
                                   treeGitOID: String, parentGitOIDs: [String]) throws -> String {
        let authorOffset = commit.metadata.trailers["X-Spaces-Author-TZ"]
            .flatMap(gitOffsetTokenMinutes) ?? localOffsetMinutes(for: commit.author)
        let committerOffset = commit.metadata.trailers["X-Spaces-Committer-TZ"]
            .flatMap(gitOffsetTokenMinutes) ?? localOffsetMinutes(for: commit.committer)
        var input = "tree \(treeGitOID)\n"
        for parent in parentGitOIDs {
            input += "parent \(parent)\n"
        }
        input += gitIdentityLine(keyword: "author", sig: commit.author, offsetMinutes: authorOffset)
        input += gitIdentityLine(keyword: "committer", sig: commit.committer, offsetMinutes: committerOffset)
        if let signature = commit.metadata.signature {
            let sigLines = signature.components(separatedBy: "\n")
            for (index, line) in sigLines.enumerated() {
                if index == 0 {
                    input += "gpgsig \(line)\n"
                } else {
                    input += " \(line)\n"
                }
            }
        }
        input += "\n"
        for (k, v) in commit.metadata.trailers.sorted(by: { $0.key < $1.key }) {
            input += "\(k): \(v)\n"
        }
        input += "\(commit.message)\n"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: git)
        process.arguments = prefix + ["hash-object", "-t", "commit", "-w", "--stdin"]
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
            throw SpacesError.migrationError("git hash-object for signed commit failed")
        }
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func writeGitTagObject(git: String, prefix: [String], tag: TagPayload,
                                   targetGitOID: String) throws -> String {
        var input = "object \(targetGitOID)\n"
        input += "type \(tag.objectType.rawValue)\n"
        input += "tag \(tag.name)\n"
        if let tagger = tag.tagger {
            input += "tagger \(gitSignature(tagger))\n"
        }
        input += "\n\(tag.message)\n"
        if let signature = tag.signature, signature.hasPrefix("-----BEGIN PGP SIGNATURE-----") {
            input += "\n\(signature)\n"
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: git)
        process.arguments = prefix + ["mktag"]
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

    private func applyGitIdentity(_ env: inout [String: String], prefix: String,
                                  sig: Signature, offsetMinutes: Int? = nil) {
        env[prefix + "NAME"] = sig.name
        env[prefix + "EMAIL"] = sig.email
        let minutes: Int
        if let offsetMinutes {
            minutes = offsetMinutes
        } else {
            minutes = localOffsetMinutes(for: sig)
        }
        env[prefix + "DATE"] = "@\(sig.timestamp) \(gitOffsetToken(minutes: minutes))"
    }

    private func gitSignature(_ s: Signature) -> String {
        let tz = TimeZone.current.secondsFromGMT(for: Date(timeIntervalSince1970: TimeInterval(s.timestamp)))
        let sign = tz >= 0 ? "+" : "-"
        let absTz = abs(tz)
        let hh = absTz / 3600, mm = (absTz % 3600) / 60
        return "\(s.name) <\(s.email)> \(s.timestamp) \(sign)\(String(format: "%02d%02d", hh, mm))"
    }

    private func findGit() throws -> String {
        var candidates: [String] = ["/usr/bin/git", "/opt/homebrew/bin/git", "/usr/local/bin/git",
                                    "/opt/local/bin/git", "/Library/Developer/CommandLineTools/usr/bin/git",
                                    "/Applications/Xcode.app/Contents/Developer/usr/bin/git"]
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        candidates += [home + "/homebrew/bin/git", home + "/opt/homebrew/bin/git", home + "/.local/bin/git"]
        if let developerDir = runToolOutput("/usr/bin/xcode-select", ["-p"]) {
            let trimmed = developerDir.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { candidates.append(trimmed + "/usr/bin/git") }
        }
        if let xcrunGit = runToolOutput("/usr/bin/xcrun", ["-f", "git"]) {
            let trimmed = xcrunGit.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { candidates.append(trimmed) }
        }
        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) { return path }
        }
        if let pathEnv = ProcessInfo.processInfo.environment["PATH"] {
            for dir in pathEnv.components(separatedBy: ":") {
                let candidate = dir + "/git"
                if FileManager.default.isExecutableFile(atPath: candidate) { return candidate }
            }
        }
        throw SpacesError.migrationError("git executable not found (required only for Spaces git import and export; Spaces itself does not need git). Install git with the Xcode Command Line Tools (xcode-select --install) or Homebrew (brew install git), or put a git binary on PATH. Locations searched: " + candidates.joined(separator: ", ") + " and PATH")
    }

    private func runToolOutput(_ executable: String, _ args: [String]) -> String? {
        guard FileManager.default.isExecutableFile(atPath: executable) else { return nil }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    private func resolveGitDir(git: String, path: String) throws -> String {
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

    private func runGitOptional(_ git: String, _ args: [String]) -> String? {
        try? runGitRaw(git, args)
    }
}
