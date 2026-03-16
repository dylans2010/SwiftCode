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

        // 0. Repository Scan - provide codebase awareness
        log("Scanning repository structure...")
        let fileList = try await ListFilesTool.shared.getFileList(at: request.projectPath.isEmpty ? nil : request.projectPath)
        log("Repository scan complete. Found \(fileList.count) files.")

        // 1. Planning
        log("Generating execution plan...")
        state.plan = try await TaskPlanner.shared.generatePlan(
            for: request.task,
            contextFiles: request.contextFiles,
            availableFiles: fileList
        )
        log("Plan generated with \(state.plan.count) steps.")

        // 2. Execution Loop
        for i in 0..<state.plan.count {
            state.currentStepIndex = i
            state.plan[i].status = .running
            log("Executing step \(i + 1): \(state.plan[i].description)")

            do {
                try await executeStep(state.plan[i], stepIndex: i)
                state.plan[i].status = .completed
            } catch {
                state.plan[i].status = .failed
                log("Step \(i + 1) failed: \(error.localizedDescription)")
                throw error
            }
        }

        state.status = .completed
        log("Task completed successfully.")

        let finalOutput = buildFinalOutput()

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

    private func executeStep(_ step: AgentPlanStep, stepIndex: Int) async throws {
        // Build a more structured prompt with available tools
        let availableTools = buildToolList()

        let systemPrompt = """
        You are an autonomous software development agent executing a task step by step.
        You have access to a project codebase and can use various tools to complete your objectives.

        Your goal is to complete the current step efficiently and accurately.
        """

        let prompt = """
        Current Task: \(request.task)
        Current Step (\(stepIndex + 1)): \(step.description)

        Available Tools:
        \(availableTools)

        Context Files: \(request.contextFiles.isEmpty ? "None" : request.contextFiles.joined(separator: ", "))

        Please analyze the step and decide which tool(s) to use.
        Respond with a JSON array of tool calls in this format:
        [
          {
            "tool": "tool_name",
            "parameters": {
              "param1": "value1",
              "param2": "value2"
            }
          }
        ]

        If no tools are needed for this step, return an empty array: []
        """

        let response = try await LLMService.shared.generateResponse(prompt: prompt, useContext: true)
        log("Agent response for step \(stepIndex + 1): \(response)")

        // Parse and execute tool calls
        try await parseAndExecuteToolCalls(response)
    }

    private func buildToolList() -> String {
        let coreTools = ["list_files", "read_file", "write_file", "create_file", "delete_file"]
        return coreTools.map { "- \($0)" }.joined(separator: "\n")
    }

    private func parseAndExecuteToolCalls(_ response: String) async throws {
        // Clean up response to extract JSON
        let cleaned = response
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8),
              let toolCalls = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            // Fallback to simple parsing
            try await fallbackToolExecution(response)
            return
        }

        for call in toolCalls {
            guard let toolName = call["tool"] as? String,
                  let parameters = call["parameters"] as? [String: Any] else {
                continue
            }

            log("Executing tool: \(toolName)")
            do {
                let result = try await ToolExecutor.shared.execute(toolName: toolName, parameters: parameters)
                log("Tool \(toolName) result: \(result.prefix(200))...")
            } catch {
                log("Tool \(toolName) error: \(error.localizedDescription)")
            }
        }
    }

    private func fallbackToolExecution(_ response: String) async throws {
        // Simple heuristic-based parsing as fallback
        let lowercased = response.lowercased()

        if lowercased.contains("list_files") || lowercased.contains("scan") {
            _ = try await ToolExecutor.shared.execute(toolName: "list_files", parameters: [:])
        }

        if lowercased.contains("read_file") && !request.contextFiles.isEmpty {
            if let path = request.contextFiles.first {
                _ = try await ToolExecutor.shared.execute(toolName: "read_file", parameters: ["path": path])
            }
        }
    }

    private func buildFinalOutput() -> String {
        var output = "Agent completed the task: \(request.task)\n\n"

        if !CodePatchEngine.shared.pendingPatches.isEmpty {
            output += "Generated \(CodePatchEngine.shared.pendingPatches.count) code patches:\n"
            for patch in CodePatchEngine.shared.pendingPatches {
                output += "  - \(patch.filePath)\n"
            }
        } else {
            output += "No code changes generated.\n"
        }

        output += "\nExecution completed successfully."
        return output
    }
}
