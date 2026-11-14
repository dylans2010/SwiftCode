import Foundation

/// Remote operations: clone, fetch, push, pull, remote management.
/// Uses the Spaces wire protocol over pluggable transports. The local
/// transport performs real object transfer between repositories; HTTP
/// remotes require a Spaces server (documented limitation).
public struct RemoteOps {
    public let repo: Repository
    public var cancelRequested = false
    public init(repo: Repository) { self.repo = repo }

    public struct TransferProgress: Codable, Sendable {
        public var remote: String
        public var direction: String
        public var transferred: Int
        public var alreadyPresent: Int
        public var failed: [String]
        public var objectIDs: [String]
        public var lastCheckpoint: Int64
        public var completed: Bool
    }

    public struct TransferReport: Sendable {
        public var remote: String
        public var direction: String
        public var transferred: Int
        public var alreadyPresent: Int
        public var failed: [String]
        public var totalObjects: Int
    }

    public struct RemoteHealth: Sendable {
        public var remote: String
        public var reachable: Bool
        public var lastSync: Int64?
        public var objectCount: Int
        public var remoteRefCount: Int
    }

    public mutating func requestCancellation() {
        cancelRequested = true
    }

    private func remoteDirectory(_ remote: String) -> URL {
        repo.metaURL.appendingPathComponent("remotes").appendingPathComponent(remote)
    }

    private func progressURL(_ remote: String) -> URL {
        remoteDirectory(remote).appendingPathComponent("progress.json")
    }

    private func cancelURL(_ remote: String) -> URL {
        remoteDirectory(remote).appendingPathComponent("cancel")
    }

    private func loadProgress(_ remote: String) -> TransferProgress? {
        guard let data = try? Data(contentsOf: progressURL(remote)) else { return nil }
        return try? JSONDecoder().decode(TransferProgress.self, from: data)
    }

    private func saveProgress(_ progress: TransferProgress) throws {
        let dir = remoteDirectory(progress.remote)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        try repo.refs.atomicWrite(progressURL(progress.remote), contents: encoder.encode(progress))
    }

    private func checkCancellation(_ remote: String) throws {
        if cancelRequested || FileManager.default.fileExists(atPath: cancelURL(remote).path) {
            throw SpacesError.cancelled
        }
    }

    public func cancelRemoteTransfer(_ remote: String) throws {
        let dir = remoteDirectory(remote)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data().write(to: cancelURL(remote), options: .atomic)
    }

    public func clearRemoteCancel(_ remote: String) {
        try? FileManager.default.removeItem(at: cancelURL(remote))
    }

    public func lastTransferReport(_ remote: String) throws -> TransferReport? {
        guard let progress = loadProgress(remote) else { return nil }
        return TransferReport(remote: progress.remote, direction: progress.direction,
                              transferred: progress.transferred, alreadyPresent: progress.alreadyPresent,
                              failed: progress.failed,
                              totalObjects: progress.transferred + progress.alreadyPresent + progress.failed.count)
    }

    @discardableResult
    public func resumeFetch(_ remote: String) throws -> TransferReport {
        _ = try fetch(remote)
        guard let report = try lastTransferReport(remote) else {
            throw SpacesError.internalInconsistency("missing transfer progress for \(remote)")
        }
        return report
    }

    @discardableResult
    public func resumePush(_ remote: String, refspec: String) throws -> TransferReport {
        _ = try push(remote, refspec: refspec)
        guard let report = try lastTransferReport(remote) else {
            throw SpacesError.internalInconsistency("missing transfer progress for \(remote)")
        }
        return report
    }

