import Foundation







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
        try repo.saveConfig(config)
        try repo.refs.setHEAD(ref: "refs/heads/\(defaultBranch)")
        
        try repo.appendReflog(refName: "HEAD", old: nil, new: nil,
                              message: "repository initialized")
        return repo
    }

    
    public static func open(at url: URL? = nil) throws -> Repository {
        let start = (url ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
            .standardizedFileURL
        guard let worktree = RepositoryFormat.discover(from: start) else {
            throw SpacesError.notARepository(start.path)
        }
        let repo = try Repository(worktree: worktree)
        try repo.recoverIfNeeded()
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
        return problems
    }

    
    
    
    
    @discardableResult
    public func recoverIfNeeded() throws -> [String] {
        var notes: [String] = []
        if journal.hasUnfinishedTransactions {
            notes.append("unfinished transaction detected in journal")
        }
        
        if let sym = try? refs.symbolicHEAD() {
            if try refs.readRef(sym) == nil {
                
                notes.append("HEAD points at unborn ref \(sym)")
            }
        }
        return notes
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

    
    
    
    
    public func acquireLock() throws {
        ioLock.lock()
        if lockDepth > 0 {
            lockDepth += 1
            return
        }
        let fm = FileManager.default
        if fm.fileExists(atPath: lockURL.path) {
            if let info = try? String(contentsOf: lockURL, encoding: .utf8),
               let pid = Int32(info.components(separatedBy: "\n").first ?? "") {
                if kill(pid, 0) == 0 {
                    ioLock.unlock()
                    throw SpacesError.repositoryLocked("pid \(pid)")
                }
                
                try? fm.removeItem(at: lockURL)
            } else {
                try? fm.removeItem(at: lockURL)
            }
        }
        let payload = "\(ProcessInfo.processInfo.processIdentifier)\n\(Int64(Date().timeIntervalSince1970))\n"
        guard fm.createFile(atPath: lockURL.path, contents: Data(payload.utf8)) else {
            ioLock.unlock()
            throw SpacesError.repositoryLocked("cannot create lock")
        }
        lockDepth = 1
    }

    public func releaseLock() {
        lockDepth -= 1
        if lockDepth <= 0 {
            lockDepth = 0
            try? FileManager.default.removeItem(at: lockURL)
            ioLock.unlock()
            SpacesEventHub.shared.emit(.statusChanged, worktree: worktreeURL)
            SpacesEventHub.shared.emit(.refsChanged, worktree: worktreeURL)
        }
    }

    
    public func withLock<T>(_ body: () throws -> T) throws -> T {
        try acquireLock()
        defer { releaseLock() }
        return try body()
    }

    
    @discardableResult
    public func performTransaction<T>(steps: [String] = [],
                                      _ body: () throws -> T) throws -> T {
        try acquireLock()
        defer { releaseLock() }
        let tx = UUID().uuidString
        if !steps.isEmpty { try journal.begin(tx: tx, steps: steps) }
        do {
            let result = try body()
            if !steps.isEmpty {
                try journal.finish(tx: tx, committed: true)
                SpacesEventHub.shared.emit(
                    .operationFinished(steps.joined(separator: ",")),
                    worktree: worktreeURL)
            }
            return result
        } catch {
            if !steps.isEmpty { try? journal.finish(tx: tx, committed: false) }
            throw error
        }
    }

    

    public func appendReflog(refName: String, old: ObjectID?, new: ObjectID?,
                             message: String) throws {
        let ident = identity()
        let oldHex = old?.hex ?? String(repeating: "0", count: 64)
        let newHex = new?.hex ?? String(repeating: "0", count: 64)
        let line = "\(oldHex) \(newHex) \(ident.name) <\(ident.email)> \(ident.timestamp)\t\(message)\n"
        for target in ["HEAD", refName] {
            let logDir = metaURL.appendingPathComponent("logs")
            let logURL = logDir.appendingPathComponent(target)
            try FileManager.default.createDirectory(at: logURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: logURL.path) {
                FileManager.default.createFile(atPath: logURL.path, contents: nil)
            }
            let handle = try FileHandle(forWritingTo: logURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: Data(line.utf8))
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

    

    
    public func headCommit() throws -> CommitPayload? {
        guard let oid = try refs.headOID(objects: objects) else { return nil }
        return try commitObject(oid)
    }

    
    
    public func resolveRevision(_ text: String) throws -> ObjectID {
        var spec = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !spec.isEmpty else { throw SpacesError.ambiguousRevision(text) }

        
        var base = spec
        var caretSteps = 0
        var tildeSteps = 0
        
        while true {
            guard let m = base.range(of: #"[\^~][0-9]*$"#, options: .regularExpression) else { break }
            let suffix = String(base[m])
            base = String(base[..<m.lowerBound])
            let op = suffix.first!
            let digits = suffix.dropFirst()
            let n = digits.isEmpty ? 1 : (Int(digits) ?? 1)
            if op == "~" { tildeSteps += n } else { caretSteps += n }
        }
        if base.isEmpty && (caretSteps > 0 || tildeSteps > 0) { base = "HEAD" }

        var oid = try resolveBase(base)
        
        for _ in 0..<tildeSteps {
            oid = try firstParent(of: oid)
        }
        if caretSteps > 0 {
            let commit = try commitObject(oid)
            let parentIndex = caretSteps - 1
            guard parentIndex < commit.parents.count else {
                throw SpacesError.invalidArgument("\(spec): commit has no such parent")
            }
            oid = commit.parents[parentIndex]
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
        let base = worktreeURL.path
        let full = url.standardizedFileURL.path
        guard full.hasPrefix(base) else { throw SpacesError.pathOutsideRepository(full) }
        var rel = String(full.dropFirst(base.count))
        if rel.hasPrefix("/") { rel.removeFirst() }
        return rel
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
