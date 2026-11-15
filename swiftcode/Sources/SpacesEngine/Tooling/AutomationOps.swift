import Foundation

public struct AutomationOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public enum AutomationEvent: String, Codable, Sendable, CaseIterable {
        case postCommit = "post-commit"
        case postMerge = "post-merge"
        case postCheckout = "post-checkout"
        case postPush = "post-push"
    }

    public struct Pipeline: Codable, Sendable, Equatable {
        public var id: String
        public var event: AutomationEvent
        public var command: String
        public var enabled: Bool
        public var on: [String]

        public init(id: String, event: AutomationEvent, command: String, enabled: Bool = false,
                    on: [String] = []) {
            self.id = id
            self.event = event
            self.command = command
            self.enabled = enabled
            self.on = on
        }
    }

    public struct AutomationConfig: Codable, Sendable {
        public var pipelines: [Pipeline]
        public var allowlistedCommands: [String]

        public init(pipelines: [Pipeline] = [], allowlistedCommands: [String] = []) {
            self.pipelines = pipelines
            self.allowlistedCommands = allowlistedCommands
        }
    }

    public enum RunStatus: String, Codable, Sendable {
        case executed
        case skipped
        case failed
    }

    public struct AutomationRunResult: Codable, Sendable, Equatable {
        public var pipelineId: String
        public var event: AutomationEvent
        public var command: String
        public var status: RunStatus
        public var reason: String
        public var exitCode: Int32?
        public var stdout: String
        public var stderr: String
        public var durationMs: Int64

        public init(pipelineId: String, event: AutomationEvent, command: String, status: RunStatus, reason: String, exitCode: Int32? = nil, stdout: String = "", stderr: String = "", durationMs: Int64 = 0) {
            self.pipelineId = pipelineId
            self.event = event
            self.command = command
            self.status = status
            self.reason = reason
            self.exitCode = exitCode
            self.stdout = stdout
            self.stderr = stderr
            self.durationMs = durationMs
        }
    }

    public func automationPipelines() throws -> [Pipeline] {
        let config: AutomationConfig? = try ToolingStorage.readJSON(repo: repo, relativePath: "tooling/automation.json")
        return config?.pipelines ?? []
    }

    public func setPipelines(_ pipelines: [Pipeline], allowlistedCommands: [String]) throws {
        for pipeline in pipelines {
            guard !pipeline.id.isEmpty else { throw SpacesError.invalidArgument("pipeline id must not be empty") }
            guard !pipeline.command.isEmpty else { throw SpacesError.invalidArgument("pipeline command must not be empty") }
        }
        let config = AutomationConfig(pipelines: pipelines, allowlistedCommands: allowlistedCommands)
        try repo.withLock {
            try ToolingStorage.atomicWriteJSON(repo: repo, relativePath: "tooling/automation.json", value: config)
        }
    }

    public static func triggerName(for event: AutomationEvent) -> String {
        switch event {
        case .postCommit: return "commit"
        case .postMerge: return "merge"
        case .postPush: return "push"
        case .postCheckout: return "checkout"
        }
    }

    public func runAutomation(event: AutomationEvent) throws -> [AutomationRunResult] {
        let config: AutomationConfig? = try ToolingStorage.readJSON(repo: repo, relativePath: "tooling/automation.json")
        guard let config else { return [] }
        let trigger = Self.triggerName(for: event)
        var results: [AutomationRunResult] = []
        for pipeline in config.pipelines where pipeline.event == event || pipeline.on.contains(trigger) {
            if !pipeline.enabled {
                results.append(AutomationRunResult(pipelineId: pipeline.id, event: event, command: pipeline.command, status: .skipped, reason: "pipeline is disabled"))
                continue
            }
            if !config.allowlistedCommands.contains(pipeline.command) {
                results.append(AutomationRunResult(pipelineId: pipeline.id, event: event, command: pipeline.command, status: .skipped, reason: "command is not allowlisted"))
                continue
            }
            results.append(execute(pipeline: pipeline, event: event))
        }
        return results
    }

    private func execute(pipeline: Pipeline, event: AutomationEvent) -> AutomationRunResult {
        let started = Date()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["sh", "-c", pipeline.command]
        process.currentDirectoryURL = repo.worktreeURL
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        let outBox = DataBox()
        let errBox = DataBox()
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global().async {
            outBox.data = outPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        group.enter()
        DispatchQueue.global().async {
            errBox.data = errPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        do {
            try process.run()
        } catch {
            return AutomationRunResult(pipelineId: pipeline.id, event: event, command: pipeline.command, status: .failed, reason: "failed to launch: " + error.localizedDescription, durationMs: elapsedMs(since: started))
        }
        var timedOut = false
        while process.isRunning {
            if Date().timeIntervalSince(started) > 60 {
                timedOut = true
                process.terminate()
                break
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        process.waitUntilExit()
        group.wait()
        let duration = elapsedMs(since: started)
        let stdout = String(data: outBox.data, encoding: .utf8) ?? ""
        let stderr = String(data: errBox.data, encoding: .utf8) ?? ""
        if timedOut {
            return AutomationRunResult(pipelineId: pipeline.id, event: event, command: pipeline.command, status: .failed, reason: "command timed out after 60 seconds", exitCode: process.terminationStatus, stdout: stdout, stderr: stderr, durationMs: duration)
        }
        if process.terminationStatus == 0 {
            return AutomationRunResult(pipelineId: pipeline.id, event: event, command: pipeline.command, status: .executed, reason: "command completed successfully", exitCode: 0, stdout: stdout, stderr: stderr, durationMs: duration)
        }
        return AutomationRunResult(pipelineId: pipeline.id, event: event, command: pipeline.command, status: .failed, reason: "command exited with status " + String(process.terminationStatus), exitCode: process.terminationStatus, stdout: stdout, stderr: stderr, durationMs: duration)
    }

    private func elapsedMs(since started: Date) -> Int64 {
        let elapsed = Date().timeIntervalSince(started)
        return Int64(ceil(elapsed * 1000))
    }
}

private final class DataBox: @unchecked Sendable {
    var data = Data()
}