    public func remoteHealth(_ remote: String) throws -> RemoteHealth {
        guard let cfg = repo.config.remotes[remote] else {
            throw SpacesError.remoteNotFound(remote)
        }
        let reachable: Bool
        if cfg.url.hasPrefix("http://") || cfg.url.hasPrefix("https://") || cfg.url.hasPrefix("spaces://") {
            reachable = httpReachable(urlString: cfg.url)
        } else {
            reachable = (try? LocalTransport(path: cfg.url).resolve()) != nil
        }
        var lastSync: Int64? = nil
        var refCount = 0
        for ref in try repo.refs.allRefs() where ref.name.hasPrefix("refs/remotes/\(remote)/") {
            refCount += 1
            if let entry = try repo.readReflog(refName: ref.name, limit: 1).first {
                if lastSync == nil || entry.timestamp > (lastSync ?? 0) {
                    lastSync = entry.timestamp
                }
            }
        }
        let counts = try MaintenanceOps(repo: repo).countObjects()
        return RemoteHealth(remote: remote, reachable: reachable, lastSync: lastSync,
                            objectCount: counts.total, remoteRefCount: refCount)
    }

    private func httpReachable(urlString: String) -> Bool {
        var target = urlString
        if target.hasPrefix("spaces://") {
            target = "https://" + target.dropFirst("spaces://".count)
        }
        guard let url = URL(string: target) else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5
        let semaphore = DispatchSemaphore(value: 0)
        var ok = false
        URLSession.shared.dataTask(with: request) { _, response, _ in
            if let http = response as? HTTPURLResponse, (200...399).contains(http.statusCode) {
                ok = true
            }
            semaphore.signal()
        }.resume()
        semaphore.wait()
        return ok
    }

    public struct RemoteInfo: Sendable {
        public var name: String
        public var url: String
        public var fetchSpec: String
        public var pushURL: String?
    }

    public func list() -> [RemoteInfo] {
        repo.config.remotes.map {
            RemoteInfo(name: $0.key, url: $0.value.url,
                       fetchSpec: $0.value.fetchSpec, pushURL: $0.value.pushURL)
        }.sorted { $0.name < $1.name }
    }

    public func add(_ name: String, url: String, pushURL: String? = nil) throws { return try repo.withLock {
        guard !name.isEmpty, !url.isEmpty else {
            throw SpacesError.invalidArgument("remote name and url required")
        }
        repo.config.remotes[name] = SpacesConfig.RemoteConfig(url: url, pushURL: pushURL)
        try repo.saveConfig()
        }
    }

    public func remove(_ name: String) throws { return try repo.withLock {
        guard repo.config.remotes[name] != nil else { throw SpacesError.remoteNotFound(name) }
        repo.config.remotes.removeValue(forKey: name)
        // Remove remote-tracking refs.
        for ref in try repo.refs.allRefs() where ref.name.hasPrefix("refs/remotes/\(name)/") {
            try repo.refs.deleteRef(ref.name)
        }
        try repo.saveConfig()
        }
    }

    public func setURL(_ name: String, url: String) throws { return try repo.withLock {
        guard repo.config.remotes[name] != nil else { throw SpacesError.remoteNotFound(name) }
        repo.config.remotes[name]!.url = url
        try repo.saveConfig()
        }
    }

    // MARK: - Transport resolution

    public func transport(for remote: String) throws -> SpacesTransport {
        guard let cfg = repo.config.remotes[remote] else {
            throw SpacesError.remoteNotFound(remote)
        }
        return try transport(forURL: cfg.url)
    }

    public func transport(forURL url: String) throws -> SpacesTransport {
        if url.hasPrefix("http://") || url.hasPrefix("https://") || url.hasPrefix("spaces://") {
            var u = url
            if u.hasPrefix("spaces://") { u = "https://" + u.dropFirst("spaces://".count) }
            guard let urlObj = URL(string: u) else {
                throw SpacesError.invalidArgument("bad remote url: \(url)")
            }
            #if os(macOS)
            let store = KeychainCredentialStore()
            #else
            let store = FileCredentialStore()
            #endif
            let host = urlObj.host ?? url
            let creds = try? store.load(host: host)
            return HTTPTransport(url: urlObj, credentials: creds)
        }
        // Local path or file:// URL.
        return LocalTransport(path: url)
    }

