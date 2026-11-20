import Foundation
import Observation
import os

private let logger = Logger(subsystem: "com.swiftcode.app", category: "SlashCommandExecutionEngine")

public struct SlashExecutionResult: Sendable {
    public let command: String
    public let messageToInsert: String?
    public let feedbackText: String
    public let shouldSubmitImmediately: Bool

    public init(
        command: String,
        messageToInsert: String? = nil,
        feedbackText: String,
        shouldSubmitImmediately: Bool = false
    ) {
        self.command = command
        self.messageToInsert = messageToInsert
        self.feedbackText = feedbackText
        self.shouldSubmitImmediately = shouldSubmitImmediately
    }
}

@MainActor
public final class SlashCommandExecutionEngine: Sendable {
    public static let shared = SlashCommandExecutionEngine()

    private init() {}

    public func execute(
        command: String,
        argument: String? = nil
    ) async -> SlashExecutionResult {
        let cleanCommand = command.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let arg = argument?.trimmingCharacters(in: .whitespacesAndNewlines)

        logger.info("Executing slash command '\(cleanCommand)' with argument: \(arg ?? "none")")

        switch cleanCommand {
        case "/schedule", "schedule":
            return await executeSchedule(argument: arg)

        case "/compact", "compact":
            return await executeCompact(focusInstructions: arg)

        case "/goal", "goal":
            return executeGoal(objective: arg)

        case "/teamwork", "teamwork":
            return executeTeamwork(task: arg)

        case "/interview", "interview":
            return executeInterview(topic: arg)

        case "/learn", "learn":
            return await executeLearn(topicOrRule: arg)

        case "/boost", "boost":
            return executeBoost(objective: arg)

        default:
            // Check if it matches an installed skill
            let skillName = cleanCommand.hasPrefix("/") ? String(cleanCommand.dropFirst()) : cleanCommand
            if let skill = SkillIndex.shared.skills.first(where: { $0.name.lowercased() == skillName || $0.id.lowercased() == skillName }) {
                return executeSkill(skill, argument: arg)
            }

            return SlashExecutionResult(
                command: cleanCommand,
                messageToInsert: nil,
                feedbackText: "Unknown slash command: \(cleanCommand)",
                shouldSubmitImmediately: false
            )
        }
    }

    // MARK: - /compact
    private func executeCompact(focusInstructions: String?) async -> SlashExecutionResult {
        let result = await AssistConversationCompactor.shared.compactCurrentSession(focusInstructions: focusInstructions)
        let percentStr = String(format: "%.1f", result.percentageSaved)
        let feedback = "🗜️ **Conversation Compacted**: Reduced from \(result.beforeTokens) to \(result.afterTokens) tokens (-\(percentStr)%). \(result.messagesCondensed) past message(s) synthesized into memory."

        var notifyMsg = AssistMessage(role: .system, content: feedback)
        notifyMsg.providerID = "compactor"
        AssistManager.shared.messages.append(notifyMsg)

        return SlashExecutionResult(
            command: "/compact",
            messageToInsert: nil,
            feedbackText: feedback,
            shouldSubmitImmediately: false
        )
    }

