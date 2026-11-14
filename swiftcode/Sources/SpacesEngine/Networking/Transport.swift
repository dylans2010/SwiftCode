import Foundation

/// Spaces networking: a versioned wire protocol (`spaces-proto/1`) carried
/// over pluggable transports. The local transport (filesystem path or
/// file:// URL) is fully implemented — it performs real object transfer and
/// ref negotiation between two repository object stores. The HTTP transport
/// implements the client side of the protocol; it requires a Spaces server,
/// which is documented as server-dependent infrastructure.
///
/// Protocol (newline-delimited JSON messages):
///   C→S  {"v":1,"op":"hello","caps":[...]}
///   S→C  {"v":1,"op":"hello","caps":[...],"repo":"<id>"}
///   C→S  {"v":1,"op":"advertise-refs"}
///   S→C  {"v":1,"op":"refs","refs":[{"name","oid"}]}
///   C→S  {"v":1,"op":"want","oids":[...],"haves":[...]}
///   S→C  {"v":1,"op":"pack","objects":[{"id","type","data(b64)"}]}
///   C→S  {"v":1,"op":"have","oids":[...]}
///   S→C  {"v":1,"op":"ack","oids":[...]}
///   C→S  {"v":1,"op":"update-refs","refs":[{"name","oid","old"?}]}
///   S→C  {"v":1,"op":"ok"|"error","message"?}

public protocol SpacesTransport: Sendable {
    /// Opens a connection to the remote repository.
    func connect() throws -> TransportConnection
}

public protocol TransportConnection: Sendable {
    func send(_ message: [String: Any]) throws
    func receive() throws -> [String: Any]
    func close()
}

/// Local transport: connects to another repository on the filesystem.
/// "Networking" over this transport is real — objects are copied between
/// object stores with full integrity verification.
public struct LocalTransport: SpacesTransport {
    public let path: String
    public init(path: String) { self.path = path }

    public func resolve() throws -> URL {
        var url = URL(fileURLWithPath: path)
        if url.scheme == "file" { url = URL(fileURLWithPath: url.path) }
        // Accept paths to either the worktree or the .spaces dir.
        var candidate = url
        if candidate.lastPathComponent == RepositoryFormat.metadataDirectoryName {
            candidate = candidate.deletingLastPathComponent()
        }
        guard FileManager.default.fileExists(
            atPath: RepositoryFormat.metadataURL(for: candidate).path) else {
            throw SpacesError.remoteError("not a Spaces repository: \(path)")
        }
        return candidate
    }

    public func connect() throws -> TransportConnection {
        // For the local transport the "wire" is a direct in-process bridge;
        // we return a connection that delegates to the remote Repository.
        return LocalConnection(remote: try resolve())
    }
}

/// In-process connection implementing the protocol against a local repo.
final class LocalConnection: TransportConnection, @unchecked Sendable {
    let remoteWorktree: URL
    var closed = false

    init(remote: URL) { self.remoteWorktree = remote }

    private func remoteRepo() throws -> Repository {
        try Repository(worktree: remoteWorktree)
    }

