import Foundation
import YcodeSubprocess

public struct ProcessResult: Sendable {
    public var status: Int32
    public var stdout: Data
    public var stderr: Data
    public var stdoutText: String { String(decoding: stdout, as: UTF8.self) }
    public var stderrText: String { String(decoding: stderr, as: UTF8.self) }

    public init(status: Int32, stdout: Data, stderr: Data) {
        self.status = status
        self.stdout = stdout
        self.stderr = stderr
    }
}

public protocol ProcessRunner: Sendable {
    func run(executable: String, arguments: [String], environment: [String: String]?, currentDirectory: URL?) throws -> ProcessResult
}

public struct SubprocessProcessRunner: ProcessRunner {
    public init() {}

    public func run(executable: String, arguments: [String], environment: [String: String]?, currentDirectory: URL?) throws -> ProcessResult {
        var merged = ProcessInfo.processInfo.environment
        if let environment {
            merged.merge(environment) { _, new in new }
        }
        let output = try Subprocess.run(executable, arguments, environment: merged,
                                        currentDirectory: currentDirectory, captureStderr: true)
        return ProcessResult(status: output.status, stdout: output.stdout, stderr: output.stderr)
    }
}

public enum ProcessRunnerRegistry {
    private final class Holder: @unchecked Sendable {
        var runner: any ProcessRunner = SubprocessProcessRunner()
        let lock = NSLock()
    }

    private static let holder = Holder()

    public static var shared: any ProcessRunner {
        holder.lock.lock()
        defer { holder.lock.unlock() }
        return holder.runner
    }

    public static func register(_ runner: any ProcessRunner) {
        holder.lock.lock()
        defer { holder.lock.unlock() }
        holder.runner = runner
    }
}