    // MARK: - /schedule
    private func executeSchedule(argument: String?) async -> SlashExecutionResult {
        guard let arg = argument, !arg.isEmpty else {
            let usage = "Usage: `/schedule <duration|cron> <task-prompt>`\nExample: `/schedule 15m Run build and test suite` or `/schedule 3600 Check git repo`"
            return SlashExecutionResult(command: "/schedule", messageToInsert: nil, feedbackText: usage, shouldSubmitImmediately: false)
        }

        let parts = arg.split(separator: " ", maxSplits: 1).map(String.init)
        guard let timingPart = parts.first, !timingPart.isEmpty else {
            return SlashExecutionResult(command: "/schedule", messageToInsert: nil, feedbackText: "Please specify duration (e.g. 10m, 1h) or cron expression.", shouldSubmitImmediately: false)
        }

        let taskPrompt = parts.count > 1 ? parts[1] : "Scheduled Task: \(timingPart)"

        if let seconds = AssistScheduledTaskManager.shared.parseDuration(timingPart) {
            let task = AssistScheduledTaskManager.shared.scheduleOneShot(delaySeconds: seconds, prompt: taskPrompt)
            let feedback = "⏰ **Task Scheduled**: Fires in \(seconds)s at \(task.nextFireDate.formatted(date: .omitted, time: .standard)).\nPrompt: _\"\(taskPrompt)\"_"
            return SlashExecutionResult(command: "/schedule", messageToInsert: nil, feedbackText: feedback, shouldSubmitImmediately: false)
        } else if timingPart.contains("*") || timingPart.contains("/") {
            let task = AssistScheduledTaskManager.shared.scheduleCron(expression: timingPart, prompt: taskPrompt)
            let feedback = "⏰ **Recurring Cron Scheduled**: [\(timingPart)] Fires periodically.\nPrompt: _\"\(taskPrompt)\"_"
            return SlashExecutionResult(command: "/schedule", messageToInsert: nil, feedbackText: feedback, shouldSubmitImmediately: false)
        } else {
            let fallbackSeconds = 300
            let task = AssistScheduledTaskManager.shared.scheduleOneShot(delaySeconds: fallbackSeconds, prompt: arg)
            let feedback = "⏰ **Task Scheduled**: Fires in 5 minutes (\(task.nextFireDate.formatted(date: .omitted, time: .standard))).\nPrompt: _\"\(arg)\"_"
            return SlashExecutionResult(command: "/schedule", messageToInsert: nil, feedbackText: feedback, shouldSubmitImmediately: false)
        }
    }

    // MARK: - /goal
    private func executeGoal(objective: String?) -> SlashExecutionResult {
        UserDefaults.standard.set(ExecutionMode.autopilot.rawValue, forKey: "com.swiftcode.assist.executionMode")

        let promptPayload: String
        if let obj = objective, !obj.isEmpty {
            promptPayload = """
            ### AUTONOMOUS GOAL MODE ACTIVE
            Objective: \(obj)

            Execute this goal autonomously from start to finish. Decompose steps internally, ground your analysis in the codebase, make required code changes, run builds, and verify tests without stopping to ask confirmation on routine decisions. Do not halt until the goal is fully achieved.
            """
        } else {
            promptPayload = """
            ### AUTONOMOUS GOAL MODE ACTIVE
            You are operating in fully autonomous Goal Mode. Accomplish all upcoming objectives end-to-end without pausing for routine confirmation. Validate all changes, fix errors, and verify completion before concluding.
            """
        }

        let feedback = "🎯 **Autonomous Goal Mode Activated**: Autopilot engaged. Pursuing objective end-to-end without interruption."

        return SlashExecutionResult(
            command: "/goal",
            messageToInsert: promptPayload,
            feedbackText: feedback,
            shouldSubmitImmediately: objective != nil
        )
    }

    // MARK: - /teamwork
    private func executeTeamwork(task: String?) -> SlashExecutionResult {
        let taskText = task ?? "Execute current architectural work using parallel subagents."

        let promptPayload = """
        ### TEAMWORK POLICY ACTIVE: Multi-Agent Parallel Execution Mandated
        Objective: \(taskText)

        You MUST decompose this task into subtasks and invoke specialized workers via the `use_workers` tool.
        - Assign distinct names and non-overlapping scopes (directories or modules) to each worker.
        - Ensure each worker's task is concrete and focused.
        - Act as the central coordinator: synthesize subagent outputs, verify filesystem changes, and ensure integration.
        """

        let feedback = "👥 **Teamwork Mode Activated**: Workers and subagents execution policy mandated for this session."

        return SlashExecutionResult(
            command: "/teamwork",
            messageToInsert: promptPayload,
            feedbackText: feedback,
            shouldSubmitImmediately: task != nil
        )
    }