    // MARK: - Fetch

    public struct FetchReport: Sendable, Encodable {
        public var remote: String
        public var newObjects: Int
        public var updatedRefs: [String]
        public var remoteRefs: [Ref]
    }

    @discardableResult
    public func fetch(_ remote: String, prune: Bool = false) throws -> FetchReport { return try repo.withLock {
        try checkCancellation(remote)
        let transport = try transport(for: remote)
        let conn = try transport.connect()
        defer { conn.close() }

        try conn.send(["v": RepositoryFormat.protocolVersion, "op": "hello",
                       "caps": ["objects-v1", "refs-v1"]])
        _ = try conn.receive()

        try conn.send(["v": RepositoryFormat.protocolVersion, "op": "advertise-refs"])
        let refsMsg = try conn.receive()
        guard let refsArr = refsMsg["refs"] as? [[String: Any]] else {
            throw SpacesError.protocolError("bad refs advertisement")
        }
        var remoteRefs: [Ref] = []
        for r in refsArr {
            guard let name = r["name"] as? String, let hex = r["oid"] as? String,
                  let oid = try? ObjectID(validating: hex) else { continue }
            remoteRefs.append(Ref(name: name, oid: oid))
        }

        let localReachable = try MaintenanceOps(repo: repo).reachableSet()
        var wants: [String] = []
        var haves: [String] = []
        for ref in try repo.refs.allRefs() { haves.append(ref.oid.hex) }
        for r in remoteRefs {
            guard r.name.hasPrefix("refs/heads/") || r.name.hasPrefix("refs/tags/") else { continue }
            if !localReachable.contains(r.oid) {
                wants.append(r.oid.hex)
            }
        }
        guard !wants.isEmpty else {
            let report = try updateTrackingRefs(remote: remote, remoteRefs: remoteRefs, newObjects: 0)
            try saveProgress(TransferProgress(remote: remote, direction: "fetch", transferred: 0,
                                              alreadyPresent: 0, failed: [], objectIDs: [],
                                              lastCheckpoint: Int64(Date().timeIntervalSince1970),
                                              completed: true))
            return report
        }

        try conn.send(["v": RepositoryFormat.protocolVersion, "op": "want",
                       "oids": wants, "haves": haves])
        let packMsg = try conn.receive()
        guard packMsg["op"] as? String == "pack",
              let objects = packMsg["objects"] as? [[String: Any]] else {
            throw SpacesError.protocolError("expected pack response")
        }
        try checkCancellation(remote)

        var stored = 0
        var alreadyPresent = 0
        var receivedIDs: [String] = []
        for o in objects {
            guard let hex = o["id"] as? String,
                  let typeRaw = o["type"] as? String,
                  let type = ObjectType(rawValue: typeRaw),
                  let b64 = o["data"] as? String,
                  let payload = Data(base64Encoded: b64),
                  let oid = try? ObjectID(validating: hex) else { continue }
            guard ObjectID.compute(type: type, payload: payload) == oid else {
                throw SpacesError.objectCorrupt(hex)
            }
            receivedIDs.append(hex)
            if repo.objects.exists(oid) {
                alreadyPresent += 1
                continue
            }
            _ = try repo.objects.write(type: type, payload: payload)
            stored += 1
        }

        var failed: [String] = []
        for hex in receivedIDs {
            if let oid = try? ObjectID(validating: hex) {
                do { _ = try repo.objects.read(oid) } catch { failed.append(hex) }
            }
        }
        try saveProgress(TransferProgress(remote: remote, direction: "fetch", transferred: stored,
                                          alreadyPresent: alreadyPresent, failed: failed,
                                          objectIDs: receivedIDs,
                                          lastCheckpoint: Int64(Date().timeIntervalSince1970),
                                          completed: failed.isEmpty))

        return try updateTrackingRefs(remote: remote, remoteRefs: remoteRefs,
                                      newObjects: stored)
        }
    }