    func send(_ message: [String: Any]) throws {
        guard let op = message["op"] as? String else {
            throw SpacesError.protocolError("missing op")
        }
        let repo = try remoteRepo()
        switch op {
        case "hello":
            pending = ["v": RepositoryFormat.protocolVersion, "op": "hello",
                       "caps": ["objects-v1", "refs-v1"],
                       "repo": remoteWorktree.lastPathComponent]
        case "advertise-refs":
            let refs = try repo.refs.allRefs().map {
                ["name": $0.name, "oid": $0.oid.hex] as [String: Any]
            }
            // Local transport doesn't need receive(); ops are synchronous.
            // We stash the response for receive().
            pending = ["v": 1, "op": "refs", "refs": refs]
        case "want":
            let oids = (message["oids"] as? [String]) ?? []
            let haves = (message["haves"] as? [String]) ?? []
            let objects = try producePack(repo: repo, wants: oids, haves: haves)
            pending = ["v": 1, "op": "pack", "objects": objects]
        case "update-refs":
            let refs = (message["refs"] as? [[String: Any]]) ?? []
            for r in refs {
                guard let name = r["name"] as? String, let hex = r["oid"] as? String,
                      let oid = try? ObjectID(validating: hex) else { continue }
                _ = try repo.refs.updateRef(name, to: oid)
            }
            pending = ["v": 1, "op": "ok"]
        case "have":
            let oids = (message["oids"] as? [String]) ?? []
            var present: [String] = []
            for h in oids {
                if let oid = try? ObjectID(validating: h), repo.objects.exists(oid) {
                    present.append(h)
                }
            }
            pending = ["v": 1, "op": "ack", "oids": present]
        case "store":
            // Push path: client sends objects the remote lacks.
            let objects = (message["objects"] as? [[String: Any]]) ?? []
            for o in objects {
                guard let hex = o["id"] as? String,
                      let typeRaw = o["type"] as? String,
                      let type = ObjectType(rawValue: typeRaw),
                      let b64 = o["data"] as? String,
                      let payload = Data(base64Encoded: b64),
                      let oid = try? ObjectID(validating: hex) else { continue }
                // Verify before storing — never trust remote metadata.
                guard ObjectID.compute(type: type, payload: payload) == oid else { continue }
                _ = try repo.objects.write(type: type, payload: payload)
            }
            pending = ["v": 1, "op": "ok"]
        default:
            throw SpacesError.protocolError("unknown op: \(op)")
        }
    }

    private var pending: [String: Any]?

    func receive() throws -> [String: Any] {
        guard let p = pending else { throw SpacesError.protocolError("no pending response") }
        pending = nil
        return p
    }

    func close() { closed = true }

    /// Produces the objects the remote should send: all objects reachable
    /// from `wants` but not from `haves`.
    private func producePack(repo: Repository, wants: [String], haves: [String]) throws -> [[String: Any]] {
        var wantIDs: [ObjectID] = []
        for w in wants { if let o = try? ObjectID(validating: w) { wantIDs.append(o) } }
        var haveIDs: [ObjectID] = []
        for h in haves { if let o = try? ObjectID(validating: h) { haveIDs.append(o) } }

        let wantReach = try repo.objects.reachable(from: wantIDs)
        let haveReach = try repo.objects.reachable(from: haveIDs)
        let toSend = wantReach.subtracting(haveReach)

        var result: [[String: Any]] = []
        // Send commits/trees/tags before blobs isn't required (receiver
        // stores all); order by type for readability.
        for id in toSend.sorted() {
            guard let stored = try? repo.objects.read(id) else { continue }
            result.append([
                "id": id.hex,
                "type": stored.type.rawValue,
                "data": stored.payload.base64EncodedString()
            ])
        }
        return result
    }
}

/// HTTP transport client for `spaces://`/`https://` remotes.
/// Implements protocol framing over HTTP POST; requires a Spaces server
/// implementing the same protocol (server is separate infrastructure).
public struct HTTPTransport: SpacesTransport {
    public let url: URL
    public let credentials: Credentials?

    public init(url: URL, credentials: Credentials? = nil) {
        self.url = url
        self.credentials = credentials
    }

    public func connect() throws -> TransportConnection {
        // Probe the endpoint; a Spaces server responds to GET /info/refs.
        var request = URLRequest(url: url.appendingPathComponent("info/refs"))
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        if let creds = credentials {
            let token = creds.token ?? ""
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let semaphore = DispatchSemaphore(value: 0)
        var responseData: Data?
        var responseError: Error?
        URLSession.shared.dataTask(with: request) { data, response, error in
            responseError = error
            responseData = data
            if let http = response as? HTTPURLResponse, http.statusCode == 401 {
                responseError = SpacesError.authenticationRequired(url.absoluteString)
            }
            semaphore.signal()
        }.resume()
        semaphore.wait()
        if let e = responseError { throw e }
        guard responseData != nil else {
            throw SpacesError.remoteError("empty response from \(url.absoluteString)")
        }
        return HTTPConnection(base: url, credentials: credentials)
    }
}

final class HTTPConnection: TransportConnection, @unchecked Sendable {
    let base: URL
    let credentials: Credentials?

