import Foundation

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

public final class Repository: @unchecked Sendable {
    public let worktreeURL: URL
    public let metaURL: URL
    public let objects: ObjectStore
    public let refs: RefDatabase
    public let journal: Journal
    public var config: SpacesConfig
    private let ioLock = NSRecursiveLock()

    public init(worktree: URL) throws {
        self.worktreeURL = worktree.standardizedFileURL
        self.metaURL = RepositoryFormat.metadataURL(for: worktree).standardizedFileURL
        self.objects = ObjectStore(root: metaURL.appendingPathComponent("objects"))
        self.refs = RefDatabase(metaURL: metaURL)
        self.journal = Journal(metaURL: metaURL)
        self.config = SpacesConfig()
        try loadConfig()
    }

    @discardableResult
    public static func create(at url: URL, defaultBranch: String = "main",
                              user: SpacesConfig.User? = nil) throws -> Repository {
        let worktree = url.standardizedFileURL
        let meta = RepositoryFormat.metadataURL(for: worktree)
        if FileManager.default.fileExists(atPath: meta.path) {
            throw SpacesError.alreadyARepository(worktree.path)
        }
        do {
            try FileManager.default.createDirectory(at: worktree, withIntermediateDirectories: true)
            for sub in ["objects", "refs/heads", "refs/tags", "refs/remotes", "refs/snapshots",
                        "logs/refs/heads", "hooks", "lfs/objects", "tmp"] {
                try FileManager.default.createDirectory(
                    at: meta.appendingPathComponent(sub), withIntermediateDirectories: true)
            }
            var config = SpacesConfig()
            config.core.defaultBranch = defaultBranch
            config.user = user ?? SpacesConfig.User(name: "", email: "")
            let repo = try Repository(worktree: worktree)
            try repo.acquireLock()
            defer { repo.releaseLock() }
            try repo.saveConfig(config)
            try repo.refs.setHEAD(ref: "refs/heads/\(defaultBranch)")
            try repo.appendReflog(refName: "HEAD", old: nil, new: nil,
                                  message: "repository initialized")
            return repo
        } catch {
            try? FileManager.default.removeItem(at: meta)
            throw error
        }
    }

