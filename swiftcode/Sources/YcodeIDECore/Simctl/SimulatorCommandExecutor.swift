import Foundation
import os
import YcodeDeviceModel

public actor SimulatorCommandExecutor {
    private let logger = Logger(subsystem: "com.swiftcode.simulator", category: "CommandExecutor")
    public init() {}

    public struct ExecutionResult: Sendable {
        public let exitCode: Int32
        public let output: String
        public let errorOutput: String
        public let duration: TimeInterval
    }

    public func execute(_ command: SimulatorCommand) async throws -> ExecutionResult {
        logger.info("[BEGIN] Executing command '\(command.name)': \(command.executable) \(command.arguments.joined(separator: " "))")
        let startTime = Date()

        let fm = FileManager.default
        let hasExecutable = fm.fileExists(atPath: command.executable)

        guard hasExecutable else {
            logger.error("[FAILED] Executable not found at '\(command.executable)'")
            throw SimulatorError.executionFailed(
                command: command.name, exitCode: -1,
                output: "Executable not found at '\(command.executable)'. simctl requires macOS with Xcode installed.")
        }

        do {
            let result = try await DeviceConnectProcessRunner.shared.run(
                executableURL: URL(fileURLWithPath: command.executable),
                arguments: command.arguments,
                timeout: command.timeout
            )
            let duration = Date().timeIntervalSince(startTime)
            logger.info("[END] Command '\(command.name)' exited with \(result.exitCode) in \(duration)s")
            return ExecutionResult(exitCode: result.exitCode, output: result.stdout, errorOutput: result.stderr, duration: duration)
        } catch let error as DeviceConnectProcessError {
            let duration = Date().timeIntervalSince(startTime)
            logger.error("[FAILED] Command '\(command.name)' failed after \(duration)s: \(error.localizedDescription)")
            if case .timedOut = error {
                throw SimulatorError.bootTimeout(udid: command.name)
            }
            throw SimulatorError.simctlFailed(reason: error.localizedDescription)
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.error("[FAILED] Command '\(command.name)' failed after \(duration)s: \(error.localizedDescription)")
            throw SimulatorError.simctlFailed(reason: error.localizedDescription)
        }
    }
}
