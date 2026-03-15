import SwiftUI
import Foundation

// MARK: - Agent Task Status

enum AgentTaskStatus: String {
    case pending = "Pending"
    case running = "Running"
    case completed = "Done"
    case failed = "Failed"

    var color: Color {
        switch self {
        case .pending:   return .gray
        case .running:   return .yellow
        case .completed: return .green
        case .failed:    return .red
        }
    }

    var icon: String {
        switch self {
        case .pending:   return "circle"
        case .running:   return "arrow.clockwise.circle"
        case .completed: return "checkmark.circle.fill"
        case .failed:    return "xmark.circle.fill"
        }
    }
}

// MARK: - Agent Running Status

enum AgentRunningStatus: String {
    case idle      = "Idle"
    case planning  = "Planning"
    case running   = "Running"
    case paused    = "Paused"
    case completed = "Completed"
    case failed    = "Failed"

    var color: Color {
        switch self {
        case .idle:      return .gray
        case .planning:  return .blue
        case .running:   return .green
        case .paused:    return .orange
        case .completed: return .mint
        case .failed:    return .red
        }
    }
}

// MARK: - Agent Execution Mode

enum AgentExecutionMode: String, CaseIterable {
    case assistant = "Assistant"
    case agent     = "Agent"
    case autonomous = "Autonomous"

    var description: String {
        switch self {
        case .assistant: return "Text Suggestions Only"
        case .agent:     return "Tool Calls With Confirmation"
        case .autonomous: return "Fully Automated Execution"
        }
    }

    var icon: String {
        switch self {
        case .assistant:  return "bubble.left.and.bubble.right"
        case .agent:      return "person.badge.gearshape"
        case .autonomous: return "cpu.fill"
        }
    }
}

// MARK: - Agent Data Models

struct AgentTask: Identifiable {
    let id = UUID()
    var title: String
    var status: AgentTaskStatus = .pending
    var detail: String = ""
}

struct AgentPlanStep: Identifiable {
    let id = UUID()
    var stepNumber: Int
    var description: String
    var isActive: Bool = false
    var isCompleted: Bool = false
}

struct AgentThought: Identifiable {
    let id = UUID()
    var content: String
    var timestamp: Date = Date()
}

struct AgentProcessEntry: Identifiable {
    let id = UUID()
    var toolName: String
    var parameters: String
    var result: String = ""
    var status: AgentTaskStatus = .running
    var timestamp: Date = Date()
}

struct AgentLogEntry: Identifiable {
    let id = UUID()
    var message: String
    var level: LogLevel = .info
    var timestamp: Date = Date()

    enum LogLevel {
        case info, success, warning, error

        var color: Color {
            switch self {
            case .info:    return .secondary
            case .success: return .green
            case .warning: return .orange
            case .error:   return .red
            }
        }

        var icon: String {
            switch self {
            case .info:    return "info.circle"
            case .success: return "checkmark.circle"
            case .warning: return "exclamationmark.triangle"
            case .error:   return "xmark.circle"
            }
        }
    }
}

// MARK: - Agent Memory

struct AgentMemory: Codable {
    var projectArchitecture: String = ""
    var importantFiles: [String] = []
    var dependencies: [String] = []
    var codePatterns: [String] = []
    var lastUpdated: Date = Date()
}

@MainActor
final class AgentMemoryStore {
    static let shared = AgentMemoryStore()
    private(set) var memory = AgentMemory()

    private init() { load() }

    private var memoryURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AgentMemory.json")
    }

    func save() {
        memory.lastUpdated = Date()
        if let data = try? JSONEncoder().encode(memory) {
            try? data.write(to: memoryURL)
        }
    }

    func load() {
        guard let data = try? Data(contentsOf: memoryURL),
              let decoded = try? JSONDecoder().decode(AgentMemory.self, from: data) else { return }
        memory = decoded
    }

    func update(
        architecture: String? = nil,
        files: [String]? = nil,
        deps: [String]? = nil,
        patterns: [String]? = nil
    ) {
        if let arch = architecture { memory.projectArchitecture = arch }
        if let f = files { memory.importantFiles = f }
        if let d = deps { memory.dependencies = d }
        if let p = patterns { memory.codePatterns = p }
        save()
    }
}

// MARK: - Agent State

@MainActor
final class AgentState: ObservableObject {
    @Published var tasks: [AgentTask] = []
    @Published var plan: [AgentPlanStep] = []
    @Published var thinking: [AgentThought] = []
    @Published var process: [AgentProcessEntry] = []
    @Published var logs: [AgentLogEntry] = []
    @Published var status: AgentRunningStatus = .idle
    @Published var currentGoal: String = ""
    @Published var streamingThought: String = ""