    init(base: URL, credentials: Credentials?) {
        self.base = base
        self.credentials = credentials
    }

    func send(_ message: [String: Any]) throws {
        // Each message is a POST to /rpc/<op>; response retrieved via receive().
        guard let op = message["op"] as? String else {
            throw SpacesError.protocolError("missing op")
        }
        var request = URLRequest(url: base.appendingPathComponent("rpc/\(op)"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let creds = credentials {
            request.setValue("Bearer \(creds.token ?? "")", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: message)
        let semaphore = DispatchSemaphore(value: 0)
        var result: [String: Any]?
        var failure: Error?
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error { failure = error }
            else if let http = response as? HTTPURLResponse {
                switch http.statusCode {
                case 200:
                    if let data,
                       let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        result = obj
                    }
                case 401:
                    failure = SpacesError.authenticationRequired(self.base.absoluteString)
                default:
                    failure = SpacesError.remoteError("HTTP \(http.statusCode)")
                }
            }
            semaphore.signal()
        }.resume()
        semaphore.wait()
        if let failure { throw failure }
        pending = result
    }

    private var pending: [String: Any]?

    func receive() throws -> [String: Any] {
        guard let p = pending else { throw SpacesError.protocolError("no pending response") }
        pending = nil
        return p
    }

    func close() {}
}

/// Credential storage abstraction. The default Keychain store is used on
/// macOS; a file-based fallback exists for headless/Linux use. Tokens are
/// never logged.
public struct Credentials: Codable, Sendable {
    public var token: String?
    public var username: String?
    public var kind: String // "token" | "basic" | "ssh-agent"

    public init(token: String? = nil, username: String? = nil, kind: String = "token") {
        self.token = token
        self.username = username
        self.kind = kind
    }
}

public protocol CredentialStore: Sendable {
    func load(host: String) throws -> Credentials?
    func save(_ creds: Credentials, for host: String) throws
    func delete(host: String) throws
}

/// File-based credential store at `~/.config/spaces/credentials.json`
/// (mode 0600). On macOS the Keychain-backed store is preferred; see
/// `KeychainCredentialStore`.
public final class FileCredentialStore: CredentialStore, @unchecked Sendable {
    public let url: URL
    public init(url: URL? = nil) {
        self.url = url ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/spaces/credentials.json")
    }

    private func all() throws -> [String: Credentials] {
        guard let data = try? Data(contentsOf: url),
              let dict = try? JSONDecoder().decode([String: Credentials].self, from: data) else {
            return [:]
        }
        return dict
    }

    private func writeAll(_ dict: [String: Credentials]) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(dict).write(to: url)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    public func load(host: String) throws -> Credentials? { try all()[host] }
    public func save(_ creds: Credentials, for host: String) throws {
        var dict = try all(); dict[host] = creds; try writeAll(dict)
    }
    public func delete(host: String) throws {
        var dict = try all(); dict.removeValue(forKey: host); try writeAll(dict)
    }
}

#if os(macOS)
import Security

/// macOS Keychain-backed credential store (service "dev.swiftcode.spaces").
public struct KeychainCredentialStore: CredentialStore {
    public init() {}
    private let service = "dev.swiftcode.spaces"

    public func load(host: String) throws -> Credentials? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: host,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return try? JSONDecoder().decode(Credentials.self, from: data)
    }

    public func save(_ creds: Credentials, for host: String) throws {
        let data = try JSONEncoder().encode(creds)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: host
        ]
        let attrs: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
        if status == errSecItemNotFound {
            var add = query
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            SecItemAdd(add as CFDictionary, nil)
        }
    }

    public func delete(host: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: host
        ]
        SecItemDelete(query as CFDictionary)
    }
}
#endif
