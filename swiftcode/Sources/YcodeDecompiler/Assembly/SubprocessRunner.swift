import Foundation
#if canImport(Subprocess)
import Subprocess
#if canImport(System)
import System
#elseif canImport(SystemPackage)
import SystemPackage
#endif

public struct SwiftSubprocessRunner: ProcessRunner {
    public init() {}

    public func run(executable: String, arguments: [String], environment: [String: String]?,
                    currentDirectory: URL?) throws -> ProcessResult {
        final class Accumulator: @unchecked Sendable {
            var stdout = Data()
            var stderr = Data()
            let lock = NSLock()

            func appendStdout(_ data: Data) {
                lock.lock()
                defer { lock.unlock() }
                stdout.append(data)
            }

            func appendStderr(_ data: Data) {
                lock.lock()
                defer { lock.unlock() }
                stderr.append(data)
            }
        }

        let accumulator = Accumulator()
        let semaphore = DispatchSemaphore(value: 0)
        let box = ResultBox()
        let task = Task {
            do {
                let code = try await runStreaming(
                    executable: executable, arguments: arguments, environment: environment,
                    currentDirectory: currentDirectory,
                    onStdout: { accumulator.appendStdout($0) },
                    onStderr: { accumulator.appendStderr($0) })
                box.set(.success(code))
            } catch {
                box.set(.failure(error))
            }
            semaphore.signal()
        }
        let trackingID = SwiftSubprocessRunner.track(task)
        semaphore.wait()
        SwiftSubprocessRunner.untrack(trackingID)
        switch box.get() {
        case .success(let code):
            return ProcessResult(status: code, stdout: accumulator.stdout, stderr: accumulator.stderr)
        case .failure(let error):
            throw error
        case .none:
            throw DecompilerError.engineUnavailable("swift-subprocess run finished without a result for \(executable).")
        }
    }

    public func runStreaming(executable: String, arguments: [String], environment: [String: String]?,
                             currentDirectory: URL?,
                             onStdout: @escaping @Sendable (Data) -> Void,
                             onStderr: @escaping @Sendable (Data) -> Void) async throws -> Int32 {
        var merged = ProcessInfo.processInfo.environment
        if let environment {
            merged.merge(environment) { _, new in new }
        }
        let subprocessEnvironment = Environment.inherit.updating(
            Dictionary(uniqueKeysWithValues: merged.map { (Environment.Key(stringLiteral: $0.key), Optional($0.value)) }))
        let configuration = Configuration(
            executable: .path(FilePath(executable)),
            arguments: Arguments(arguments),
            environment: subprocessEnvironment,
            workingDirectory: currentDirectory.map { FilePath($0.path) }
        )
        let result = try await Subprocess.run(
            configuration,
            input: .none,
            output: .sequence,
            error: .sequence
        ) { execution in
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    for try await chunk in execution.standardOutput {
                        onStdout(chunk.withUnsafeBytes { Data($0) })
                    }
                }
                group.addTask {
                    for try await chunk in execution.standardError {
                        onStderr(chunk.withUnsafeBytes { Data($0) })
                    }
                }
                try await group.waitForAll()
            }
        }
        switch result.terminationStatus {
        case .exited(let code):
            return code
        case .signaled(let signal):
            return 128 + signal
        }
    }

    public static func cancelAllRunning() {
        Tracker.shared.cancelAll()
    }

    private static func track(_ task: Task<Void, Never>) -> UUID {
        Tracker.shared.add(task)
    }

    private static func untrack(_ id: UUID) {
        Tracker.shared.remove(id)
    }

    private final class ResultBox: @unchecked Sendable {
        var result: Result<Int32, Error>?
        let lock = NSLock()

        func set(_ value: Result<Int32, Error>) {
            lock.lock()
            defer { lock.unlock() }
            result = value
        }

        func get() -> Result<Int32, Error>? {
            lock.lock()
            defer { lock.unlock() }
            return result
        }
    }

    private final class Tracker: @unchecked Sendable {
        static let shared = Tracker()
        var tasks: [UUID: Task<Void, Never>] = [:]
        let lock = NSLock()

        func add(_ task: Task<Void, Never>) -> UUID {
            let id = UUID()
            lock.lock()
            defer { lock.unlock() }
            tasks[id] = task
            return id
        }

        func remove(_ id: UUID) {
            lock.lock()
            defer { lock.unlock() }
            tasks.removeValue(forKey: id)
        }

        func cancelAll() {
            lock.lock()
            let current = Array(tasks.values)
            lock.unlock()
            for task in current {
                task.cancel()
            }
        }
    }
}

#endif
