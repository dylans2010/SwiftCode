#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif
import Foundation

public final class SpacesHttpServer: @unchecked Sendable {
    public let repo: Repository
    public let requestedPort: UInt16
    public private(set) var boundPort: UInt16 = 0
    public private(set) var isRunning: Bool = false

    private let handler: SpacesProtocolHandler
    private let lock = NSLock()
    private var listenFD: Int32 = -1
    private var connectionFDs: Set<Int32> = []
    private let acceptQueue = DispatchQueue(label: "dev.swiftcode.spaces.http-accept")

    public init(repo: Repository, port: UInt16 = 0) {
        self.repo = repo
        self.requestedPort = port
        self.handler = SpacesProtocolHandler(repo: repo)
    }

    deinit {
        stop()
    }

    public var baseURL: URL {
        URL(string: "http://127.0.0.1:\(boundPort)") ?? URL(fileURLWithPath: "/")
    }

    public func start() throws {
        lock.lock()
        defer { lock.unlock() }
        guard listenFD < 0 else {
            throw SpacesError.remoteError("http server already running")
        }
        let fd = socket(AF_INET, SpacesHttpServer.streamSocketType, 0)
        guard fd >= 0 else {
            throw SpacesError.remoteError("could not create socket: \(SpacesHttpServer.posixMessage(errno))")
        }
        var reuse: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &reuse,
                   socklen_t(MemoryLayout<Int32>.size))
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = requestedPort.bigEndian
        addr.sin_addr = in_addr(s_addr: INADDR_ANY)
        #if canImport(Darwin)
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        #endif
        let bound = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bound == 0 else {
            let code = errno
            close(fd)
            throw SpacesError.remoteError("could not bind port \(requestedPort): \(SpacesHttpServer.posixMessage(code))")
        }
        guard listen(fd, 128) == 0 else {
            let code = errno
            close(fd)
            throw SpacesError.remoteError("could not listen: \(SpacesHttpServer.posixMessage(code))")
        }
        var actual = sockaddr_in()
        var actualLen = socklen_t(MemoryLayout<sockaddr_in>.size)
        withUnsafeMutablePointer(to: &actual) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                _ = getsockname(fd, $0, &actualLen)
            }
        }
        boundPort = UInt16(bigEndian: actual.sin_port)
        listenFD = fd
        isRunning = true
        acceptQueue.async { [weak self] in self?.acceptLoop() }
    }

    public func stop() {
        lock.lock()
        let fd = listenFD
        let conns = connectionFDs
        listenFD = -1
        isRunning = false
        connectionFDs.removeAll()
        lock.unlock()
        if fd >= 0 {
            shutdown(fd, Int32(SHUT_RDWR))
            close(fd)
        }
        for conn in conns {
            shutdown(conn, Int32(SHUT_RDWR))
            close(conn)
        }
    }

    private func acceptLoop() {
        while true {
            var peer = sockaddr_in()
            var peerLen = socklen_t(MemoryLayout<sockaddr_in>.size)
            let fd = withUnsafeMutablePointer(to: &peer) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    accept(listenFD, $0, &peerLen)
                }
            }
            if fd < 0 {
                let err = errno
                lock.lock()
                let running = isRunning
                lock.unlock()
                if !running { return }
                if err == EINTR { continue }
                return
            }
            lock.lock()
            connectionFDs.insert(fd)
            lock.unlock()
            DispatchQueue.global().async { [weak self] in
                self?.handleConnection(fd)
            }
        }
    }

    private func handleConnection(_ fd: Int32) {
        defer {
            lock.lock()
            connectionFDs.remove(fd)
            lock.unlock()
            close(fd)
        }
        do {
            guard let request = try readRequest(fd) else { return }
            let response = route(request)
            try writeAll(fd, response)
        } catch {
            return
        }
    }

    private struct HttpRequest {
        var method: String
        var path: String
        var headers: [String: String]
        var body: Data
    }

    private static let maxHeaderBytes = 65536
    private static let maxBodyBytes = 268435456

    private func readRequest(_ fd: Int32) throws -> HttpRequest? {
        var head = Data()
        var buffer = [UInt8](repeating: 0, count: 8192)
        var headerEnd: Data.Index? = nil
        while headerEnd == nil {
            guard head.count < Self.maxHeaderBytes else {
                throw SpacesError.protocolError("http request headers too large")
            }
            let read = buffer.withUnsafeMutableBytes { raw in
                recv(fd, raw.baseAddress, raw.count, 0)
            }
            if read < 0 {
                if errno == EINTR { continue }
                throw SpacesError.ioError("http read failed: \(Self.posixMessage(errno))")
            }
            if read == 0 {
                return nil
            }
            head.append(contentsOf: buffer.prefix(read))
            headerEnd = head.range(of: Data("\r\n\r\n".utf8))?.upperBound
        }
        guard let end = headerEnd else { return nil }
        let headerText = String(decoding: head.prefix(upTo: end), as: UTF8.self)
        let lines = headerText.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return nil }
        let requestParts = requestLine.split(separator: " ").map(String.init)
        guard requestParts.count >= 2 else {
            throw SpacesError.protocolError("malformed http request line")
        }
        var headers: [String: String] = [:]
        for line in lines.dropFirst() where !line.isEmpty {
            let parts = line.split(separator: ":", maxSplits: 1).map(String.init)
            if parts.count == 2 {
                headers[parts[0].trimmingCharacters(in: .whitespaces).lowercased()] =
                    parts[1].trimmingCharacters(in: .whitespaces)
            }
        }
        var body = Data(head.suffix(from: end))
        if headers["transfer-encoding"]?.lowercased() == "chunked" {
            throw SpacesError.unsupportedOperation("chunked transfer encoding is not supported")
        }
        let contentLength = Int(headers["content-length"] ?? "0") ?? 0
        guard contentLength >= 0, contentLength <= Self.maxBodyBytes else {
            throw SpacesError.protocolError("http content-length out of range")
        }
        while body.count < contentLength {
            let wanted = min(8192, contentLength - body.count)
            let read = buffer.withUnsafeMutableBytes { raw in
                recv(fd, raw.baseAddress, wanted, 0)
            }
            if read < 0 {
                if errno == EINTR { continue }
                throw SpacesError.ioError("http read failed: \(Self.posixMessage(errno))")
            }
            if read == 0 { break }
            body.append(contentsOf: buffer.prefix(read))
        }
        return HttpRequest(method: requestParts[0], path: requestParts[1],
                           headers: headers, body: body)
    }

    private func route(_ request: HttpRequest) -> Data {
        if request.method == "HEAD" {
            if request.path == "/" || request.path == "/info/refs" {
                return httpResponse(status: 200, reason: "OK", body: Data())
            }
            return httpResponse(status: 404, reason: "Not Found",
                                body: errorJSON("not found"))
        }
        if request.method == "GET" {
            if request.path == "/" || request.path == "/info/refs" {
                let hello: [String: Any] = ["v": RepositoryFormat.protocolVersion,
                                            "op": "hello",
                                            "caps": ["objects-v1", "refs-v1", "lfs-v1"],
                                            "repo": repo.worktreeURL.lastPathComponent]
                return httpResponse(status: 200, reason: "OK", body: jsonData(hello))
            }
            return httpResponse(status: 404, reason: "Not Found",
                                body: errorJSON("not found"))
        }
        if request.method == "POST", request.path.hasPrefix("/rpc/") {
            guard let message = try? JSONSerialization.jsonObject(with: request.body) as? [String: Any] else {
                return httpResponse(status: 400, reason: "Bad Request",
                                    body: errorJSON("request body is not a JSON object"))
            }
            do {
                let response = try handler.handle(message)
                return httpResponse(status: 200, reason: "OK", body: jsonData(response))
            } catch {
                let detail = (error as? SpacesError)?.errorDescription ?? error.localizedDescription
                return httpResponse(status: 200, reason: "OK", body: errorJSON(detail))
            }
        }
        return httpResponse(status: 404, reason: "Not Found",
                            body: errorJSON("not found"))
    }

    private func errorJSON(_ message: String) -> Data {
        jsonData(["v": RepositoryFormat.protocolVersion, "op": "error", "error": message])
    }

    private func jsonData(_ object: [String: Any]) -> Data {
        (try? JSONSerialization.data(withJSONObject: object)) ?? Data("{\"op\":\"error\"}".utf8)
    }

    private func httpResponse(status: Int, reason: String, body: Data) -> Data {
        var head = "HTTP/1.1 \(status) \(reason)\r\n"
        head += "Content-Type: application/json\r\n"
        head += "Content-Length: \(body.count)\r\n"
        head += "Connection: close\r\n\r\n"
        var response = Data(head.utf8)
        response.append(body)
        return response
    }

    private func writeAll(_ fd: Int32, _ data: Data) throws {
        var offset = 0
        try data.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return }
            while offset < data.count {
                let written = write(fd, base.advanced(by: offset), data.count - offset)
                if written < 0 {
                    if errno == EINTR { continue }
                    throw SpacesError.ioError("http write failed: \(Self.posixMessage(errno))")
                }
                if written == 0 {
                    throw SpacesError.ioError("http write returned 0")
                }
                offset += written
            }
        }
    }

    #if canImport(Darwin)
    private static let streamSocketType: Int32 = SOCK_STREAM
    #else
    private static let streamSocketType: Int32 = Int32(SOCK_STREAM.rawValue)
    #endif

    private static func posixMessage(_ code: Int32) -> String {
        String(cString: strerror(code))
    }
}