    private func updateTrackingRefs(remote: String, remoteRefs: [Ref],
                                    newObjects: Int) throws -> FetchReport {
        var updated: [String] = []
        for r in remoteRefs {
            let localName: String
            if r.name.hasPrefix("refs/heads/") {
                localName = "refs/remotes/\(remote)/\(String(r.name.dropFirst("refs/heads/".count)))"
            } else if r.name == "HEAD" {
                continue
            } else {
                localName = r.name // tags go to refs/tags/
            }
            let old = try repo.refs.readRef(localName)
            if old != r.oid {
                _ = try repo.refs.updateRef(localName, to: r.oid)
                updated.append(localName)
                try repo.appendReflog(refName: localName, old: old, new: r.oid,
                                      message: "fetch \(remote)")
            }
        }
        return FetchReport(remote: remote, newObjects: newObjects,
                           updatedRefs: updated, remoteRefs: remoteRefs)
    }

    /// `spaces pull <remote> <branch>` — fetch + merge into current branch.
    @discardableResult
    public func pull(_ remote: String, branch: String? = nil) throws -> MergeEngine.MergeOutcome? { return try repo.withLock {
        _ = try fetch(remote)
        // Determine what to merge: the remote-tracking ref for the given
        // branch, the configured upstream, or the remote's default branch.
        var target: String? = nil
        if let b = branch {
            let tracking = "refs/remotes/\(remote)/\(b)"
            if try repo.refs.readRef(tracking) != nil { target = tracking }
            else { target = b }
        }
        if target == nil, let current = try repo.refs.currentBranch(),
           let up = repo.config.branchTracking[current] {
            let parts = up.split(separator: "/", maxSplits: 1).map(String.init)
            if parts.count == 2 { target = "refs/remotes/\(parts[0])/\(parts[1])" }
        }
        if target == nil {
            // Fall back to the remote's main/master tracking ref.
            for cand in ["refs/remotes/\(remote)/main", "refs/remotes/\(remote)/master"] {
                if try repo.refs.readRef(cand) != nil { target = cand; break }
            }
        }
        guard let t = target else {
            throw SpacesError.invalidArgument("no upstream configured; specify branch")
        }
        return try MergeEngine(repo: repo).merge(t)
        }
    }

    // MARK: - Push

    public struct PushReport: Sendable, Encodable {
        public var remote: String
        public var refsUpdated: [String]
        public var objectsSent: Int
    }

    @discardableResult
    public func push(_ remote: String, refspec: String) throws -> PushReport {
        try push(remote, refspec: refspec, force: false)
    }

