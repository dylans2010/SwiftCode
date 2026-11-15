import Crypto
import Foundation

public enum LfsLocalStore {
    public static func objectsDirectory(repo: Repository) -> URL {
        repo.metaURL.appendingPathComponent("lfs/objects")
    }

    public static func partsDirectory(repo: Repository) -> URL {
        repo.metaURL.appendingPathComponent("lfs/tmp")
    }

    public static func objectURL(repo: Repository, oid: String) -> URL {
        objectsDirectory(repo: repo).appendingPathComponent(oid)
    }

    public static func partURL(repo: Repository, oid: String) -> URL {
        partsDirectory(repo: repo).appendingPathComponent(oid + ".part")
    }

    public static func isValidOID(_ oid: String) -> Bool {
        oid.count == 64 && oid.allSatisfy({ $0.isHexDigit })
    }

    public static func fileSize(at url: URL) -> Int64? {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value
    }

    public static func list(repo: Repository) throws -> [(oid: String, size: Int64)] {
        let dir = objectsDirectory(repo: repo)
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else {
            return []
        }
        var result: [(oid: String, size: Int64)] = []
        for name in names.sorted() where isValidOID(name) {
            let url = dir.appendingPathComponent(name)
            if let size = fileSize(at: url) {
                result.append((oid: name, size: size))
            }
        }
        return result
    }