    func reset() {
        tasks = []
        plan = []
        thinking = []
        process = []
        logs = []
        status = .idle
        streamingThought = ""
    }

    func addLog(_ message: String, level: AgentLogEntry.LogLevel = .info) {
        logs.append(AgentLogEntry(message: message, level: level))
    }

    func addThought(_ content: String) {
        thinking.append(AgentThought(content: content))
    }

    func addProcess(toolName: String, parameters: String) -> UUID {
        let step = AgentProcessEntry(toolName: toolName, parameters: parameters)
        process.append(step)
        return step.id
    }

    func updateProcess(id: UUID, result: String, status: AgentTaskStatus) {
        guard let index = process.firstIndex(where: { $0.id == id }) else { return }
        process[index].result = result
        process[index].status = status
    }

    func updateTaskStatus(at index: Int, status: AgentTaskStatus) {
        guard index < tasks.count else { return }
        tasks[index].status = status
    }
}

// MARK: - Agent Safety Validator

private enum AgentSafetyValidator {
    private static let disallowedSegments = ["../", "//", "/etc", "/usr", "/bin", "/sbin", "/private"]

    static func isPathSafe(_ path: String) -> Bool {
        for segment in disallowedSegments where path.contains(segment) {
            return false
        }
        return true
    }
}

// MARK: - Tool Registry

/// Central registry of tools available to the agent for autonomous execution.
struct ToolRegistry {
    struct RegisteredTool {
        let name: String
        let description: String
        let category: String
    }

    static let tools: [RegisteredTool] = [
        RegisteredTool(name: "read_file", description: "Read the contents of a file", category: "File System"),
        RegisteredTool(name: "write_file", description: "Write content to a file", category: "File System"),
        RegisteredTool(name: "create_file", description: "Create a new file with content", category: "File System"),
        RegisteredTool(name: "delete_file", description: "Delete a file from the project", category: "File System"),
        RegisteredTool(name: "rename_file", description: "Rename a file in the project", category: "File System"),
        RegisteredTool(name: "list_files", description: "List files in a directory", category: "File System"),
        RegisteredTool(name: "search_codebase", description: "Search for text patterns across all project files", category: "Search"),
        RegisteredTool(name: "find_in_project", description: "Find files matching a pattern", category: "Search"),
        RegisteredTool(name: "install_dependency", description: "Install a Swift package dependency", category: "Dependency"),
        RegisteredTool(name: "remove_dependency", description: "Remove a Swift package dependency", category: "Dependency"),
        RegisteredTool(name: "trigger_build", description: "Trigger a project build", category: "Build"),
        RegisteredTool(name: "get_build_status", description: "Get the current build status", category: "Build"),
        RegisteredTool(name: "analyze_code_structure", description: "Analyze the code structure of a file", category: "Analysis"),
        RegisteredTool(name: "get_project_info", description: "Get project metadata and file tree", category: "Project"),
    ]

    static func tool(named name: String) -> RegisteredTool? {
        tools.first { $0.name == name }
    }

    static var availableToolNames: [String] {
        tools.map(\.name)
    }

    /// Format the registered tools for inclusion in the AI system prompt.
    static func formatForPrompt() -> String {
        tools.map { "- \($0.name): \($0.description) [\($0.category)]" }.joined(separator: "\n")
    }
}

// MARK: - Agent Controller

@MainActor
final class AgentController: ObservableObject {
    static let shared = AgentController()

    @Published var state = AgentState()
    @Published var executionMode: AgentExecutionMode = .agent
    @Published var includeProjectContext = true

    private var activeTask: Task<Void, Never>?
    private var conversationHistory: [AIMessage] = []
    private let maxIterations = 20
    private var iterationCount = 0

    private init() {}

    // MARK: - Lifecycle

    func start(goal: String, projectManager: ProjectManager) {
        let currentStatus = state.status
        guard currentStatus == .idle || currentStatus == .completed || currentStatus == .failed else { return }

        state.reset()
        state.currentGoal = goal
        state.status = .planning
        conversationHistory = []
        iterationCount = 0

        state.addLog("Agent Started. Goal: \(goal)")

        activeTask = Task { [weak self] in
            guard let self else { return }
            await self.runExecutionLoop(goal: goal, projectManager: projectManager)
        }
    }

    func stop() {
        activeTask?.cancel()
        activeTask = nil
        state.status = .idle
        state.addLog("Agent Stopped By User.", level: .warning)
    }

    func pause() {
        activeTask?.cancel()
        activeTask = nil
        state.status = .paused
        state.addLog("Agent Paused.", level: .warning)
    }