    @discardableResult
    public func push(_ remote: String, refspec: String, force: Bool) throws -> PushReport { return try repo.withLock {
        try checkCancellation(remote)
        let parts = refspec.split(separator: ":", maxSplits: 1).map(String.init)
        let src = parts[0]
        let dst = parts.count > 1 ? parts[1] : src

        let srcOID = try repo.resolveRevision(src)
        let dstRefName = dst.hasPrefix("refs/") ? dst : "refs/heads/\(dst)"

        let transport = try transport(for: remote)
        let conn = try transport.connect()
        defer { conn.close() }

        try conn.send(["v": RepositoryFormat.protocolVersion, "op": "hello",
                       "caps": ["objects-v1", "refs-v1"]])
        _ = try conn.receive()
        try conn.send(["v": RepositoryFormat.protocolVersion, "op": "advertise-refs"])
        let refsMsg = try conn.receive()
        let remoteRefs = (refsMsg["refs"] as? [[String: Any]] ?? [])
            .compactMap { r -> (name: String, oid: ObjectID)? in
                guard let n = r["name"] as? String, let h = r["oid"] as? String,
                      let o = try? ObjectID(validating: h) else { return nil }
                return (n, o)
            }

        if let existing = remoteRefs.first(where: { $0.name == dstRefName }),
           existing.oid != srcOID {
            if force {
                let protected = try ProtectedHistoryOps(repo: repo).checkProtectedHistory(ref: dstRefName, operation: "force-push")
                if !protected.allowed {
                    try? AccessAuditOps(repo: repo).recordAuditEvent(operation: "force-push", details: "\(remote) \(refspec)", result: "denied: \(protected.reasons.joined(separator: "; "))")
                    throw SpacesError.invalidArgument(protected.reasons.joined(separator: "; "))
                }
            } else {
                let isAncestor = try isAncestorLocal(existing.oid, of: srcOID)
                if !isAncestor {
                    throw SpacesError.remoteError(
                        "non-fast-forward: \(dstRefName) on remote is not an ancestor (use --force)")
                }
            }
        }

        let remoteSeeds = remoteRefs.map(\.oid)
        var haveSeeds: [ObjectID] = []
        for ref in try repo.refs.allRefs()
        where ref.name.hasPrefix("refs/remotes/\(remote)/") {
            haveSeeds.append(ref.oid)
        }
        let haveReach = try repo.objects.reachable(from: haveSeeds)
        let wantReach = try repo.objects.reachable(from: [srcOID])
        var toSend = wantReach.subtracting(haveReach)
        var resumedIDs = Set<ObjectID>()
        let priorProgress = loadProgress(remote)
        if let prior = priorProgress, prior.direction == "push", !prior.completed {
            for hex in prior.objectIDs {
                if let oid = try? ObjectID(validating: hex) { resumedIDs.insert(oid) }
            }
        }
        let alreadyPresent = toSend.intersection(resumedIDs).count
        toSend.subtract(resumedIDs)

        var sent = 0
        var sentIDs: [String] = priorProgress?.objectIDs ?? []
        var failed: [String] = []
        let batchSize = 500
        let sorted = toSend.sorted { $0.hex < $1.hex }
        for chunkStart in stride(from: 0, to: sorted.count, by: batchSize) {
            do {
                try checkCancellation(remote)
            } catch {
                try saveProgress(TransferProgress(remote: remote, direction: "push", transferred: sent,
                                                  alreadyPresent: alreadyPresent, failed: failed,
                                                  objectIDs: sentIDs,
                                                  lastCheckpoint: Int64(Date().timeIntervalSince1970),
                                                  completed: false))
                throw error
            }
            let chunk = Array(sorted[chunkStart..<min(chunkStart + batchSize, sorted.count)])
            var objects: [[String: Any]] = []
            for id in chunk {
                do {
                    let stored = try repo.objects.read(id)
                    objects.append(["id": id.hex, "type": stored.type.rawValue,
                                    "data": stored.payload.base64EncodedString()])
                } catch {
                    failed.append(id.hex)
                }
            }
            try conn.send(["v": RepositoryFormat.protocolVersion, "op": "store",
                           "objects": objects])
            _ = try conn.receive()
            sent += objects.count
            sentIDs.append(contentsOf: objects.compactMap { $0["id"] as? String })
            try saveProgress(TransferProgress(remote: remote, direction: "push", transferred: sent,
                                              alreadyPresent: alreadyPresent, failed: failed,
                                              objectIDs: sentIDs,
                                              lastCheckpoint: Int64(Date().timeIntervalSince1970),
                                              completed: false))
        }

        try conn.send(["v": RepositoryFormat.protocolVersion, "op": "update-refs",
                       "refs": [["name": dstRefName, "oid": srcOID.hex]]])
        let ok = try conn.receive()
        guard ok["op"] as? String == "ok" else {
            throw SpacesError.protocolError("remote rejected ref update")
        }

        let trackName = "refs/remotes/\(remote)/\(dst)"
        _ = try repo.refs.updateRef(trackName, to: srcOID)
        try saveProgress(TransferProgress(remote: remote, direction: "push", transferred: sent,
                                          alreadyPresent: alreadyPresent, failed: failed,
                                          objectIDs: sentIDs,
                                          lastCheckpoint: Int64(Date().timeIntervalSince1970),
                                          completed: failed.isEmpty))
        try? AccessAuditOps(repo: repo).recordAuditEvent(operation: force ? "force-push" : "push",
                                                         details: "\(remote) \(refspec)", result: "success")
        return PushReport(remote: remote, refsUpdated: [dstRefName], objectsSent: sent)
        }
    }

