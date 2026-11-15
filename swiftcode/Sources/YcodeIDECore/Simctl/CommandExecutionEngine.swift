import Foundation
import os
import YcodeDeviceModel

public actor CommandExecutionEngine {
    public static let shared = CommandExecutionEngine()

    private var executionHistory: [CommandExecutionRecord] = []
    private let historyLimit = 20

    private init() {}

    public func getHistory() -> [CommandExecutionRecord] {
        executionHistory
    }

    private func appendToHistory(_ record: CommandExecutionRecord) {
        executionHistory.insert(record, at: 0)
        if executionHistory.count > historyLimit {
            executionHistory.removeLast()
        }
    }

    public func execute(_ spec: CommandSpec) async -> CommandExecutionRecord {
        let startedAt = Date()
        let recordID = UUID()
        Logger.process.debug("Starting execution of command: \(spec.executableURL.path) \(spec.arguments.joined(separator: " "))")

        #if !os(macOS)
        let record = CommandExecutionRecord(
            id: recordID,
            command: spec,
            stdout: Data(),
            stderr: "simctl requires macOS with Xcode installed.".data(using: .utf8) ?? Data(),
            exitCode: -1,
            duration: .zero,
            startedAt: startedAt,
            outcome: .launchFailed(reason: "simctl requires macOS with Xcode installed")
        )
        appendToHistory(record)
        return record
        #else

        guard FileManager.default.fileExists(atPath: spec.executableURL.path) else {
            let record = CommandExecutionRecord(
                id: recordID,
                command: spec,
                stdout: Data(),
                stderr: "Executable not found at path: \(spec.executableURL.path)".data(using: .utf8) ?? Data(),
                exitCode: -1,
                duration: .zero,
                startedAt: startedAt,
                outcome: .launchFailed(reason: "Executable not found")
            )
            appendToHistory(record)
            Logger.process.error("Command launch failed: Executable not found at \(spec.executableURL.path)")
            return record
        }

        var currentAttempt = 0
        let maxAttempts: Int = {
            if case .standard(let maxRetries, _) = spec.retryPolicy {
                return maxRetries + 1
            }
            return 1
        }()

        var lastRecord: CommandExecutionRecord?

        while currentAttempt < maxAttempts {
            if currentAttempt > 0 {
                if case .standard(_, let backoffs) = spec.retryPolicy, currentAttempt - 1 < backoffs.count {
                    let backoff = backoffs[currentAttempt - 1]
                    try? await Task.sleep(for: backoff)
                }
                Logger.process.info("Retrying command: \(spec.executableURL.path) (attempt \(currentAttempt + 1))")
            }

            let attemptRecord = await runSingleProcessExecution(spec: spec, recordID: recordID, startedAt: startedAt)
            lastRecord = attemptRecord

            switch attemptRecord.outcome {
            case .success, .nonZeroExit:
                appendToHistory(attemptRecord)
                return attemptRecord
            case .timedOut, .launchFailed:
                currentAttempt += 1
            case .cancelled:
                appendToHistory(attemptRecord)
                return attemptRecord
            }
        }

        let finalRecord = lastRecord ?? CommandExecutionRecord(
            id: recordID,
            command: spec,
            stdout: Data(),
            stderr: "All retries failed".data(using: .utf8) ?? Data(),
            exitCode: -1,
            duration: .zero,
            startedAt: startedAt,
            outcome: .launchFailed(reason: "All retries failed")
        )
        appendToHistory(finalRecord)
        return finalRecord
        #endif
    }

    private func runSingleProcessExecution(spec: CommandSpec, recordID: UUID, startedAt: Date) async -> CommandExecutionRecord {
        let timeoutSeconds = Double(spec.timeout.components.seconds) + Double(spec.timeout.components.attoseconds) / 1_000_000_000_000_000_000
        do {
            let result = try await DeviceConnectProcessRunner.shared.run(
                executableURL: spec.executableURL,
                arguments: spec.arguments,
                timeout: timeoutSeconds
            )
            let duration = Date().timeIntervalSince(startedAt)
            let outcome: CommandOutcome = (result.exitCode == 0) ? .success : .nonZeroExit(code: result.exitCode)
            return CommandExecutionRecord(
                id: recordID,
                command: spec,
                stdout: result.stdout.data(using: .utf8) ?? Data(),
                stderr: result.stderr.data(using: .utf8) ?? Data(),
                exitCode: result.exitCode,
                duration: .seconds(duration),
                startedAt: startedAt,
                outcome: outcome
            )
        } catch {
            let duration = Date().timeIntervalSince(startedAt)
            let isTimeout: Bool
            if let processError = error as? DeviceConnectProcessError, case .timedOut = processError {
                isTimeout = true
            } else {
                isTimeout = false
            }
            return CommandExecutionRecord(
                id: recordID,
                command: spec,
                stdout: Data(),
                stderr: error.localizedDescription.data(using: .utf8) ?? Data(),
                exitCode: -1,
                duration: .seconds(duration),
                startedAt: startedAt,
                outcome: isTimeout ? .timedOut : .launchFailed(reason: error.localizedDescription)
            )
        }
    }
}