    func resume(projectManager: ProjectManager) {
        guard state.status == .paused else { return }
        state.status = .running
        state.addLog("Agent Resumed.")
        activeTask = Task { [weak self] in
            guard let self else { return }
            await self.runExecutionLoop(goal: self.state.currentGoal, projectManager: projectManager)
        }
    }

    func clearLogs() {
        state.logs = []
        state.thinking = []
        state.process = []
        state.streamingThought = ""
    }

    // MARK: - Execution Loop

    private func runExecutionLoop(goal: String, projectManager: ProjectManager) async {
        let context = includeProjectContext ? gatherProjectContext(projectManager: projectManager) : ""
        let systemPrompt = buildSystemPrompt(context: context)

        if conversationHistory.isEmpty {
            conversationHistory.append(
                AIMessage(role: "user", content: goal)
            )
        }

        state.status = .planning
        state.addLog("Gathering Project Context…")

        while !Task.isCancelled && iterationCount < maxIterations {
            guard state.status != .paused else { break }
            iterationCount += 1
            state.addLog("Iteration \(iterationCount)/\(maxIterations)")
            state.status = .running

            do {
                var fullResponse = ""

                try await LLMService.shared.streamChat(
                    messages: conversationHistory,
                    model: AppSettings.shared.selectedModel,
                    systemPrompt: systemPrompt
                ) { [weak self] token in
                    guard let self, !Task.isCancelled else { return }
                    await MainActor.run {
                        fullResponse += token
                        self.state.streamingThought += token
                    }
                }

                let finalThought = state.streamingThought
                state.streamingThought = ""

                if !finalThought.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    state.addThought(finalThought)
                }

                conversationHistory.append(
                    AIMessage(role: "assistant", content: fullResponse)
                )

                extractPlan(from: fullResponse)
                syncTasksFromPlan()

                let toolCalls = parseToolCalls(from: fullResponse)

                if toolCalls.isEmpty {
                    state.status = .completed
                    state.addLog("Task Completed Successfully!", level: .success)
                    break
                }

                for call in toolCalls {
                    guard !Task.isCancelled else { break }
                    let resultText = await executeToolCall(call, projectManager: projectManager)
                    conversationHistory.append(
                        AIMessage(role: "tool_result", content: "[\(call.name)] \(resultText)")
                    )
                }

            } catch {
                state.status = .failed
                state.addLog("Error: \(error.localizedDescription)", level: .error)
                break
            }
        }