    public static func sha256Hex(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    public static func sha256HexOfFile(at url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            let chunk = try handle.read(upToCount: LfsTransferOps.chunkSize) ?? Data()
            if chunk.isEmpty {
                break
            }
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    public static func verifyFile(at url: URL, oid: String, size: Int64) throws -> Bool {
        guard let actual = fileSize(at: url), actual == size else {
            return false
        }
        return try sha256HexOfFile(at: url) == oid.lowercased()
    }
}

public struct LfsTransferOps {
    public let repo: Repository

    public init(repo: Repository) {
        self.repo = repo
    }

    public static let chunkSize = 262144

    public struct LfsReport: Sendable {
        public var remote: String
        public var direction: String
        public var transferred: Int
        public var alreadyPresent: Int
        public var bytes: Int64
        public var failed: [String]
    }

    private enum PushOutcome {
        case alreadyPresent
        case transferred
    }

    private func sayHello(_ conn: TransportConnection) throws {
        try conn.send(["v": RepositoryFormat.protocolVersion, "op": "hello",
                       "caps": ["objects-v1", "refs-v1", "lfs-v1"]])
        let response = try conn.receive()
        guard let version = response["v"] as? Int,
              version == RepositoryFormat.protocolVersion else {
            throw SpacesError.protocolError("unsupported protocol version in hello response")
        }
        let caps = (response["caps"] as? [String]) ?? []
        for required in ["objects-v1", "refs-v1", "lfs-v1"] {
            guard caps.contains(required) else {
                throw SpacesError.protocolError("remote hello missing capability \(required)")
            }
        }
    }

    private func checkedReceive(_ conn: TransportConnection) throws -> [String: Any] {
        let message = try conn.receive()
        if message["op"] as? String == "error" {
            throw SpacesError.protocolError(message["error"] as? String ?? "remote error")
        }
        return message
    }

    @discardableResult
    public func fetch(_ remote: String) throws -> LfsReport { return try repo.withLock {
        let transport = try RemoteOps(repo: repo).transport(for: remote)
        let conn = try transport.connect()
        defer { conn.close() }
        try sayHello(conn)
        try conn.send(["v": RepositoryFormat.protocolVersion, "op": "lfs-list"])
        let listMsg = try checkedReceive(conn)
        guard let objects = listMsg["objects"] as? [[String: Any]] else {
            throw SpacesError.protocolError("bad lfs-list response")
        }
        var transferred = 0
        var alreadyPresent = 0
        var bytes: Int64 = 0
        var failed: [String] = []
        for entry in objects {
            guard let oid = entry["oid"] as? String,
                  let size = SpacesProtocolHandler.jsonInt(entry["size"]) else { continue }
            do {
                let localURL = LfsLocalStore.objectURL(repo: repo, oid: oid)
                if (try? LfsLocalStore.verifyFile(at: localURL, oid: oid, size: size)) == true {
                    alreadyPresent += 1
                    continue
                }
                try fetchObject(conn: conn, oid: oid, size: size)
                transferred += 1
                bytes += size
            } catch {
                failed.append(oid)
            }
        }
        return LfsReport(remote: remote, direction: "fetch", transferred: transferred,
                         alreadyPresent: alreadyPresent, bytes: bytes, failed: failed)
        }
    }

    @discardableResult
    public func pull(_ remote: String) throws -> LfsReport {
        var report = try fetch(remote)
        report.direction = "pull"
        return report
    }

    @discardableResult
    public func push(_ remote: String) throws -> LfsReport { return try repo.withLock {
        let transport = try RemoteOps(repo: repo).transport(for: remote)
        let conn = try transport.connect()
        defer { conn.close() }
        try sayHello(conn)
        var transferred = 0
        var alreadyPresent = 0
        var bytes: Int64 = 0
        var failed: [String] = []
        for (oid, size) in try LfsLocalStore.list(repo: repo) {
            do {
                switch try pushObject(conn: conn, oid: oid, size: size) {
                case .alreadyPresent:
                    alreadyPresent += 1
                case .transferred:
                    transferred += 1
                    bytes += size
                }
            } catch {
                failed.append(oid)
            }
        }
        return LfsReport(remote: remote, direction: "push", transferred: transferred,
                         alreadyPresent: alreadyPresent, bytes: bytes, failed: failed)
        }
    }

    private func fetchObject(conn: TransportConnection, oid: String, size: Int64) throws {
        var attempt = 0
        while true {
            attempt += 1
            do {
                try fetchObjectOnce(conn: conn, oid: oid, size: size)
                return
            } catch let error as SpacesError {
                if attempt == 1, case .lfsError(let message) = error,
                   message.contains("hash verification") {
                    try? FileManager.default.removeItem(
                        at: LfsLocalStore.partURL(repo: repo, oid: oid))
                    continue
                }
                throw error
            }
        }
    }

    private func fetchObjectOnce(conn: TransportConnection, oid: String, size: Int64) throws {
        let partURL = LfsLocalStore.partURL(repo: repo, oid: oid)
        try FileManager.default.createDirectory(at: partURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: partURL.path) {
            _ = FileManager.default.createFile(atPath: partURL.path, contents: Data())
        }
        var offset = LfsLocalStore.fileSize(at: partURL) ?? 0
        if offset > size {
            try FileManager.default.removeItem(at: partURL)
            _ = FileManager.default.createFile(atPath: partURL.path, contents: Data())
            offset = 0
        }
        let handle = try FileHandle(forWritingTo: partURL)
        defer { try? handle.close() }
        try handle.seek(toOffset: UInt64(offset))
        while offset < size {
            try conn.send(["v": RepositoryFormat.protocolVersion, "op": "lfs-get",
                           "oid": oid, "offset": Int(offset)])
            let msg = try checkedReceive(conn)
            guard let b64 = msg["data"] as? String,
                  let chunk = Data(base64Encoded: b64) else {
                throw SpacesError.protocolError("bad lfs-get response for \(oid)")
            }
            guard SpacesProtocolHandler.jsonInt(msg["offset"]) == offset else {
                throw SpacesError.protocolError("lfs-get offset mismatch for \(oid)")
            }
            guard !chunk.isEmpty else {
                throw SpacesError.protocolError("lfs-get returned an empty chunk for \(oid)")
            }
            try handle.write(contentsOf: chunk)
            offset += Int64(chunk.count)
            if msg["complete"] as? Bool == true {
                break
            }
        }
        try handle.synchronize()
        guard offset == size else {
            throw SpacesError.lfsError("incomplete lfs transfer for \(oid): \(offset) of \(size) bytes")
        }
        guard try LfsLocalStore.verifyFile(at: partURL, oid: oid, size: size) else {
            try? FileManager.default.removeItem(at: partURL)
            throw SpacesError.lfsError("lfs object \(oid) failed hash verification; partial transfer removed")
        }
        let dest = LfsLocalStore.objectURL(repo: repo, oid: oid)
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.moveItem(at: partURL, to: dest)
    }

    private func pushObject(conn: TransportConnection, oid: String, size: Int64) throws -> PushOutcome {
        try conn.send(["v": RepositoryFormat.protocolVersion, "op": "lfs-info", "oid": oid])
        let info = try checkedReceive(conn)
        let stored = SpacesProtocolHandler.jsonInt(info["size"]) ?? 0
        let complete = info["complete"] as? Bool ?? false
        if complete && stored == size {
            return .alreadyPresent
        }
        let localURL = LfsLocalStore.objectURL(repo: repo, oid: oid)
        let handle = try FileHandle(forReadingFrom: localURL)
        defer { try? handle.close() }
        var offset = stored
        var attempts = 0
        while true {
            attempts += 1
            do {
                try handle.seek(toOffset: UInt64(offset))
                var remaining = size - offset
                while remaining > 0 {
                    let chunk = try handle.read(upToCount: Self.chunkSize) ?? Data()
                    guard !chunk.isEmpty else {
                        throw SpacesError.lfsError("short read on local lfs object \(oid)")
                    }
                    let isLast = Int64(chunk.count) >= remaining
                    try conn.send(["v": RepositoryFormat.protocolVersion, "op": "lfs-put",
                                   "oid": oid, "offset": Int(offset), "size": Int(size),
                                   "data": chunk.base64EncodedString(), "complete": isLast])
                    let ack = try checkedReceive(conn)
                    guard ack["op"] as? String == "ok" else {
                        throw SpacesError.protocolError("lfs-put rejected for \(oid)")
                    }
                    offset += Int64(chunk.count)
                    remaining -= Int64(chunk.count)
                }
                break
            } catch let error as SpacesError {
                if attempts == 1, case .protocolError(let message) = error,
                   message.contains("offset mismatch") {
                    offset = 0
                    continue
                }
                throw error
            }
        }
        try conn.send(["v": RepositoryFormat.protocolVersion, "op": "lfs-info", "oid": oid])
        let confirm = try checkedReceive(conn)
        guard confirm["complete"] as? Bool == true,
              SpacesProtocolHandler.jsonInt(confirm["size"]) == size else {
            throw SpacesError.lfsError("remote did not confirm complete lfs object \(oid)")
        }
        return .transferred
    }
}
