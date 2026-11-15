import Foundation

public struct SshRemoteURL: Sendable, Equatable {
    public var user: String?
    public var host: String
    public var port: Int?
    public var path: String
    public var raw: String

    public init(user: String? = nil, host: String, port: Int? = nil, path: String, raw: String) {
        self.user = user
        self.host = host
        self.port = port
        self.path = path
        self.raw = raw
    }

    public var destination: String {
        if let user, !user.isEmpty {
            return "\(user)@\(host)"
        }
        return host
    }

    public var remoteCommand: String {
        "spaces serve \(SshTransport.shellQuote(path))"
    }

    public static func isSSHURL(_ string: String) -> Bool {
        if string.hasPrefix("ssh://") {
            return true
        }
        return parseScpLike(string) != nil
    }

    public static func parse(_ string: String) throws -> SshRemoteURL {
        if string.hasPrefix("ssh://") {
            guard let components = URLComponents(string: string),
                  let host = components.host, !host.isEmpty else {
                throw SpacesError.invalidArgument("bad ssh remote url: \(spacesSanitizedURLString(string))")
            }
            var path = components.path
            if path.hasPrefix("/") {
                path = String(path.dropFirst())
            }
            guard !path.isEmpty else {
                throw SpacesError.invalidArgument("ssh remote url has no path: \(spacesSanitizedURLString(string))")
            }
            if let port = components.port, !(1...65535).contains(port) {
                throw SpacesError.invalidArgument("bad ssh port in remote url: \(spacesSanitizedURLString(string))")
            }
            let authority = String(string.dropFirst("ssh://".count).prefix(while: { $0 != "/" }))
            let hostPortPart: Substring
            if authority.hasPrefix("[") {
                guard let close = authority.firstIndex(of: "]") else {
                    throw SpacesError.invalidArgument("bad ssh remote url: \(spacesSanitizedURLString(string))")
                }
                hostPortPart = authority[authority.index(after: close)...]
            } else if let at = authority.lastIndex(of: "@") {
                hostPortPart = authority[authority.index(after: at)...]
            } else {
                hostPortPart = authority[...]
            }
            if let colon = hostPortPart.firstIndex(of: ":") {
                let portText = String(hostPortPart[hostPortPart.index(after: colon)...])
                guard let portValue = Int(portText), (1...65535).contains(portValue) else {
                    throw SpacesError.invalidArgument("bad ssh port in remote url: \(spacesSanitizedURLString(string))")
                }
            }
            return SshRemoteURL(user: components.user, host: host, port: components.port,
                                path: path, raw: string)
        }
        if let scp = parseScpLike(string) {
            return scp
        }
        throw SpacesError.invalidArgument("not an ssh remote url: \(spacesSanitizedURLString(string))")
    }

    static func parseScpLike(_ string: String) -> SshRemoteURL? {
        guard let at = string.firstIndex(of: "@") else { return nil }
        let user = String(string[..<at])
        guard !user.isEmpty, !user.contains("/"), !user.contains(":") else { return nil }
        let rest = string[string.index(after: at)...]
        guard let colon = rest.firstIndex(of: ":") else { return nil }
        let host = String(rest[..<colon])
        guard !host.isEmpty, !host.contains("/") else { return nil }
        let path = String(rest[rest.index(after: colon)...])
        guard !path.isEmpty else { return nil }
        return SshRemoteURL(user: user, host: host, port: nil, path: path, raw: string)
    }
}

public struct SshTransport: SpacesTransport {
    public let remoteURL: SshRemoteURL
    public let sshBinaryPath: String?
    public let connectTimeout: TimeInterval
    public let operationTimeout: TimeInterval
    public let remoteCommandOverride: String?

    public init(remoteURL: SshRemoteURL, sshBinaryPath: String? = nil,
                connectTimeout: TimeInterval = 15, operationTimeout: TimeInterval = 30,
                remoteCommandOverride: String? = nil) {
        self.remoteURL = remoteURL
        self.sshBinaryPath = sshBinaryPath
        self.connectTimeout = connectTimeout
        self.operationTimeout = operationTimeout
        self.remoteCommandOverride = remoteCommandOverride
    }