        if iterationCount >= maxIterations && state.status == .running {
            state.status = .completed
            state.addLog("Maximum Iterations Reached.", level: .warning)
        }
    }

    // MARK: - Tool Execution

    private func executeToolCall(_ call: AgentToolCall, projectManager: ProjectManager) async -> String {
        let paramsDisplay = call.parameters
            .map { "\($0.key): \($0.value)" }
            .joined(separator: ", ")
        let processId = state.addProcess(toolName: call.name, parameters: paramsDisplay)
        state.addLog("Executing: \(call.name)")

        // Safety check on path-like parameters
        for (_, value) in call.parameters {
            if let pathString = value as? String, pathString.hasPrefix("/") {
                if !AgentSafetyValidator.isPathSafe(pathString) {
                    let msg = "Blocked: unsafe path '\(pathString)'"
                    state.updateProcess(id: processId, result: msg, status: .failed)
                    state.addLog(msg, level: .error)
                    return msg
                }
            }
        }

        let result = await AgentToolService.shared.execute(
            toolName: call.name,
            parameters: call.parameters,
            projectManager: projectManager
        )

        let taskStatus: AgentTaskStatus = result.isError ? .failed : .completed
        state.updateProcess(id: processId, result: result.result, status: taskStatus)

        let logLevel: AgentLogEntry.LogLevel = result.isError ? .error : .success
        let preview = String(result.result.prefix(120))
        state.addLog("\(call.name): \(result.isError ? "failed" : "ok") — \(preview)", level: logLevel)

        return result.result
    }

    // MARK: - Response Parsing

    private func parseToolCalls(from response: String) -> [AgentToolCall] {
        var calls: [AgentToolCall] = []
        guard let regex = try? NSRegularExpression(
            pattern: #"<tool_call>\s*(.*?)\s*</tool_call>"#,
            options: .dotMatchesLineSeparators
        ) else { return calls }

        let nsRange = NSRange(response.startIndex..., in: response)
        for match in regex.matches(in: response, range: nsRange) {
            guard let range = Range(match.range(at: 1), in: response) else { continue }
            let json = String(response[range])
            guard let data = json.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let name = obj["name"] as? String else { continue }

            var params: [String: Any] = [:]
            if let p = obj["parameters"] as? [String: Any] { params = p }
            calls.append(AgentToolCall(name: name, parameters: params))
        }
        return calls
    }

    private func extractPlan(from response: String) {
        guard state.plan.isEmpty else { return }
        let lines = response.components(separatedBy: "\n")
        var steps: [AgentPlanStep] = []
        var stepNumber = 1

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let stripped: String?
            if trimmed.lowercased().hasPrefix("step ") {
                stripped = trimmed.replacingOccurrences(
                    of: #"^[Ss]tep\s+\d+[.:]\s*"#, with: "", options: .regularExpression
                )
            } else if let firstChar = trimmed.first, firstChar.isNumber, trimmed.contains(". ") {
                stripped = trimmed.replacingOccurrences(
                    of: #"^\d+\.\s*"#, with: "", options: .regularExpression
                )
            } else {
                stripped = nil
            }

            if let desc = stripped, !desc.isEmpty {
                steps.append(AgentPlanStep(stepNumber: stepNumber, description: desc))
                stepNumber += 1
            }
        }

        if !steps.isEmpty {
            state.plan = steps
        }
    }

    private func syncTasksFromPlan() {
        guard state.tasks.isEmpty, !state.plan.isEmpty else { return }
        state.tasks = state.plan.map { AgentTask(title: $0.description) }
    }

    // MARK: - Context & Prompt

    private func gatherProjectContext(projectManager: ProjectManager) -> String {
        guard let project = projectManager.activeProject else {
            return "No Active Project Open."
        }
        var ctx = "Project: \(project.name)\n"
        ctx += "Created: \(project.createdAt)\n\n"
        ctx += "File Structure:\n"
        ctx += fileTreeString(nodes: project.files, indent: 0)

        let mem = AgentMemoryStore.shared.memory
        if !mem.importantFiles.isEmpty {
            ctx += "\nKey Files: \(mem.importantFiles.joined(separator: ", "))"
        }
        if !mem.dependencies.isEmpty {
            ctx += "\nDependencies: \(mem.dependencies.joined(separator: ", "))"
        }
        return ctx
    }

    private func fileTreeString(nodes: [FileNode], indent: Int) -> String {
        let prefix = String(repeating: "  ", count: indent)
        return nodes.map { node in
            var line = "\(prefix)\(node.name)\n"
            if node.isDirectory {
                line += fileTreeString(nodes: node.children, indent: indent + 1)
            }
            return line
        }.joined()
    }

    private func buildSystemPrompt(context: String) -> String {
        let toolsSection = AgentToolService.buildSystemPrompt()
        let registeredTools = ToolRegistry.formatForPrompt()
        return """
        You are SwiftCode Autonomous Agent — an AI-powered iOS development assistant.

        Execution mode: \(executionMode.rawValue)

        \(toolsSection)

        Registered Tools:
        \(registeredTools)

        Here is your only project context:
        \(context)

        Autonomous Execution Loop:
        1. ANALYZE: Read the project structure and understand the codebase.
        2. PLAN: Create a numbered plan (Step 1: …, Step 2: …).
        3. EXECUTE: Execute one tool at a time using <tool_call> format.
        4. VERIFY: Read tool results and verify correctness before proceeding.
        5. REPEAT: Continue until the task is fully complete.
        6. SUMMARIZE: When done, summarize without further tool calls.

        Instructions:
        1. Start by analysing the goal and writing a numbered plan (Step 1: …, Step 2: …).
        2. Execute one tool at a time using the exact <tool_call> format shown above.
        3. Read tool results before proceeding to the next step.
        4. When the task is fully complete, summarise what was done WITHOUT any further tool calls.
        5. Always include the full plan in every response.
        6. Keep responses concise but complete.
        7. Use the project context to inform your decisions.
        8. If you encounter errors, explain them and suggest solutions.
        9. Never modify files directly - always use the appropriate tool.
        10. For file operations, always specify the full path relative to the project root.
        11. When creating new files, include the full file path.
        12. When editing files, specify the exact line numbers to modify.
        13. For code generation, include the full code block with proper indentation.
        14. If the user justs tells you to build an app without any other details/context, just build a simple app with it's full project setup, full code then reply to the user that the app is ready to run.

        Safety constraints:
        - Never delete the entire project directory.
        - Never access paths outside the project root.
        - Validate all parameters before execution.
        - Confirm destructive operations before proceeding.
        - Always check file existence before operations.
        - Never execute commands that could compromise system security.
        - Always verify paths before file operations.
        """
    }
}