    // MARK: - /interview
    private func executeInterview(topic: String?) -> SlashExecutionResult {
        UserDefaults.standard.set(ExecutionMode.plan.rawValue, forKey: "com.swiftcode.assist.executionMode")

        let topicText = topic ?? "Gathering requirements and architectural trade-offs."

        let promptPayload = """
        ### INTERVIEW PHASE ACTIVE
        Focus: \(topicText)

        Do not make code edits or mutations yet. Conduct an interactive interview to clarify user requirements, assess architectural tradeoffs, and gather critical specifications.
        Use the `plan-AskUser` decision tool to present structured questions with recommended choices before preparing the final execution plan.
        """

        let feedback = "📋 **Interactive Interview Activated**: Plan mode engaged. The Assistant will ask clarifying questions via decision prompts before implementing changes."

        return SlashExecutionResult(
            command: "/interview",
            messageToInsert: promptPayload,
            feedbackText: feedback,
            shouldSubmitImmediately: topic != nil
        )
    }

    // MARK: - /learn
    private func executeLearn(topicOrRule: String?) async -> SlashExecutionResult {
        let text = topicOrRule ?? ""

        if text.isEmpty {
            // Reflect on recent messages
            let messages = AssistManager.shared.messages
            let lastUserMessages = messages.filter { $0.role == .user }.suffix(3)
            let summary = lastUserMessages.map { $0.content }.joined(separator: " | ")
            let key = "LearnedPattern_\(Date().formatted(date: .numeric, time: .omitted))"
            let value = summary.isEmpty ? "Standard SwiftCode project patterns and conventions." : summary

            UserMemoryManager.shared.saveEntry(key: key, value: value, category: "Rules")
            let feedback = "🧠 **Learned & Remembered**: Captured key session rules into User Memory (`\(key)`)."
            return SlashExecutionResult(command: "/learn", messageToInsert: nil, feedbackText: feedback, shouldSubmitImmediately: false)
        } else {
            // Direct rule or guideline
            let key = text.components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
            let safeKey = String(key.prefix(28)).isEmpty ? "LearnedRule_\(UUID().uuidString.prefix(6))" : String(key.prefix(28))
            UserMemoryManager.shared.saveEntry(key: safeKey, value: text, category: "Rules")
            let feedback = "🧠 **Rule Captured**: Saved `\(safeKey)` to User Memory under Rules:\n_\"\(text)\"_"
            return SlashExecutionResult(command: "/learn", messageToInsert: nil, feedbackText: feedback, shouldSubmitImmediately: false)
        }
    }

    // MARK: - /boost
    private func executeBoost(objective: String?) -> SlashExecutionResult {
        UserDefaults.standard.set("Extended", forKey: "com.swiftcode.assist.reasoningLevel")

        let objText = objective ?? "High-complexity software engineering challenge."

        let promptPayload = """
        ### MASTER ORCHESTRATOR MODE (BOOST) ACTIVE
        Objective: \(objText)

        You are the Master Orchestrator and Chief Technical Lead. Maximum reasoning effort is activated.
        1. Engage in deep strategic thinking, exploring codebase dependencies and architectural design before acting.
        2. Delegate discrete modules, refactors, and test suites to parallel subagents using `use_workers`.
        3. Supervise, review, and rigorously verify all worker output against strict compiler diagnostics and unit tests.
        4. Do not stop until the entire system is verified with zero regressions.
        """

        let feedback = "⚡️ **Boost Master Orchestrator Activated**: Deep reasoning enabled. The model will command and boss around subagents to conquer this task."

        return SlashExecutionResult(
            command: "/boost",
            messageToInsert: promptPayload,
            feedbackText: feedback,
            shouldSubmitImmediately: objective != nil
        )
    }

    // MARK: - Installed Skill Execution
    private func executeSkill(_ skill: SkillDescriptor, argument: String?) -> SlashExecutionResult {
        var promptPayload = "### SKILL ACTIVE: \(skill.name)\n"
        if let arg = argument, !arg.isEmpty {
            promptPayload += "Task: \(arg)\n\n"
        }
        promptPayload += "Description: \(skill.description)\n"

        let feedback = "🪄 **Skill Activated**: `\(skill.name)` (\(skill.sourceKind.rawValue))."

        return SlashExecutionResult(
            command: "/\(skill.name)",
            messageToInsert: promptPayload,
            feedbackText: feedback,
            shouldSubmitImmediately: argument != nil
        )
    }
}