    public static func open(at url: URL? = nil) throws -> Repository {
        let start = (url ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
            .standardizedFileURL
        guard let worktree = RepositoryFormat.discover(from: start) else {
            throw SpacesError.notARepository(start.path)
        }
        let repo = try Repository(worktree: worktree)
        if repo.needsRecovery() {
            _ = try repo.withLock { try repo.recoverIfNeeded() }
        }
        let problems = repo.validate()
        if !problems.isEmpty {
            throw SpacesError.internalInconsistency("repository validation failed: \(problems.joined(separator: "; "))")
        }
        return repo
    }

    public static func isRepository(at url: URL) -> Bool {
        RepositoryFormat.discover(from: url) != nil
    }

    public static func detect(at url: URL) -> RepositoryDetection {
        let worktree = url.standardizedFileURL
        let meta = RepositoryFormat.metadataURL(for: worktree)
        var isMetaDir: ObjCBool = false
        let metaExists = FileManager.default.fileExists(atPath: meta.path, isDirectory: &isMetaDir)
        if metaExists, !isMetaDir.boolValue {
            return .spacesInvalid(reason: ".spaces exists but is not a directory")
        }
        if !metaExists {
            var isGitDir: ObjCBool = false
            let gitURL = worktree.appendingPathComponent(".git")
            if FileManager.default.fileExists(atPath: gitURL.path, isDirectory: &isGitDir), isGitDir.boolValue {
                return .git
            }
            return .empty
        }
        let configURL = meta.appendingPathComponent("config.json")
        guard FileManager.default.fileExists(atPath: configURL.path) else {
            return .spacesInvalid(reason: ".spaces/config.json is missing")
        }
        let config: SpacesConfig
        do {
            config = try JSONDecoder().decode(SpacesConfig.self, from: Data(contentsOf: configURL))
        } catch {
            return .spacesInvalid(reason: ".spaces/config.json cannot be parsed: \(error.localizedDescription)")
        }
        if config.version > RepositoryFormat.formatVersion {
            return .unsupportedVersion(version: config.version)
        }
        var isObjectsDir: ObjCBool = false
        if !FileManager.default.fileExists(atPath: meta.appendingPathComponent("objects").path, isDirectory: &isObjectsDir) || !isObjectsDir.boolValue {
            return .spacesInvalid(reason: ".spaces/objects directory is missing")
        }
        var isRefsDir: ObjCBool = false
        if !FileManager.default.fileExists(atPath: meta.appendingPathComponent("refs").path, isDirectory: &isRefsDir) || !isRefsDir.boolValue {
            return .spacesInvalid(reason: ".spaces/refs directory is missing")
        }
        return .spaces(valid: true)
    }

    public func validate() -> [String] {
        var problems: [String] = []
        let required = ["objects", "refs", "config.json"]
        for r in required {
            if !FileManager.default.fileExists(atPath: metaURL.appendingPathComponent(r).path) {
                problems.append("missing \(r)")
            }
        }
        if (try? refs.readHEAD()) == nil { problems.append("HEAD unreadable") }
        if (try? objects.allIDs()) == nil { problems.append("object store unreadable") }
        if let head = try? refs.readHEAD() {
            let trimmed = head.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("ref: ") {
                let target = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                if target.isEmpty {
                    problems.append("HEAD has an empty symbolic target")
                } else if FileManager.default.fileExists(atPath: metaURL.appendingPathComponent(target).path)
                            || packedRefsContains(target) {
                    let resolved: ObjectID?
                    do { resolved = try refs.readRef(target) } catch { resolved = nil }
                    if resolved == nil {
                        problems.append("HEAD target ref \(target) is corrupt")
                    }
                } else {
                    let hasCommits = ((try? objects.allIDs()) ?? []).contains { id in
                        (try? objects.read(id, expectedType: .commit)) != nil
                    }
                    if hasCommits {
                        problems.append("HEAD points at missing ref \(target)")
                    }
                }
            } else if !trimmed.isEmpty {
                if (try? ObjectID(validating: trimmed)) == nil {
                    problems.append("HEAD is malformed")
                } else if let oid = try? ObjectID(validating: trimmed), !objects.exists(oid) {
                    problems.append("HEAD points at missing object \(trimmed)")
                }
            }
        }
        let indexURL = metaURL.appendingPathComponent("index")
        if FileManager.default.fileExists(atPath: indexURL.path) {
            do { _ = try Index.load(from: indexURL) } catch {
                problems.append("index unreadable: \(error.localizedDescription)")
            }
        }
        let packedURL = metaURL.appendingPathComponent("packed-refs")
        if FileManager.default.fileExists(atPath: packedURL.path) {
            do {
                let text = try String(contentsOf: packedURL, encoding: .utf8)
                for line in text.components(separatedBy: "\n") where !line.isEmpty {
                    if line.hasPrefix("#") { continue }
                    if line.hasPrefix("^") {
                        let hex = String(line.dropFirst())
                        if (try? ObjectID(validating: hex)) == nil {
                            problems.append("packed-refs has malformed peel line")
                        }
                        continue
                    }
                    let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
                    if parts.count != 2 || (try? ObjectID(validating: String(parts[0]))) == nil {
                        problems.append("packed-refs has malformed line: \(line)")
                    }
                }
            } catch {
                problems.append("packed-refs unreadable: \(error.localizedDescription)")
            }
        }
        return problems
    }

    private func packedRefsContains(_ name: String) -> Bool {
        guard let packed = try? String(contentsOf: metaURL.appendingPathComponent("packed-refs"), encoding: .utf8) else { return false }
        for line in packed.components(separatedBy: "\n") {
            let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            if parts.count == 2, parts[1] == name { return true }
        }
        return false
    }

    private func needsRecovery() -> Bool {
        if journal.hasUnfinishedTransactions { return true }
        if staleLockPresent() { return true }
        let indexURL = metaURL.appendingPathComponent("index")
        if (try? Index.load(from: indexURL)) == nil { return true }
        return false
    }

    @discardableResult
    public func recoverIfNeeded() throws -> [String] {
        var notes: [String] = []
        for tx in journal.unfinishedTransactionIDs() {
            try journal.finish(tx: tx, committed: false)
            notes.append("aborted unfinished transaction \(tx)")
        }
        if removeStaleLockIfNeeded() {
            notes.append("removed stale lock")
        }
        let indexURL = metaURL.appendingPathComponent("index")
        do {
            _ = try Index.load(from: indexURL)
        } catch {
            notes.append("index unreadable (\(error.localizedDescription)); rebuilding from HEAD")
            do {
                try rebuildIndexFromHead()
                notes.append("index rebuilt")
            } catch {
                notes.append("index rebuild failed: \(error.localizedDescription)")
            }
        }
        if let sym = try? refs.symbolicHEAD() {
            do {
                let oid = try refs.readRef(sym)
                if oid == nil {
                    notes.append("HEAD points at unborn ref \(sym)")
                }
            } catch {
                notes.append("HEAD target ref \(sym) is corrupt: \(error.localizedDescription)")
            }
        }
        return notes
    }

    private func rebuildIndexFromHead() throws {
        var newIndex = Index()
        if let head = try headCommit() {
            let flat = try TreeBuilder.flattenTree(repo: self, treeOID: head.tree)
            for (path, entry) in flat {
                let url = try worktreeURL(forRelativePath: path)
                if FileManager.default.fileExists(atPath: url.path) {
                    newIndex.entries[path] = try Index.entry(forFileAt: url, oid: entry.oid, mode: entry.mode)
                }
            }
        }
        try saveIndex(newIndex)
    }

    public func loadConfig() throws {
        let url = metaURL.appendingPathComponent("config.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            config = try JSONDecoder().decode(SpacesConfig.self, from: Data(contentsOf: url))
        } catch {
            throw SpacesError.configError("cannot parse config.json: \(error.localizedDescription)")
        }
        if config.version > RepositoryFormat.formatVersion {
            throw SpacesError.configError("repository format v\(config.version) is newer than supported v\(RepositoryFormat.formatVersion)")
        }
    }

    public func saveConfig(_ newConfig: SpacesConfig? = nil) throws {
        let value = newConfig ?? config
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        try refs.atomicWrite(metaURL.appendingPathComponent("config.json"),
                             contents: encoder.encode(value))
        config = value
    }

    public func identity() -> Signature {
        if let u = config.user, !u.name.isEmpty {
            return Signature(name: u.name, email: u.email)
        }
        let name = ProcessInfo.processInfo.environment["SPACES_AUTHOR_NAME"]
            ?? ProcessInfo.processInfo.environment["GIT_AUTHOR_NAME"]
            ?? NSFullUserName()
        let email = ProcessInfo.processInfo.environment["SPACES_AUTHOR_EMAIL"]
            ?? ProcessInfo.processInfo.environment["GIT_AUTHOR_EMAIL"]
            ?? "\(NSUserName())@localhost"
        return Signature(name: name, email: email)
    }

    private var lockURL: URL { metaURL.appendingPathComponent("lock") }

    private var lockDepth = 0
    private var lockFD: Int32 = -1

    public func acquireLock() throws {
        ioLock.lock()
        if lockDepth > 0 {
            lockDepth += 1
            return
        }
        var attempts = 0
        while true {
            attempts += 1
            #if canImport(Darwin)
            let fd = lockURL.path.withCString { Darwin.open($0, O_WRONLY | O_CREAT | O_EXCL, 0o644) }
            #else
            let fd = lockURL.path.withCString { Glibc.open($0, O_WRONLY | O_CREAT | O_EXCL, 0o644) }
            #endif
            if fd >= 0 {
                let payload = Data("\(ProcessInfo.processInfo.processIdentifier)\n\(Int64(Date().timeIntervalSince1970))\n".utf8)
                var writeFailed = false
                payload.withUnsafeBytes { buffer in
                    guard let baseAddress = buffer.baseAddress else { writeFailed = true; return }
                    var offset = 0
                    while offset < buffer.count {
                        let written = write(fd, baseAddress.advanced(by: offset), buffer.count - offset)
                        if written < 0 {
                            if errno == EINTR { continue }
                            writeFailed = true
                            return
                        }
                        if written == 0 { writeFailed = true; return }
                        offset += written
                    }
                }
                if writeFailed {
                    close(fd)
                    try? FileManager.default.removeItem(at: lockURL)
                    ioLock.unlock()
                    throw SpacesError.repositoryLocked("cannot write lock file")
                }
                if flock(fd, LOCK_EX | LOCK_NB) != 0 {
                    close(fd)
                    try? FileManager.default.removeItem(at: lockURL)
                    ioLock.unlock()
                    throw SpacesError.repositoryLocked("lock file is held by another process")
                }
                lockFD = fd
                lockDepth = 1
                return
            }
            if errno != EEXIST {
                let message = AtomicFileIO.posixMessage()
                ioLock.unlock()
                throw SpacesError.repositoryLocked("cannot create lock: \(message)")
            }
            if removeStaleLockIfNeeded() {
                if attempts < 4 { continue }
                ioLock.unlock()
                throw SpacesError.repositoryLocked("stale lock could not be cleared")
            }
            ioLock.unlock()
            throw SpacesError.repositoryLocked(lockURL.path)
        }
    }

    public func releaseLock() {
        guard lockDepth > 0 else { return }
        lockDepth -= 1
        if lockDepth == 0 {
            try? FileManager.default.removeItem(at: lockURL)
            if lockFD >= 0 {
                close(lockFD)
                lockFD = -1
            }
            ioLock.unlock()
            SpacesEventHub.shared.emit(.statusChanged, worktree: worktreeURL)
            SpacesEventHub.shared.emit(.refsChanged, worktree: worktreeURL)
        }
    }

    private func staleLockPresent() -> Bool {
        guard FileManager.default.fileExists(atPath: lockURL.path) else { return false }
        guard let info = try? String(contentsOf: lockURL, encoding: .utf8),
              let pid = Int32(info.components(separatedBy: "\n").first ?? "") else { return true }
        if pid <= 0 { return true }
        if kill(pid, 0) == 0 || errno == EPERM { return false }
        return true
    }

    private func removeStaleLockIfNeeded() -> Bool {
        guard staleLockPresent() else { return false }
        try? FileManager.default.removeItem(at: lockURL)
        return !FileManager.default.fileExists(atPath: lockURL.path)
    }

    public func withLock<T>(_ body: () throws -> T) throws -> T {
        try acquireLock()
        defer { releaseLock() }
        return try body()
    }

    private struct TransactionSnapshot {
        var files: [String: Data]
        var index: Index?
        var config: SpacesConfig
    }

    private func snapshotTransactionalState() throws -> TransactionSnapshot {
        var files: [String: Data] = [:]
        let fm = FileManager.default
        func record(_ url: URL) throws {
            guard fm.fileExists(atPath: url.path) else { return }
            files[url.path] = try Data(contentsOf: url)
        }
        try record(metaURL.appendingPathComponent("HEAD"))
        try record(metaURL.appendingPathComponent("packed-refs"))
        try record(metaURL.appendingPathComponent("index"))
        try record(metaURL.appendingPathComponent("config.json"))
        for sub in ["refs", "logs"] {
            let dir = metaURL.appendingPathComponent(sub)
            if let enumerator = fm.enumerator(atPath: dir.path) {
                for case let rel as String in enumerator {
                    let full = dir.appendingPathComponent(rel)
                    var isDir: ObjCBool = false
                    guard fm.fileExists(atPath: full.path, isDirectory: &isDir), !isDir.boolValue else { continue }
                    files[full.path] = try Data(contentsOf: full)
                }
            }
        }
        return TransactionSnapshot(files: files, index: try? index(), config: config)
    }

    private func restoreTransactionalState(_ snapshot: TransactionSnapshot) -> [String] {
        var failures: [String] = []
        let fm = FileManager.default
        for sub in ["refs", "logs"] {
            let dir = metaURL.appendingPathComponent(sub)
            if let enumerator = fm.enumerator(atPath: dir.path) {
                for case let rel as String in enumerator {
                    let full = dir.appendingPathComponent(rel)
                    var isDir: ObjCBool = false
                    guard fm.fileExists(atPath: full.path, isDirectory: &isDir), !isDir.boolValue else { continue }
                    if snapshot.files[full.path] == nil {
                        do { try fm.removeItem(at: full) } catch { failures.append(full.path) }
                    }
                }
            }
        }
        for (path, data) in snapshot.files {
            let url = URL(fileURLWithPath: path)
            do {
                try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try AtomicFileIO.writeAtomically(data, to: url)
            } catch {
                failures.append(path)
            }
        }
        if let idx = snapshot.index {
            indexCache = idx
            indexDirty = false
        } else {
            indexCache = nil
            indexDirty = false
        }
        config = snapshot.config
        return failures
    }

    @discardableResult
    public func performTransaction<T>(steps: [String] = [],
                                      _ body: () throws -> T) throws -> T {
        try acquireLock()
        defer { releaseLock() }
        let tx = UUID().uuidString
        let snapshot = try snapshotTransactionalState()
        if !steps.isEmpty { try journal.begin(tx: tx, steps: steps) }
        do {
            let result = try body()
            if !steps.isEmpty {
                for index in steps.indices {
                    try journal.step(tx: tx, index: index)
                }
                try journal.finish(tx: tx, committed: true)
                SpacesEventHub.shared.emit(
                    .operationFinished(steps.joined(separator: ",")),
                    worktree: worktreeURL)
            }
            return result
        } catch {
            if !steps.isEmpty { try? journal.finish(tx: tx, committed: false) }
            let rollbackFailures = restoreTransactionalState(snapshot)
            if !rollbackFailures.isEmpty {
                throw SpacesError.ioError("transaction failed (\(error.localizedDescription)) and rollback could not restore: \(rollbackFailures.prefix(5).joined(separator: ", "))")
            }
            throw error
        }
    }

    public func appendReflog(refName: String, old: ObjectID?, new: ObjectID?,
                             message: String) throws {
        let ident = identity()
        let oldHex = old?.hex ?? String(repeating: "0", count: 64)
        let newHex = new?.hex ?? String(repeating: "0", count: 64)
        let line = "\(oldHex) \(newHex) \(ident.name) <\(ident.email)> \(ident.timestamp)\t\(message)\n"
        let targets: [String] = refName == "HEAD" ? ["HEAD"] : ["HEAD", refName]
        for target in targets {
            let logDir = metaURL.appendingPathComponent("logs")
            let logURL = logDir.appendingPathComponent(target)
            try FileManager.default.createDirectory(at: logURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try AtomicFileIO.append(Data(line.utf8), to: logURL)
        }
    }

    public func readReflog(refName: String = "HEAD", limit: Int = 100) throws -> [ReflogEntry] {
        let logURL = metaURL.appendingPathComponent("logs").appendingPathComponent(refName)
        guard let text = try? String(contentsOf: logURL, encoding: .utf8) else { return [] }
        var entries: [ReflogEntry] = []
        for line in text.components(separatedBy: "\n").reversed() {
            guard !line.isEmpty else { continue }
            let parts = line.split(separator: "\t", maxSplits: 1)
            let meta = String(parts[0])
            let message = parts.count > 1 ? String(parts[1]) : ""
            let fields = meta.split(separator: " ").map(String.init)
            guard fields.count >= 5 else { continue }
            let oldHex = fields[0], newHex = fields[1]
            let ts = Int64(fields.last ?? "0") ?? 0
            let who = fields.dropFirst(2).dropLast().joined(separator: " ")
            entries.append(ReflogEntry(
                old: oldHex == String(repeating: "0", count: 64) ? nil : try? ObjectID(validating: oldHex),
                new: newHex == String(repeating: "0", count: 64) ? nil : try? ObjectID(validating: newHex),
                ident: who, timestamp: ts, message: message))
            if entries.count >= limit { break }
        }
        return entries
    }

    public var mergeHeadURL: URL { metaURL.appendingPathComponent("MERGE_HEAD") }
    public var mergeMessageURL: URL { metaURL.appendingPathComponent("MERGE_MSG") }
    public var mergeModeURL: URL { metaURL.appendingPathComponent("MERGE_MODE") }
    public var cherryPickHeadURL: URL { metaURL.appendingPathComponent("CHERRY_PICK_HEAD") }
    public var revertHeadURL: URL { metaURL.appendingPathComponent("REVERT_HEAD") }
    public var rebaseHeadURL: URL { metaURL.appendingPathComponent("REBASE_HEAD") }
    public var rebaseDirURL: URL { metaURL.appendingPathComponent("rebase-merge") }

    public func inMerge() -> Bool { FileManager.default.fileExists(atPath: mergeHeadURL.path) }
    public func inCherryPick() -> Bool {
        FileManager.default.fileExists(atPath: cherryPickHeadURL.path)
            || FileManager.default.fileExists(atPath: revertHeadURL.path)
    }
    public func inRebase() -> Bool {
        FileManager.default.fileExists(atPath: rebaseHeadURL.path)
            || FileManager.default.fileExists(atPath: rebaseDirURL.path)
    }

    public func writeState(_ name: String, contents: String) throws {
        try Data(contents.utf8).write(to: metaURL.appendingPathComponent(name), options: .atomic)
    }

    public func readState(_ name: String) -> String? {
        try? String(contentsOf: metaURL.appendingPathComponent(name), encoding: .utf8)
    }

    public func clearState(_ names: [String]) {
        for n in names { try? FileManager.default.removeItem(at: metaURL.appendingPathComponent(n)) }
    }

    private var indexCache: Index?
    private var indexDirty = false

    public func index() throws -> Index {
        if let cache = indexCache, !indexDirty { return cache }
        let idx = try Index.load(from: metaURL.appendingPathComponent("index"))
        indexCache = idx
        indexDirty = false
        return idx
    }

    public func saveIndex(_ index: Index) throws {
        try index.save(to: metaURL.appendingPathComponent("index"))
        indexCache = index
        indexDirty = false
    }

    public func markIndexDirty() { indexDirty = true }

    public func setDetachedHead(_ oid: ObjectID) throws {
        _ = try commitObject(oid)
        let oldHEAD = try refs.headOID(objects: objects)
        try refs.setHEAD(oid: oid)
        try appendReflog(refName: "HEAD", old: oldHEAD, new: oid,
                         message: "checkout: moving to \(oid.hex)")
    }

    public func isDetachedHead() throws -> Bool {
        try refs.symbolicHEAD() == nil
    }

    public func headCommit() throws -> CommitPayload? {
        guard let oid = try refs.headOID(objects: objects) else { return nil }
        return try commitObject(oid)
    }

    public func resolveRevision(_ text: String) throws -> ObjectID {
        let spec = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !spec.isEmpty else { throw SpacesError.ambiguousRevision(text) }

        var base = spec
        var ops: [(op: Character, count: Int)] = []
        while true {
            guard let m = base.range(of: #"[\^~][0-9]*$"#, options: .regularExpression) else { break }
            let suffix = String(base[m])
            base = String(base[..<m.lowerBound])
            let op = suffix.first!
            let digits = suffix.dropFirst()
            let n = digits.isEmpty ? 1 : (Int(digits) ?? 1)
            ops.append((op, n))
        }
        ops.reverse()
        if base.isEmpty, !ops.isEmpty { base = "HEAD" }

        var oid = try resolveBase(base)
        for op in ops {
            if op.count == 0 { continue }
            if op.op == "~" {
                for _ in 0..<op.count {
                    oid = try firstParent(of: oid)
                }
            } else {
                let commit = try commitObject(oid)
                let parentIndex = op.count - 1
                guard parentIndex >= 0, parentIndex < commit.parents.count else {
                    throw SpacesError.invalidArgument("\(spec): commit has no such parent")
                }
                oid = commit.parents[parentIndex]
            }
        }
        return oid
    }

    private func resolveBase(_ spec: String) throws -> ObjectID {
        if spec == "HEAD" {
            guard let oid = try refs.headOID(objects: objects) else {
                throw SpacesError.branchNotFound("HEAD (unborn)")
            }
            return oid
        }
        if spec.hasPrefix("refs/") || spec.contains("/") {
            if let oid = try refs.readRef(spec) { return oid }
        }
        return try refs.resolve(spec, objects: objects)
    }

    private func firstParent(of oid: ObjectID) throws -> ObjectID {
        let c = try commitObject(oid)
        guard let p = c.parents.first else { throw SpacesError.invalidArgument("root commit has no parent") }
        return p
    }

    public func commitObject(_ oid: ObjectID) throws -> CommitPayload {
        try objects.readPayload(oid, expected: .commit)
    }

    public func tagObject(_ oid: ObjectID) throws -> TagPayload {
        try objects.readPayload(oid, expected: .tag)
    }

    public func treeEntries(_ treeOID: ObjectID) throws -> [TreeEntry] {
        let payload: TreePayload = try objects.readPayload(treeOID, expected: .tree)
        return payload.entries
    }

    public func blobData(_ oid: ObjectID) throws -> Data {
        try objects.read(oid, expectedType: .blob).payload
    }

    public func worktreeURL(forRelativePath path: String) throws -> URL {
        let normalized = path.replacingOccurrences(of: "\\", with: "/")
        guard !normalized.hasPrefix("/"), !normalized.contains("..") else {
            throw SpacesError.pathOutsideRepository(path)
        }
        return worktreeURL.appendingPathComponent(normalized)
    }

    public func relativePath(_ url: URL) throws -> String {
        let baseComponents = worktreeURL.standardizedFileURL.pathComponents
        let fullComponents = url.standardizedFileURL.pathComponents
        guard fullComponents.count >= baseComponents.count,
              Array(fullComponents.prefix(baseComponents.count)) == baseComponents else {
            throw SpacesError.pathOutsideRepository(url.path)
        }
        return fullComponents.dropFirst(baseComponents.count).joined(separator: "/")
    }

    public func trackedPaths() throws -> [String] {
        try index().entries.keys.sorted()
    }
}

public struct ReflogEntry: Sendable {
    public var old: ObjectID?
    public var new: ObjectID?
    public var ident: String
    public var timestamp: Int64
    public var message: String
}

public enum RepositoryDetection: Sendable, Equatable {
    case spaces(valid: Bool)
    case spacesInvalid(reason: String)
    case git
    case empty
    case unsupportedVersion(version: Int)
}

extension SpacesAPI {
    public static func detectRepository(at url: URL) -> RepositoryDetection {
        Repository.detect(at: url)
    }
}