// MARK: - Main Agent Interface View

struct AgentInterfaceView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var projectManager: ProjectManager
    @EnvironmentObject private var settings: AppSettings
    @StateObject private var controller = AgentController.shared

    @State private var goalText: String = ""
    @State private var showTaskSheet      = false
    @State private var showPlanSheet      = false
    @State private var showThinkingSheet  = false
    @State private var showProcessSheet   = false
    @State private var showLogsSheet      = false
    @State private var showModeSheet      = false
    @State private var showSlashCommands = false
    @State private var slashFilter = ""
    @State private var selectedSlashCommand: String?

    private let slashCommands: [(title: String, icon: String, description: String)] = [
        ("start", "play.fill", "Start the agent with this goal"),
        ("pause", "pause.fill", "Pause active execution"),
        ("resume", "playpause.fill", "Resume from paused state"),
        ("stop", "stop.fill", "Stop current execution"),
        ("clear logs", "trash", "Clear execution logs"),
        ("analyze project", "folder", "Analyze this project's structure"),
        ("fix errors", "wrench.and.screwdriver.fill", "Ask the agent to fix current issues"),
    ]

    private var filteredSlashCommands: [(title: String, icon: String, description: String)] {
        guard !slashFilter.isEmpty else { return slashCommands }
        return slashCommands.filter { $0.title.localizedCaseInsensitiveContains(slashFilter) }
    }

    var body: some View {
        ZStack {
            Color(red: 0.07, green: 0.07, blue: 0.09).ignoresSafeArea()

            VStack(spacing: 0) {
                agentHeader
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                Divider().opacity(0.3)

                ScrollView {
                    VStack(spacing: 12) {
                        goalInputSection
                        taskPanel
                        planningPanel
                        thinkingPanel
                        processPanel
                        logsPanel
                    }
                    .padding()
                }

                Divider().opacity(0.3)

                executionControls
                    .padding(.horizontal)
                    .padding(.vertical, 12)
            }
        }
        .sheet(isPresented: $showTaskSheet) {
            TaskDetailSheet(tasks: controller.state.tasks)
        }
        .sheet(isPresented: $showPlanSheet) {
            PlanDetailSheet(plan: controller.state.plan)
        }
        .sheet(isPresented: $showThinkingSheet) {
            ThinkingDetailSheet(thoughts: controller.state.thinking)
        }
        .sheet(isPresented: $showProcessSheet) {
            ProcessDetailSheet(steps: controller.state.process)
        }
        .sheet(isPresented: $showLogsSheet) {
            LogsDetailSheet(logs: controller.state.logs)
        }
        .sheet(isPresented: $showModeSheet) {
            ModeSelectionSheet(selectedMode: $controller.executionMode)
        }
    }

    // MARK: - Header

    private var agentHeader: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text("Agent (Beta)")
                    .font(.headline)
                    .foregroundColor(.white)

                HStack(spacing: 6) {
                    if let project = projectManager.activeProject {
                        Label(project.name, systemImage: "folder.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("No Project Open")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text("·")
                        .foregroundColor(.secondary)
                    Text(controller.executionMode.rawValue)
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text("·")
                        .foregroundColor(.secondary)
                    Text(modelDisplayName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Status badge
            HStack(spacing: 4) {
                Circle()
                    .fill(controller.state.status.color)
                    .frame(width: 8, height: 8)
                Text(controller.state.status.rawValue)
                    .font(.caption)
                    .foregroundColor(controller.state.status.color)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(controller.state.status.color.opacity(0.15))
            .cornerRadius(8)

            // Mode/settings button
            Button { showModeSheet = true } label: {
                Image(systemName: controller.executionMode.icon)
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                    .frame(width: 32, height: 32)
                    .background(Color.blue.opacity(0.15))
                    .cornerRadius(8)
            }
        }
    }

    // MARK: - Goal Input

    private var goalInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Goal")
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            if showSlashCommands && !filteredSlashCommands.isEmpty {
                slashCommandsList
            }

            ZStack(alignment: .topLeading) {
                if goalText.isEmpty {
                    Text("What should Agent build? (type / for commands)")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 10)
                }

                TextEditor(text: $goalText)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .frame(minHeight: 72, maxHeight: 120)
                    .scrollContentBackground(.hidden)
                    .background(.clear)
                    .disabled(
                        controller.state.status == .running ||
                        controller.state.status == .planning
                    )
                    .onChange(of: goalText) { _, newValue in
                        handleGoalInputChange(newValue)
                    }
            }
            .padding(4)
            .background(Color.white.opacity(0.06))
            .cornerRadius(10)
        }
        .padding(12)
        .background(Color.white.opacity(0.03))
        .cornerRadius(12)
    }

    // MARK: - Task Panel

    private var taskPanel: some View {
        AgentPanelView(
            title: "Tasks",
            icon: "checklist",
            count: controller.state.tasks.count,
            onExpand: { showTaskSheet = true }
        ) {
            if controller.state.tasks.isEmpty {
                panelEmptyRow("No Tasks Yet")
            } else {
                ForEach(controller.state.tasks.prefix(5)) { task in
                    taskRow(task)
                }
                if controller.state.tasks.count > 5 {
                    moreRow(controller.state.tasks.count - 5)
                }
            }
        }
    }

    private func taskRow(_ task: AgentTask) -> some View {
        HStack(spacing: 8) {
            Image(systemName: task.status.icon)
                .foregroundColor(task.status.color)
                .font(.system(size: 13))
                .frame(width: 18)

            Text(task.title)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(1)

            Spacer()

            Text(task.status.rawValue)
                .font(.caption2)
                .foregroundColor(task.status.color)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(task.status.color.opacity(0.15))
                .cornerRadius(4)
        }
        .padding(.vertical, 3)
    }

    // MARK: - Planning Panel

    private var planningPanel: some View {
        AgentPanelView(
            title: "Plan",
            icon: "list.number",
            count: controller.state.plan.count,
            onExpand: { showPlanSheet = true }
        ) {
            if controller.state.plan.isEmpty {
                panelEmptyRow("The plan that the agent creates will appear here.")
            } else {
                ForEach(controller.state.plan.prefix(5)) { step in
                    planStepRow(step)
                }
                if controller.state.plan.count > 5 {
                    moreRow(controller.state.plan.count - 5)
                }
            }
        }
    }

    private func planStepRow(_ step: AgentPlanStep) -> some View {
        HStack(spacing: 8) {
            Text("\(step.stepNumber)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.blue)
                .frame(width: 22, height: 22)
                .background(Color.blue.opacity(0.15))
                .cornerRadius(4)

            Text(step.description)
                .font(.system(size: 13))
                .foregroundColor(step.isCompleted ? .secondary : .white.opacity(0.9))
                .lineLimit(1)
                .strikethrough(step.isCompleted)

            Spacer()

            if step.isActive {
                Image(systemName: "arrowtriangle.right.fill")
                    .font(.system(size: 9))
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 3)
    }

    // MARK: - Thinking Panel

    private var thinkingPanel: some View {
        AgentPanelView(
            title: "Thinking",
            icon: "brain",
            count: controller.state.thinking.count,
            onExpand: { showThinkingSheet = true }
        ) {
            if !controller.state.streamingThought.isEmpty {
                streamingView
            } else if controller.state.thinking.isEmpty {
                panelEmptyRow("Reasoning will stream here in real time")
            } else if let latest = controller.state.thinking.last {
                Text(latest.content.prefix(300))
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.75))
                    .lineLimit(5)
            }
        }
    }

    private var streamingView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                ProgressView().scaleEffect(0.7)
                Text("Thinking…")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            Text(controller.state.streamingThought.suffix(400))
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.75))
                .lineLimit(6)
        }
    }

    // MARK: - Process Panel

    private var processPanel: some View {
        AgentPanelView(
            title: "Tools",
            icon: "wrench.and.screwdriver",
            count: controller.state.process.count,
            onExpand: { showProcessSheet = true }
        ) {
            if controller.state.process.isEmpty {
                panelEmptyRow("Tool that the agent will execute will appear here")
            } else {
                let recent = Array(controller.state.process.suffix(3).reversed())
                ForEach(recent) { step in
                    processRow(step)
                }
                if controller.state.process.count > 3 {
                    moreRow(controller.state.process.count - 3)
                }
            }
        }
    }

    private func processRow(_ step: AgentProcessEntry) -> some View {
        HStack(spacing: 8) {
            Image(systemName: step.status.icon)
                .foregroundColor(step.status.color)
                .font(.system(size: 11))
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(step.toolName)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.cyan)
                if !step.parameters.isEmpty {
                    Text(step.parameters)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if !step.result.isEmpty {
                Text(step.result.prefix(25))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 3)
    }

    // MARK: - Logs Panel

    private var logsPanel: some View {
        AgentPanelView(
            title: "Logs",
            icon: "doc.text",
            count: controller.state.logs.count,
            onExpand: { showLogsSheet = true }
        ) {
            if controller.state.logs.isEmpty {
                panelEmptyRow("Execution Logs Will Appear Here")
            } else {
                let recent = Array(controller.state.logs.suffix(5).reversed())
                ForEach(recent) { log in
                    logRow(log)
                }
                if controller.state.logs.count > 5 {
                    moreRow(controller.state.logs.count - 5)
                }
            }
        }
    }

    private func logRow(_ log: AgentLogEntry) -> some View {
        HStack(spacing: 6) {
            Image(systemName: log.level.icon)
                .font(.system(size: 10))
                .foregroundColor(log.level.color)
                .frame(width: 14)

            Text(log.message)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)

            Spacer()

            Text(log.timestamp, style: .time)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Execution Controls

    private var executionControls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                let status = controller.state.status

            if status == .idle || status == .completed || status == .failed {
                Button {
                    let trimmed = goalText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        controller.start(goal: trimmed, projectManager: projectManager)
                    }
                } label: {
                    Label("Start", systemImage: "play.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            goalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? Color.green.opacity(0.35)
                                : Color.green
                        )
                        .cornerRadius(10)
                }
                .disabled(goalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if status == .running || status == .planning {
                Button { controller.pause() } label: {
                    Label("Pause", systemImage: "pause.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.orange)
                        .cornerRadius(10)
                }

                Button { controller.stop() } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.red)
                        .cornerRadius(10)
                }
            }

            if status == .paused {
                Button { controller.resume(projectManager: projectManager) } label: {
                    Label("Resume", systemImage: "play.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .cornerRadius(10)
                }

                Button { controller.stop() } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.red)
                        .cornerRadius(10)
                }
            }

                Button { controller.clearLogs() } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.07))
                        .cornerRadius(10)
                }
            }

            HStack {
                Button {
                    controller.includeProjectContext.toggle()
                } label: {
                    Label(controller.includeProjectContext ? "Context On" : "Context Off",
                          systemImage: controller.includeProjectContext ? "doc.text.fill" : "doc.text")
                    .font(.caption)
                    .foregroundColor(controller.includeProjectContext ? .orange : .secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.07))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Spacer()
            }
        }
    }


    private var modelDisplayName: String {
        if let preset = OpenRouterModel.defaults.first(where: { $0.id == settings.selectedModel }) {
            return preset.name
        }
        return settings.selectedModel
    }

    private var slashCommandsList: some View {
        VStack(spacing: 0) {
            ForEach(filteredSlashCommands, id: \.title) { command in
                Button {
                    applyGoalCommand(command.title)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: command.icon)
                            .font(.caption2)
                            .foregroundColor(selectedSlashCommand == command.title ? .cyan : .blue)
                            .frame(width: 14)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("/\(command.title)")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.white)
                            Text(command.description)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if selectedSlashCommand == command.title {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.cyan)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(selectedSlashCommand == command.title ? Color.cyan.opacity(0.1) : .clear)
                }
                .buttonStyle(.plain)

                if command.title != filteredSlashCommands.last?.title {
                    Divider().opacity(0.2)
                }
            }
        }
        .background(Color.white.opacity(0.06))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.blue.opacity(0.25), lineWidth: 1))
    }

    private func handleGoalInputChange(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("/") {
            slashFilter = String(trimmed.dropFirst())
            showSlashCommands = true
        } else {
            slashFilter = ""
            showSlashCommands = false
            selectedSlashCommand = nil
        }
    }

    private func applyGoalCommand(_ command: String) {
        selectedSlashCommand = command
        showSlashCommands = false
        slashFilter = ""
        let prefix = "/\(command)"

        switch command {
        case "start":
            goalText = prefix
            startIfPossible()
        case "pause":
            goalText = prefix
            if controller.state.status == .running || controller.state.status == .planning {
                controller.pause()
            }
        case "resume":
            goalText = prefix
            if controller.state.status == .paused {
                controller.resume(projectManager: projectManager)
            }
        case "stop":
            goalText = prefix
            if controller.state.status == .running || controller.state.status == .planning || controller.state.status == .paused {
                controller.stop()
            }
        case "clear logs":
            goalText = prefix
            controller.clearLogs()
        case "analyze project":
            goalText = "\(prefix) Analyze this project structure and summarize architecture."
        case "fix errors":
            goalText = "\(prefix) Find and fix errors in the active project."
        default:
            goalText = "\(prefix) "
        }
    }

    private func startIfPossible() {
        let trimmed = goalText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let status = controller.state.status
        guard status == .idle || status == .completed || status == .failed else { return }
        controller.start(goal: trimmed, projectManager: projectManager)
    }

    // MARK: - Helpers

    private func panelEmptyRow(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 8)
    }

    private func moreRow(_ count: Int) -> some View {
        Text("+ \(count) More")
            .font(.caption2)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

// MARK: - Reusable Panel Component

struct AgentPanelView<Content: View>: View {
    let title: String
    let icon: String
    let count: Int
    let onExpand: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))

                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(4)
                }

                Spacer()

                Button { onExpand() } label: {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }

            Divider().opacity(0.2)

            content
        }
        .padding(12)
        .background(Color.white.opacity(0.04))
        .cornerRadius(12)
    }
}

