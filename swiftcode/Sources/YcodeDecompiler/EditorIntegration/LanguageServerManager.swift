import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

public enum LanguageServerStatus: Sendable {
    case notStarted
    case running(processIdentifier: Int32)
    case stopped(exitCode: Int32)
    case restarting(attempt: Int, maxAttempts: Int)
    case failed(reason: String, installGuidance: String)
    case unavailable(installGuidance: String)

    public var isRunning: Bool {
        if case .running = self { return true }
        return false
    }
}

public struct LanguageServerInfo: Sendable {
    public var definition: LanguageServerDefinition
    public var status: LanguageServerStatus
    public var restarts: Int
    public var lastExitCode: Int32?
    public var lastStderrTail: String

    public init(definition: LanguageServerDefinition, status: LanguageServerStatus,
                restarts: Int = 0, lastExitCode: Int32? = nil, lastStderrTail: String = "") {
        self.definition = definition
        self.status = status
        self.restarts = restarts
        self.lastExitCode = lastExitCode
        self.lastStderrTail = lastStderrTail
    }
}

public actor LanguageServerManager {
    public static let shared = LanguageServerManager()

    public let maxRestarts: Int
    public let restartBaseDelaySeconds: Double

    private final class RunningServer: @unchecked Sendable {
        var process: Process
        var stderrData = Data()
        let lock = NSLock()
        var stopRequested = false

        init(process: Process) {
            self.process = process
        }

        func appendStderr(_ data: Data) {
            lock.lock()
            defer { lock.unlock() }
            stderrData.append(data)
            if stderrData.count > 8192 {
                stderrData.removeFirst(stderrData.count - 8192)
            }
        }

        var stderrTail: String {
            lock.lock()
            defer { lock.unlock() }
            return String(decoding: stderrData, as: UTF8.self)
        }
    }

    private struct Entry {
        var definition: LanguageServerDefinition
        var binaryPath: String
        var workingDirectory: URL?
        var server: RunningServer?
        var restarts: Int
        var status: LanguageServerStatus
        var lastExitCode: Int32?
    }

    private var entries: [String: Entry] = [:]
    private var onStatusChange: (@Sendable (LanguageServerInfo) -> Void)?

    public init(maxRestarts: Int = 3, restartBaseDelaySeconds: Double = 1.0) {
        self.maxRestarts = maxRestarts
        self.restartBaseDelaySeconds = restartBaseDelaySeconds
    }

    public func setStatusChangeHandler(_ handler: (@Sendable (LanguageServerInfo) -> Void)?) {
        onStatusChange = handler
    }

    public func startServer(for definition: LanguageServerDefinition,
                            workingDirectory: URL? = nil) async -> LanguageServerStatus {
        if let existing = entries[definition.languageID],
           case .running = existing.status {
            return existing.status
        }
        guard let binaryPath = LanguageServerDefinitions.locateBinary(for: definition) else {
            let status = LanguageServerStatus.unavailable(installGuidance: definition.installGuidance)
            entries[definition.languageID] = Entry(definition: definition, binaryPath: "",
                                                   workingDirectory: workingDirectory, server: nil,
                                                   restarts: 0, status: status, lastExitCode: nil)
            publish(definition: definition, status: status, restarts: 0, lastStderrTail: "")
            return status
        }
        entries[definition.languageID] = Entry(definition: definition, binaryPath: binaryPath,
                                               workingDirectory: workingDirectory, server: nil,
                                               restarts: 0, status: .notStarted, lastExitCode: nil)
        return await launch(definition: definition, binaryPath: binaryPath,
                            workingDirectory: workingDirectory, restarts: 0)
    }

    public func startServer(for language: SourceLanguage, workingDirectory: URL? = nil) async -> LanguageServerStatus {
        guard let definition = LanguageServerDefinitions.definition(for: language) else {
            return .unavailable(installGuidance: "No language server is defined for \(language.displayName).")
        }
        return await startServer(for: definition, workingDirectory: workingDirectory)
    }

    public func stopServer(languageID: String) {
        guard var entry = entries[languageID] else { return }
        guard let server = entry.server else {
            entry.status = .stopped(exitCode: 0)
            entries[languageID] = entry
            publish(definition: entry.definition, status: entry.status, restarts: entry.restarts,
                    lastStderrTail: "")
            return
        }
        server.stopRequested = true
        server.process.terminate()
        let processIdentifier = server.process.processIdentifier
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard let self else { return }
            await self.forceKillIfCurrent(languageID: languageID, processIdentifier: processIdentifier)
        }
    }

    private func forceKillIfCurrent(languageID: String, processIdentifier: Int32) {
        guard let server = entries[languageID]?.server else { return }
        guard server.process.processIdentifier == processIdentifier else { return }
        kill(processIdentifier, SIGKILL)
    }

    public func stopAll() {
        for languageID in entries.keys {
            stopServer(languageID: languageID)
        }
    }

    public func status(for languageID: String) -> LanguageServerStatus {
        entries[languageID]?.status ?? .notStarted
    }

    public func info(for languageID: String) -> LanguageServerInfo? {
        guard let entry = entries[languageID] else { return nil }
        return LanguageServerInfo(definition: entry.definition, status: entry.status,
                                  restarts: entry.restarts,
                                  lastExitCode: entry.lastExitCode,
                                  lastStderrTail: entry.server?.stderrTail ?? "")
    }

    public func runningServers() -> [LanguageServerInfo] {
        entries.values.filter { $0.status.isRunning }.map {
            LanguageServerInfo(definition: $0.definition, status: $0.status, restarts: $0.restarts,
                               lastStderrTail: $0.server?.stderrTail ?? "")
        }
    }

    private func launch(definition: LanguageServerDefinition, binaryPath: String,
                        workingDirectory: URL?, restarts: Int) async -> LanguageServerStatus {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = definition.arguments
        if let workingDirectory {
            process.currentDirectoryURL = workingDirectory
        }
        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        let running = RunningServer(process: process)
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty {
                running.appendStderr(data)
            }
        }
        do {
            try process.run()
        } catch {
            let status = LanguageServerStatus.failed(
                reason: "Failed to launch \(definition.displayName) (\(binaryPath)): \(error.localizedDescription)",
                installGuidance: definition.installGuidance)
            if var entry = entries[definition.languageID] {
                entry.status = status
                entries[definition.languageID] = entry
            }
            publish(definition: definition, status: status, restarts: restarts, lastStderrTail: "")
            return status
        }
        let status = LanguageServerStatus.running(processIdentifier: process.processIdentifier)
        if var entry = entries[definition.languageID] {
            entry.server = running
            entry.status = status
            entries[definition.languageID] = entry
        }
        publish(definition: definition, status: status, restarts: restarts, lastStderrTail: "")
        let languageID = definition.languageID
        let processIdentifier = process.processIdentifier
        Task { [weak self] in
            let exitCode = await Self.waitForExit(processIdentifier: processIdentifier)
            guard let self else { return }
            await self.handleExit(languageID: languageID, processIdentifier: processIdentifier,
                                 exitCode: exitCode)
        }
        return status
    }

    private static func waitForExit(processIdentifier: Int32) async -> Int32? {
        while true {
            var status: Int32 = 0
            let result = waitpid(processIdentifier, &status, WNOHANG)
            if result == processIdentifier {
                if (status & 0x7f) == 0 {
                    return (status >> 8) & 0xff
                }
                return 128 + (status & 0x7f)
            }
            if result == -1 {
                return nil
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    private func handleExit(languageID: String, processIdentifier: Int32, exitCode: Int32?) async {
        guard var entry = entries[languageID] else { return }
        guard let server = entry.server else { return }
        guard server.process.processIdentifier == processIdentifier else { return }
        let code = exitCode ?? 0
        let stderrTail = server.stderrTail
        let wasStopRequested = server.stopRequested
        entry.server = nil
        entry.lastExitCode = code
        if wasStopRequested {
            entry.status = .stopped(exitCode: code)
            entries[languageID] = entry
            publish(definition: entry.definition, status: entry.status, restarts: entry.restarts,
                    lastStderrTail: stderrTail)
            return
        }
        if entry.restarts < maxRestarts {
            entry.restarts += 1
            entry.status = .restarting(attempt: entry.restarts, maxAttempts: maxRestarts)
            entries[languageID] = entry
            publish(definition: entry.definition, status: entry.status, restarts: entry.restarts,
                    lastStderrTail: stderrTail)
            let delay = restartBaseDelaySeconds * Double(1 << (entry.restarts - 1))
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard let current = entries[languageID], !current.status.isRunning else { return }
            if case .restarting = current.status {
                _ = await launch(definition: current.definition, binaryPath: current.binaryPath,
                                 workingDirectory: current.workingDirectory, restarts: current.restarts)
            }
            return
        }
        let status = LanguageServerStatus.failed(
            reason: "\(entry.definition.displayName) exited with status \(code) \(maxRestarts + 1) times and was not restarted again.",
            installGuidance: entry.definition.installGuidance)
        entry.status = status
        entries[languageID] = entry
        publish(definition: entry.definition, status: status, restarts: entry.restarts,
                lastStderrTail: stderrTail)
    }

    private func publish(definition: LanguageServerDefinition, status: LanguageServerStatus,
                         restarts: Int, lastStderrTail: String) {
        guard let handler = onStatusChange else { return }
        let info = LanguageServerInfo(definition: definition, status: status, restarts: restarts,
                                      lastStderrTail: lastStderrTail)
        Task { handler(info) }
    }
}
