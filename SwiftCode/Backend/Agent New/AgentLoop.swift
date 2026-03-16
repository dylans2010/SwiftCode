import Foundation

@MainActor
final class AgentLoop {
    let request: PluginAgentRequest
    let state: AgentExecutionState

    init(request: PluginAgentRequest, state: AgentExecutionState) {
        self.request = request
        self.state = state
    }

    func run() async throws -> PluginAgentResponse {
        state.reset(task: request.task)
        state.status = .running
        log("Starting agent loop for task: \(request.task)")

        // 1. Planning
        log("Generating execution plan...")
        state.plan = try await TaskPlanner.shared.generatePlan(for: request.task)
        log("Plan generated with \(state.plan.count) steps.")

        // 2. Execution Loop
        for i in 0..<state.plan.count {
            state.currentStepIndex = i
            state.plan[i].status = .running
            log("Executing step \(i + 1): \(state.plan[i].description)")

            try await executeStep(state.plan[i])

            state.plan[i].status = .completed
        }

        state.status = .completed
        log("Task completed successfully.")

        let finalOutput = "Agent completed the task: \(request.task) successfully."

        return PluginAgentResponse(
            success: true,
            output: finalOutput,
            modifiedFiles: CodePatchEngine.shared.pendingPatches.map { $0.filePath },
            logs: state.logs
        )
    }

    private func log(_ message: String) {
        state.addLog(message)
        // Also log to the central AgentLogger so it appears in AgentConsoleView
        AgentLogger.shared.logToolCall(
            name: "AgentLoop",
            source: .core,
            arguments: ["message": message],
            duration: 0
        )
    }

    private func executeStep(_ step: AgentPlanStep) async throws {
        let prompt = """
        You are an autonomous agent. Given the current step: "\(step.description)", decide which tool to call or what action to take.
        Available context: \(request.task)

        If you need to read a file, suggest `read_file(path: String)`.
        If you need to list files, suggest `list_files(path: String)`.
        If you need to write code, suggest `write_file(path: String, content: String)`.

        Respond with the tool name and arguments.
        """

        let response = try await LLMService.shared.generateResponse(prompt: prompt, useContext: true)
        log("Agent decision: \(response)")

        // Simple heuristic parser for tool calls in this implementation
        if response.contains("list_files") {
            _ = try await ToolExecutor.shared.execute(toolName: "list_files", parameters: ["path": "."])
        } else if response.contains("read_file") {
            if let path = request.contextFiles.first {
                _ = try await ToolExecutor.shared.execute(toolName: "read_file", parameters: ["path": path])
            }
        }

        // Simulate some processing time
        try await Task.sleep(nanoseconds: 500_000_000)
    }
}