// MARK: - Task Detail Sheet

struct TaskDetailSheet: View {
    let tasks: [AgentTask]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if tasks.isEmpty {
                    ContentUnavailableView(
                        "No Tasks",
                        systemImage: "checklist",
                        description: Text("Tasks will appear once the agent starts.")
                    )
                } else {
                    List(tasks) { task in
                        HStack(spacing: 12) {
                            Image(systemName: task.status.icon)
                                .foregroundColor(task.status.color)
                                .frame(width: 22)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(task.title).font(.system(size: 14))
                                if !task.detail.isEmpty {
                                    Text(task.detail).font(.caption).foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            Text(task.status.rawValue)
                                .font(.caption)
                                .foregroundColor(task.status.color)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(task.status.color.opacity(0.15))
                                .cornerRadius(6)
                        }
                        .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Tasks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Plan Detail Sheet

struct PlanDetailSheet: View {
    let plan: [AgentPlanStep]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if plan.isEmpty {
                    ContentUnavailableView(
                        "No Plan Yet",
                        systemImage: "list.number",
                        description: Text("The agent's plan will appear here.")
                    )
                } else {
                    List(plan) { step in
                        HStack(spacing: 12) {
                            Text("\(step.stepNumber)")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(.blue)
                                .frame(width: 28, height: 28)
                                .background(Color.blue.opacity(0.15))
                                .cornerRadius(6)

                            Text(step.description)
                                .font(.system(size: 14))
                                .strikethrough(step.isCompleted)
                                .foregroundColor(step.isCompleted ? .secondary : .primary)

                            Spacer()

                            if step.isActive {
                                Image(systemName: "arrowtriangle.right.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                        .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Thinking Detail Sheet

struct ThinkingDetailSheet: View {
    let thoughts: [AgentThought]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if thoughts.isEmpty {
                    ContentUnavailableView(
                        "No Thoughts Yet",
                        systemImage: "brain",
                        description: Text("The agent's reasoning will appear here.")
                    )
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(thoughts.reversed()) { thought in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(thought.timestamp, style: .time)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text(thought.content)
                                        .font(.system(size: 13))
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.secondary.opacity(0.08))
                                .cornerRadius(10)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Thinking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Process Detail Sheet

struct ProcessDetailSheet: View {
    let steps: [AgentProcessEntry]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if steps.isEmpty {
                    ContentUnavailableView(
                        "No Tool Calls",
                        systemImage: "wrench.and.screwdriver",
                        description: Text("Tool executions will appear here.")
                    )
                } else {
                    List(steps.reversed()) { step in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: step.status.icon)
                                    .foregroundColor(step.status.color)
                                    .frame(width: 18)
                                Text(step.toolName)
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.cyan)
                                Spacer()
                                Text(step.timestamp, style: .time)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            if !step.parameters.isEmpty {
                                Text("Params: \(step.parameters)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            if !step.result.isEmpty {
                                Text(step.result)
                                    .font(.caption)
                                    .foregroundColor(step.status == .completed ? .green : .red)
                                    .lineLimit(4)
                            }
                        }
                        .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Tool Executions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Logs Detail Sheet

struct LogsDetailSheet: View {
    let logs: [AgentLogEntry]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if logs.isEmpty {
                    ContentUnavailableView(
                        "No Logs",
                        systemImage: "doc.text",
                        description: Text("Logs will appear here during execution.")
                    )
                } else {
                    List(logs.reversed()) { log in
                        HStack(spacing: 8) {
                            Image(systemName: log.level.icon)
                                .foregroundColor(log.level.color)
                                .frame(width: 16)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(log.message).font(.system(size: 12))
                                Text(log.timestamp, style: .time)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Mode Selection Sheet

struct ModeSelectionSheet: View {
    @Binding var selectedMode: AgentExecutionMode
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Execution Mode") {
                    ForEach(AgentExecutionMode.allCases, id: \.self) { mode in
                        Button {
                            selectedMode = mode
                        } label: {
                            HStack {
                                Label(mode.rawValue, systemImage: mode.icon)
                                    .foregroundColor(.primary)
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(mode.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    if selectedMode == mode {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                }

            }
            .navigationTitle("Agent Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