    private func isAncestorLocal(_ ancestor: ObjectID, of descendant: ObjectID) throws -> Bool {
        var visited = Set<ObjectID>()
        var queue = [descendant]
        while !queue.isEmpty {
            let oid = queue.removeFirst()
            if oid == ancestor { return true }
            guard visited.insert(oid).inserted else { continue }
            queue.append(contentsOf: try repo.commitObject(oid).parents)
        }
        return false
    }

    /// `spaces sync <remote>` — fetch then push current branch.
    public func sync(_ remote: String) throws -> (fetch: FetchReport, push: PushReport?) { return try repo.withLock {
        let f = try fetch(remote)
        var p: PushReport? = nil
        if let current = try repo.refs.currentBranch(),
           let head = try repo.refs.headOID(objects: repo.objects) {
            p = try? push(remote, refspec: "\(head.hex):refs/heads/\(current)")
        }
        return (f, p)
        }
    }
}

/// `spaces clone <url> [dir]` — creates a new repository and fetches.
public enum CloneOps {
    public static func clone(url: String, into dest: URL? = nil,
                             repo: Repository? = nil) throws -> Repository {
        // Determine destination.
        let target: URL
        if let d = dest {
            target = d
        } else {
            var name = url
            if name.hasSuffix(".spaces") { name = String(name.dropLast(7)) }
            if name.hasSuffix("/") { name = String(name.dropLast()) }
            name = name.components(separatedBy: "/").last ?? "repo"
            target = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent(name)
        }
        if FileManager.default.fileExists(atPath: target.path),
           !(try FileManager.default.contentsOfDirectory(atPath: target.path).isEmpty) {
            throw SpacesError.invalidArgument("destination not empty: \(target.path)")
        }
        let newRepo = try Repository.create(at: target)
        // Add remote and fetch.
        let remoteName = "origin"
        try RemoteOps(repo: newRepo).add(remoteName, url: url)
        _ = try RemoteOps(repo: newRepo).fetch(remoteName)
        // Check out default branch: prefer remote HEAD → main/master.
        let remoteRefs = try newRepo.refs.allRefs()
            .filter { $0.name.hasPrefix("refs/remotes/origin/") }
        let preferred = ["main", "master"]
        var chosen: String? = nil
        for p in preferred {
            if remoteRefs.contains(where: { $0.name == "refs/remotes/origin/\(p)" }) {
                chosen = p; break
            }
        }
        if chosen == nil, let first = remoteRefs.first {
            chosen = String(first.name.dropFirst("refs/remotes/origin/".count))
        }
        if let branch = chosen {
            let remoteRef = "refs/remotes/origin/\(branch)"
            if let oid = try newRepo.refs.readRef(remoteRef) {
                _ = try newRepo.refs.updateRef("refs/heads/\(branch)", to: oid)
                try newRepo.refs.setHEAD(ref: "refs/heads/\(branch)")
                let commit = try newRepo.commitObject(oid)
                try MergeEngine(repo: newRepo).checkoutTree(commit.tree, overlay: [:])
                let flat = try TreeBuilder.flattenTree(repo: newRepo, treeOID: commit.tree)
                var index = Index()
                for (path, e) in flat {
                    let url = try newRepo.worktreeURL(forRelativePath: path)
                    index.entries[path] = try Index.entry(forFileAt: url, oid: e.oid, mode: e.mode)
                }
                try newRepo.saveIndex(index)
                try newRepo.appendReflog(refName: "HEAD", old: nil, new: oid,
                                         message: "clone: from \(url)")
            }
        }
        _ = repo
        return newRepo
    }
}
