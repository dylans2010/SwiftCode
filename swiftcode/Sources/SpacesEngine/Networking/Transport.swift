import Foundation




















public protocol SpacesTransport: Sendable {
    
    func connect() throws -> TransportConnection
}

public protocol TransportConnection: Sendable {
    func send(_ message: [String: Any]) throws
    func receive() throws -> [String: Any]
    func close()
}




public struct LocalTransport: SpacesTransport {
    public let path: String
    public init(path: String) { self.path = path }

    public func resolve() throws -> URL {
        var url = URL(fileURLWithPath: path)
        if url.scheme == "file" { url = URL(fileURLWithPath: url.path) }
        
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
        
        
        return LocalConnection(remote: try resolve())
    }
}


final class LocalConnection: TransportConnection, @unchecked Sendable {
    let remoteWorktree: URL
    var closed = false

    init(remote: URL) { self.remoteWorktree = remote }

    private func remoteRepo() throws -> Repository {
        try Repository(worktree: remoteWorktree)
    }

    func send(_ message: [String: Any]) throws {
        let repo = try remoteRepo()
        pending = try SpacesProtocolHandler(repo: repo).handle(message)
    }

    private var pending: [String: Any]?


    func receive() throws -> [String: Any] {
        guard let p = pending else { throw SpacesError.protocolError("no pending response") }
        pending = nil
        return p
    }

    func close() { closed = true }
}





func spacesSanitizedURLString(_ raw: String) -> String {
    guard var components = URLComponents(string: raw) else { return raw }
    components.user = nil
    components.password = nil
    return components.string ?? raw
}

private func isTransientNetworkError(_ error: Error) -> Bool {
    guard let urlError = error as? URLError else { return false }
    switch urlError.code {
    case .timedOut, .cannotFindHost, .cannotConnectToHost, .networkConnectionLost,
         .dnsLookupFailed, .notConnectedToInternet, .resourceUnavailable,
         .secureConnectionFailed, .cannotLoadFromNetwork:
        return true
    default:
        return false
    }
}

private func performHTTPRequest(_ request: URLRequest, attempts: Int = 3) throws -> (Data, HTTPURLResponse) {
    var delay: TimeInterval = 1
    var lastError: Error?
    for attempt in 0..<attempts {
        let semaphore = DispatchSemaphore(value: 0)
        var responseData: Data?
        var response: URLResponse?
        var responseError: Error?
        URLSession.shared.dataTask(with: request) { data, resp, error in
            responseData = data
            response = resp
            responseError = error
            semaphore.signal()
        }.resume()
        semaphore.wait()
        if let responseError {
            lastError = responseError
            if attempt + 1 < attempts, isTransientNetworkError(responseError) {
                Thread.sleep(forTimeInterval: delay)
                delay *= 2
                continue
            }
            throw responseError
        }
        guard let http = response as? HTTPURLResponse, let data = responseData else {
            throw SpacesError.remoteError("empty response")
        }
        return (data, http)
    }
    throw lastError ?? SpacesError.remoteError("request failed")
}

public struct HTTPTransport: SpacesTransport {
    public let url: URL
    public let credentials: Credentials?

    public init(url: URL, credentials: Credentials? = nil) {
        self.url = url
        self.credentials = credentials
    }

    public func connect() throws -> TransportConnection {
        var request = URLRequest(url: url.appendingPathComponent("info/refs"))
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        if let creds = credentials {
            let token = creds.token ?? ""
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (_, http) = try performHTTPRequest(request)
        if http.statusCode == 401 {
            throw SpacesError.authenticationRequired(spacesSanitizedURLString(url.absoluteString))
        }
        guard (200...399).contains(http.statusCode) else {
            throw SpacesError.remoteError("HTTP \(http.statusCode) from \(spacesSanitizedURLString(url.absoluteString))")
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
        guard let op = message["op"] as? String else {
            throw SpacesError.protocolError("missing op")
        }
        var request = URLRequest(url: base.appendingPathComponent("rpc/\(op)"))
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let creds = credentials {
            request.setValue("Bearer \(creds.token ?? "")", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: message)
        let (data, http) = try performHTTPRequest(request)
        switch http.statusCode {
        case 200:
            guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw SpacesError.protocolError("invalid JSON response for op \(op)")
            }
            pending = obj
        case 401:
            throw SpacesError.authenticationRequired(spacesSanitizedURLString(base.absoluteString))
        default:
            throw SpacesError.remoteError("HTTP \(http.statusCode)")
        }
    }

    private var pending: [String: Any]?

    func receive() throws -> [String: Any] {
        guard let p = pending else { throw SpacesError.protocolError("no pending response") }
        pending = nil
        return p
    }

    func close() {}
}




public struct Credentials: Codable, Sendable {
    public var token: String?
    public var username: String?
    public var kind: String 

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
    func listCredentialIdentities() throws -> [(host: String, username: String?)]
}




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

    public func listCredentialIdentities() throws -> [(host: String, username: String?)] {
        try all().map { (host: $0.key, username: $0.value.username) }
            .sorted { $0.host < $1.host }
    }
}

#if os(macOS)
import Security


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

    public func listCredentialIdentities() throws -> [(host: String, username: String?)] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        var items: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &items)
        guard status == errSecSuccess, let results = items as? [[String: Any]] else { return [] }
        return results.compactMap { attrs in
            guard let host = attrs[kSecAttrAccount as String] as? String else { return nil }
            return (host: host, username: nil)
        }.sorted { $0.host < $1.host }
    }
}
#endif