    public static let defaultSearchPaths = ["/usr/bin/ssh", "/opt/homebrew/bin/ssh"]

    public static func locateSshBinary() throws -> String {
        let fileManager = FileManager.default
        var searched = defaultSearchPaths
        for candidate in defaultSearchPaths {
            if fileManager.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        let pathEnv = ProcessInfo.processInfo.environment["PATH"] ?? ""
        for dir in pathEnv.split(separator: ":").map(String.init) where !dir.isEmpty {
            let candidate = (dir as NSString).appendingPathComponent("ssh")
            searched.append(candidate)
            if fileManager.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        throw SpacesError.remoteError("ssh binary not found; searched: \(searched.joined(separator: ", "))")
    }

    public static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    public static func encodeMessage(_ message: [String: Any]) throws -> Data {
        let body: Data
        do {
            body = try JSONSerialization.data(withJSONObject: message, options: [])
        } catch {
            throw SpacesError.protocolError("cannot encode ssh message: \(error.localizedDescription)")
        }
        var framed = body
        framed.append(10)
        return framed
    }

    public static func decodeMessage(_ data: Data) throws -> [String: Any] {
        guard let object = try? JSONSerialization.jsonObject(with: data, options: []),
              let message = object as? [String: Any] else {
            throw SpacesError.protocolError("invalid JSON message from ssh remote")
        }
        return message
    }

    private func resolveBinary() throws -> String {
        if let override = sshBinaryPath {
            guard FileManager.default.isExecutableFile(atPath: override) else {
                throw SpacesError.remoteError("ssh binary not found at configured path: \(override)")
            }
            return override
        }
        return try Self.locateSshBinary()
    }

    public func connect() throws -> TransportConnection {
        let binary = try resolveBinary()
        var args: [String] = [
            "-T",
            "-o", "BatchMode=yes",
            "-o", "ConnectTimeout=\(Int(connectTimeout))"
        ]
        if let port = remoteURL.port {
            args.append("-p")
            args.append(String(port))
        }
        args.append(remoteURL.destination)
        args.append(remoteCommandOverride ?? remoteURL.remoteCommand)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = args
        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        do {
            try process.run()
        } catch {
            throw SpacesError.remoteError("could not launch ssh (\(binary)): \(error.localizedDescription)")
        }
        return SshConnection(process: process,
                             stdinHandle: stdinPipe.fileHandleForWriting,
                             stdoutHandle: stdoutPipe.fileHandleForReading,
                             stderrHandle: stderrPipe.fileHandleForReading,
                             hostDisplay: remoteURL.destination,
                             operationTimeout: operationTimeout)
    }
}

final class SshLineReader: @unchecked Sendable {
    private let handle: FileHandle
    private let lock = NSLock()
    private var buffer = Data()
    private var lines: [Data] = []
    private var atEOF = false
    private let available = DispatchSemaphore(value: 0)

    init(handle: FileHandle) {
        self.handle = handle
        handle.readabilityHandler = { [weak self] source in
            guard let self else { return }
            let chunk = source.availableData
            self.lock.lock()
            if chunk.isEmpty {
                self.atEOF = true
            } else {
                self.buffer.append(chunk)
                while let newline = self.buffer.firstIndex(of: 10) {
                    self.lines.append(Data(self.buffer.prefix(upTo: newline)))
                    self.buffer.removeFirst(newline + 1)
                }
            }
            self.lock.unlock()
            self.available.signal()
        }
    }

    func nextLine(timeout: TimeInterval) -> Data? {
        let deadline = DispatchTime.now() + timeout
        while true {
            lock.lock()
            if !lines.isEmpty {
                let line = lines.removeFirst()
                lock.unlock()
                return line
            }
            let eof = atEOF
            lock.unlock()
            if eof {
                return nil
            }
            if available.wait(timeout: deadline) == .timedOut {
                return nil
            }
        }
    }

    func stop() {
        handle.readabilityHandler = nil
    }
}

final class SshStderrCollector: @unchecked Sendable {
    private let handle: FileHandle
    private let lock = NSLock()
    private var tail = Data()
    private static let maxBytes = 8192

    init(handle: FileHandle) {
        self.handle = handle
        handle.readabilityHandler = { [weak self] source in
            guard let self else { return }
            let chunk = source.availableData
            guard !chunk.isEmpty else { return }
            self.lock.lock()
            self.tail.append(chunk)
            if self.tail.count > Self.maxBytes {
                self.tail.removeFirst(self.tail.count - Self.maxBytes)
            }
            self.lock.unlock()
        }
    }

    func text() -> String {
        lock.lock()
        defer { lock.unlock() }
        return String(data: tail, encoding: .utf8) ?? ""
    }

    func stop() {
        handle.readabilityHandler = nil
    }
}

final class SshConnection: TransportConnection, @unchecked Sendable {
    private let process: Process
    private let stdinHandle: FileHandle
    private let reader: SshLineReader
    private let stderrCollector: SshStderrCollector
    private let hostDisplay: String
    private let operationTimeout: TimeInterval
    private let stateLock = NSLock()
    private var closed = false
    private let writeQueue = DispatchQueue(label: "dev.swiftcode.spaces.ssh-write")

    init(process: Process, stdinHandle: FileHandle, stdoutHandle: FileHandle,
         stderrHandle: FileHandle, hostDisplay: String, operationTimeout: TimeInterval) {
        self.process = process
        self.stdinHandle = stdinHandle
        self.reader = SshLineReader(handle: stdoutHandle)
        self.stderrCollector = SshStderrCollector(handle: stderrHandle)
        self.hostDisplay = hostDisplay
        self.operationTimeout = operationTimeout
    }

    deinit {
        close()
    }

    private func ensureOpen() throws {
        stateLock.lock()
        let isClosed = closed
        stateLock.unlock()
        if isClosed {
            throw SpacesError.remoteError("ssh connection to \(hostDisplay) is closed")
        }
    }

    private func failure() -> Error {
        let detail = stderrCollector.text().trimmingCharacters(in: .whitespacesAndNewlines)
        if detail.contains("Permission denied") {
            return SpacesError.authenticationRequired(hostDisplay)
        }
        if detail.isEmpty {
            return SpacesError.remoteError("ssh to \(hostDisplay) exited (status \(process.terminationStatus)) with no error output")
        }
        return SpacesError.remoteError("ssh to \(hostDisplay) failed: \(detail)")
    }

    func send(_ message: [String: Any]) throws {
        try ensureOpen()
        let data = try SshTransport.encodeMessage(message)
        let done = DispatchSemaphore(value: 0)
        writeQueue.async {
            self.stdinHandle.write(data)
            done.signal()
        }
        if done.wait(timeout: .now() + operationTimeout) == .timedOut {
            close()
            throw SpacesError.remoteError("timed out writing to ssh (\(hostDisplay)) after \(Int(operationTimeout))s")
        }
        if !process.isRunning {
            throw failure()
        }
    }

    func receive() throws -> [String: Any] {
        try ensureOpen()
        guard let line = reader.nextLine(timeout: operationTimeout) else {
            if !process.isRunning {
                throw failure()
            }
            close()
            throw SpacesError.remoteError("timed out waiting for ssh response from \(hostDisplay) after \(Int(operationTimeout))s")
        }
        return try SshTransport.decodeMessage(line)
    }

    func close() {
        stateLock.lock()
        if closed {
            stateLock.unlock()
            return
        }
        closed = true
        stateLock.unlock()
        reader.stop()
        stderrCollector.stop()
        if process.isRunning {
            process.terminate()
            process.waitUntilExit()
        }
    }
}
