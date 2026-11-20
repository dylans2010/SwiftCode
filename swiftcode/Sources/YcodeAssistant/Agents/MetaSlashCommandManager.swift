import Foundation

public enum MetaCommandArgument: Identifiable, Hashable, Sendable {
    case options(name: String, choices: [String], defaultValue: String?)
    case text(name: String, placeholder: String, isOptional: Bool)

    public var id: String {
        switch self {
        case .options(let name, _, _): return "opt-\(name)"
        case .text(let name, _, _): return "txt-\(name)"
        }
    }

    public var argumentName: String {
        switch self {
        case .options(let name, _, _): return name
        case .text(let name, _, _): return name
        }
    }
}

public struct MetaSlashCommand: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let title: String
    public let description: String
    public let syntax: String
    public let icon: String
    public let category: String
    public let arguments: [MetaCommandArgument]
    public let isTerminalSkill: Bool

    public var requiresArguments: Bool { !arguments.isEmpty }

    public init(
        id: String,
        name: String,
        title: String,
        description: String,
        syntax: String,
        icon: String = "terminal.fill",
        category: String = "General",
        arguments: [MetaCommandArgument] = [],
        isTerminalSkill: Bool = false
    ) {
        self.id = id
        self.name = name
        self.title = title
        self.description = description
        self.syntax = syntax
        self.icon = icon
        self.category = category
        self.arguments = arguments
        self.isTerminalSkill = isTerminalSkill
    }
}

public enum MetaGuidedFlow: String, Sendable, Equatable {
    case interview
    case learn
}

public enum MetaAgentTask: String, Sendable, Equatable {
    case test
    case review
    case audit
    case refactor
    case docs
    case debug
    case profile
    case explain
    case summarize
    case onboard
    case fix
}

public enum MetaSlashCommandEffect: Sendable, Equatable {
    case setReasoningEffort(String)
    case setModel(String)
    case clearSession
    case startLogin
    case insertText(String)
    case setAssistMode(AssistMode)
    case setChatMode
    case boost(String)
    case guidedFlow(MetaGuidedFlow, String)
    case sendAgentPrompt(String)
    case startDecompile(String)
}

public struct MetaSlashCommandManager: Sendable {
    public static let skillsListTimeout: TimeInterval = 15

    public private(set) var commands: [MetaSlashCommand]
    public private(set) var isCapturing: Bool = false
    public private(set) var lastCapturedAt: Date?

    public static var builtInActionCommands: [MetaSlashCommand] {
        let existing = Set(builtInCommands.map(\.id))
        return BuiltInActionCatalogData.entries.filter { !existing.contains($0.id) }.map {
            MetaSlashCommand(id: $0.id, name: "/" + $0.id, title: $0.title, description: $0.subtitle,
                             syntax: "/\($0.id) [\($0.placeholder)]", icon: $0.icon, category: "Actions",
                             arguments: [.text(name: "Input", placeholder: $0.placeholder, isOptional: true)])
        }
    }

    public init(commands: [MetaSlashCommand] = Self.builtInCommands + Self.builtInActionCommands) {
        self.commands = commands
    }

    public static let builtInCommands: [MetaSlashCommand] = [
        MetaSlashCommand(id: "effort", name: "/effort", title: "Effort Level",
                         description: "Set the model's reasoning effort level",
                         syntax: "/effort [<none|minimal|low|medium|high|xhigh|max|ultra>]",
                         icon: "gauge.with.needle", category: "Model",
                         arguments: [.options(name: "Effort Tier",
                                              choices: ["none", "minimal", "low", "medium", "high", "xhigh", "max", "ultra"],
                                              defaultValue: "high")]),
        MetaSlashCommand(id: "model", name: "/model", title: "Choose Model",
                         description: "Select active Meta Assist model",
                         syntax: "/model [<model-id>]",
                         icon: "cpu", category: "Model",
                         arguments: [.options(name: "Model",
                                              choices: ["muse-wonder-1.0", "muse-spark-1.3", "muse-swift-2.0"],
                                              defaultValue: "muse-wonder-1.0")]),
        MetaSlashCommand(id: "skills", name: "/skills", title: "Skills Manager",
                         description: "Browse, reload, manage, and use skills",
                         syntax: "/skills [import|reload|manage|diagnostics|use <id> [prompt]]",
                         icon: "wand.and.stars", category: "Skills",
                         arguments: [.options(name: "Action",
                                              choices: ["list", "reload", "manage", "diagnostics", "import"],
                                              defaultValue: "list")]),
        MetaSlashCommand(id: "deep-research", name: "/deep-research", title: "Deep Research",
                         description: "Research a question across sources with cross-checking and citations",
                         syntax: "/deep-research <question>",
                         icon: "magnifyingglass.circle.fill", category: "Research",
                         arguments: [.text(name: "Question",
                                           placeholder: "Enter research topic or question...",
                                           isOptional: false)]),
        MetaSlashCommand(id: "goal", name: "/goal", title: "Autonomous Goal",
                         description: "Start or manage continuous work toward a goal",
                         syntax: "/goal [<objective>|edit <objective>|clear|cancel|stop|pause|resume]",
                         icon: "target", category: "Agent",
                         arguments: [.options(name: "Goal Action",
                                              choices: ["status", "resume", "pause", "stop", "cancel", "clear", "edit"],
                                              defaultValue: "status")]),
        MetaSlashCommand(id: "rules", name: "/rules", title: "Governing Rules",
                         description: "Show which markdown rule files govern this session",
                         syntax: "/rules [import]",
                         icon: "doc.text.badge.plus", category: "System",
                         arguments: [.options(name: "Action",
                                              choices: ["show", "import"],
                                              defaultValue: "show")]),
        MetaSlashCommand(id: "export", name: "/export", title: "Export Session",
                         description: "Save the conversation or the full session trajectory log",
                         syntax: "/export [transcript|trajectory]",
                         icon: "square.and.arrow.up", category: "Session",
                         arguments: [.options(name: "Format",
                                              choices: ["transcript", "trajectory"],
                                              defaultValue: "transcript")]),
        MetaSlashCommand(id: "voice", name: "/voice", title: "Voice Input",
                         description: "Manage voice input transcription and audio diagnostics",
                         syntax: "/voice [status|debug]",
                         icon: "waveform", category: "System",
                         arguments: [.options(name: "Option",
                                              choices: ["status", "debug"],
                                              defaultValue: "status")]),
        MetaSlashCommand(id: "stop", name: "/stop", title: "Stop Tasks",
                         description: "Stop background tasks and terminal commands",
                         syntax: "/stop [all]",
                         icon: "stop.circle.fill", category: "Agent",
                         arguments: [.options(name: "Scope",
                                              choices: ["all"],
                                              defaultValue: "all")]),
        MetaSlashCommand(id: "copy", name: "/copy", title: "Copy to Clipboard",
                         description: "Copy a response, code block, or ran command to clipboard",
                         syntax: "/copy [N]",
                         icon: "doc.on.doc", category: "Session",
                         arguments: [.options(name: "Target",
                                              choices: ["last", "1", "2", "3"],
                                              defaultValue: "last")]),
        MetaSlashCommand(id: "name", name: "/name", title: "Name Session",
                         description: "Name or rename this session for resume and reference",
                         syntax: "/name [<name>]",
                         icon: "tag", category: "Session",
                         arguments: [.text(name: "Session Name",
                                           placeholder: "e.g. feature-auth-refactor",
                                           isOptional: false)]),
        MetaSlashCommand(id: "resume", name: "/resume", title: "Resume Session",
                         description: "Resume an earlier Muse Code session",
                         syntax: "/resume [--last|<id-or-name>]",
                         icon: "arrow.clockwise", category: "Session",
                         arguments: [.options(name: "Target",
                                              choices: ["--last"],
                                              defaultValue: "--last")]),
        MetaSlashCommand(id: "fork", name: "/fork", title: "Fork Conversation",
                         description: "Branch this session from the latest message",
                         syntax: "/fork [prompt]",
                         icon: "arrow.triangle.branch", category: "Session",
                         arguments: [.text(name: "Prompt",
                                           placeholder: "Branch goal or prompt...",
                                           isOptional: true)]),
        MetaSlashCommand(id: "feedback", name: "/feedback", title: "Send Feedback",
                         description: "Send quick feedback or report a bug to the team",
                         syntax: "/feedback [note]",
                         icon: "envelope", category: "System",
                         arguments: [.text(name: "Note",
                                           placeholder: "Feedback message or bug report...",
                                           isOptional: false)]),
        MetaSlashCommand(id: "clear", name: "/clear", title: "Clear Session",
                         description: "Clear terminal and start a fresh session",
                         syntax: "/clear",
                         icon: "trash", category: "Session"),
        MetaSlashCommand(id: "rewind", name: "/rewind", title: "Rewind",
                         description: "Rewind conversation to an earlier input",
                         syntax: "/rewind",
                         icon: "arrow.uturn.backward", category: "Session"),
        MetaSlashCommand(id: "side", name: "/side", title: "Side Chat",
                         description: "Start a side conversation without polluting main context",
                         syntax: "/side",
                         icon: "bubble.left.and.bubble.right", category: "Session"),
        MetaSlashCommand(id: "init", name: "/init", title: "Initialize Workspace",
                         description: "Explore the workspace and create or improve AGENTS.md",
                         syntax: "/init",
                         icon: "sparkles", category: "Agent"),
        MetaSlashCommand(id: "subagents", name: "/subagents", title: "View Subagents",
                         description: "View running and past subagents in this workspace",
                         syntax: "/subagents",
                         icon: "person.3", category: "Agent"),
        MetaSlashCommand(id: "settings", name: "/settings", title: "Meta Settings",
                         description: "Open local Meta Code configuration and settings",
                         syntax: "/settings",
                         icon: "gearshape", category: "Configuration"),
        MetaSlashCommand(id: "keymap", name: "/keymap", title: "Keyboard Shortcuts",
                         description: "Show keyboard shortcuts and key bindings",
                         syntax: "/keymap",
                         icon: "keyboard", category: "Configuration"),
        MetaSlashCommand(id: "help", name: "/help", title: "Meta Help",
                         description: "Show Meta Code help and command catalog",
                         syntax: "/help",
                         icon: "questionmark.circle.fill", category: "General"),
        MetaSlashCommand(id: "theme", name: "/theme", title: "Theme",
                         description: "Choose color theme for Meta Code",
                         syntax: "/theme",
                         icon: "paintpalette", category: "Configuration"),
        MetaSlashCommand(id: "compact", name: "/compact", title: "Compact Context",
                         description: "Summarize conversation to free up context window",
                         syntax: "/compact",
                         icon: "arrow.down.right.and.arrow.up.left", category: "Session"),
        MetaSlashCommand(id: "recap", name: "/recap", title: "Recap Activity",
                         description: "Show a recap of recent session activity",
                         syntax: "/recap",
                         icon: "newspaper", category: "Session"),
        MetaSlashCommand(id: "plugins", name: "/plugins", title: "Plugins",
                         description: "Validate and manage installed plugins",
                         syntax: "/plugins",
                         icon: "puzzlepiece", category: "Skills"),
        MetaSlashCommand(id: "mcp", name: "/mcp", title: "MCP Servers",
                         description: "Show Model Context Protocol servers and active tools",
                         syntax: "/mcp",
                         icon: "network", category: "System"),
        MetaSlashCommand(id: "status", name: "/status", title: "Session Status",
                         description: "Show current session status and environment health",
                         syntax: "/status",
                         icon: "info.circle", category: "Session"),
        MetaSlashCommand(id: "usage", name: "/usage", title: "Usage & Cost",
                         description: "Show session usage, token count, and cost metrics",
                         syntax: "/usage",
                         icon: "chart.bar", category: "Session"),
        MetaSlashCommand(id: "permissions", name: "/permissions", title: "Permissions",
                         description: "Choose what Muse Code is allowed to execute and read",
                         syntax: "/permissions",
                         icon: "lock.shield", category: "Configuration"),
        MetaSlashCommand(id: "tasks", name: "/tasks", title: "Background Tasks",
                         description: "View and manage background tasks and active terminals",
                         syntax: "/tasks",
                         icon: "list.bullet.rectangle", category: "Agent"),
        MetaSlashCommand(id: "workflows", name: "/workflows", title: "Workflows",
                         description: "Browse workflow runs and multi-step plans",
                         syntax: "/workflows",
                         icon: "flowchart", category: "Agent"),
        MetaSlashCommand(id: "questions", name: "/questions", title: "Pending Questions",
                         description: "Answer pending questions from running agents",
                         syntax: "/questions",
                         icon: "questionmark.circle", category: "Session"),
        MetaSlashCommand(id: "hud", name: "/hud", title: "Status Bar HUD",
                         description: "Choose what appears in the bottom status bar",
                         syntax: "/hud",
                         icon: "menubar.dock.rectangle", category: "Configuration"),
        MetaSlashCommand(id: "login", name: "/login", title: "Log In",
                         description: "Log in with Meta account or using an API key",
                         syntax: "/login",
                         icon: "person.crop.circle.badge.plus", category: "System"),
        MetaSlashCommand(id: "logout", name: "/logout", title: "Log Out",
                         description: "Log out, forget saved login, and exit",
                         syntax: "/logout",
                         icon: "arrow.backward.circle", category: "System"),
        MetaSlashCommand(id: "interview", name: "/interview", title: "Interview",
                         description: "Start a guided interview that asks structured questions before planning any work",
                         syntax: "/interview [topic]",
                         icon: "questionmark.bubble", category: "Agent",
                         arguments: [.text(name: "Topic",
                                           placeholder: "What should the interview clarify?...",
                                           isOptional: true)]),
        MetaSlashCommand(id: "boost", name: "/boost", title: "Boost",
                         description: "Raise reasoning to maximum, switch to Turbo mode, and orchestrate parallel subagents",
                         syntax: "/boost [objective]",
                         icon: "bolt.fill", category: "Agent",
                         arguments: [.text(name: "Objective",
                                           placeholder: "High-complexity objective to conquer...",
                                           isOptional: true)]),
        MetaSlashCommand(id: "learn", name: "/learn", title: "Learn Rule",
                         description: "Save a rule to User Memory, or distill rules from the recent conversation when no rule is given",
                         syntax: "/learn [rule]",
                         icon: "brain", category: "Agent",
                         arguments: [.text(name: "Rule",
                                           placeholder: "Rule or guideline to remember...",
                                           isOptional: true)]),
        MetaSlashCommand(id: "reverse", name: "/reverse", title: "Reverse Engineer",
                         description: "Hand a binary to DecompileAssist for symbol, string, and function analysis",
                         syntax: "/reverse [binary]",
                         icon: "cpu", category: "Agent",
                         arguments: [.text(name: "Binary",
                                           placeholder: "Path to the binary to reverse...",
                                           isOptional: true)]),
        MetaSlashCommand(id: "decompile", name: "/decompile", title: "Decompile",
                         description: "Decompile a binary through DecompileAssist and reconstruct its implementation",
                         syntax: "/decompile [binary]",
                         icon: "doc.text.magnifyingglass", category: "Agent",
                         arguments: [.text(name: "Binary",
                                           placeholder: "Path to the binary to decompile...",
                                           isOptional: true)]),
        MetaSlashCommand(id: "audit", name: "/audit", title: "Security Audit",
                         description: "Run security, access-level, and permissions audits over the workspace",
                         syntax: "/audit [scope]",
                         icon: "shield.checkered", category: "Agent",
                         arguments: [.text(name: "Scope",
                                           placeholder: "What to audit...",
                                           isOptional: true)]),
        MetaSlashCommand(id: "review", name: "/review", title: "Code Review",
                         description: "Run the code review tool over recent changes or a given scope",
                         syntax: "/review [scope]",
                         icon: "checkmark.seal", category: "Agent",
                         arguments: [.text(name: "Scope",
                                           placeholder: "What to review...",
                                           isOptional: true)]),
        MetaSlashCommand(id: "explain", name: "/explain", title: "Explain Code",
                         description: "Explain the selected code or a given file, symbol, or concept in plain terms",
                         syntax: "/explain [target]",
                         icon: "text.book.closed", category: "Agent",
                         arguments: [.text(name: "Target",
                                           placeholder: "Code, file, or symbol to explain...",
                                           isOptional: true)]),
        MetaSlashCommand(id: "refactor", name: "/refactor", title: "Refactor",
                         description: "Refactor the given code with the code refactor tool and verify the result builds",
                         syntax: "/refactor [target]",
                         icon: "arrow.triangle.2.circlepath", category: "Agent",
                         arguments: [.text(name: "Target",
                                           placeholder: "Code or file to refactor...",
                                           isOptional: true)]),
        MetaSlashCommand(id: "test", name: "/test", title: "Run Tests",
                         description: "Run the project test suite, generate missing tests, and report coverage",
                         syntax: "/test [scope]",
                         icon: "testtube.2", category: "Agent",
                         arguments: [.text(name: "Scope",
                                           placeholder: "Test scope, target, or filter...",
                                           isOptional: true)]),
        MetaSlashCommand(id: "docs", name: "/docs", title: "Generate Docs",
                         description: "Generate documentation for the workspace and check API documentation coverage",
                         syntax: "/docs [scope]",
                         icon: "book", category: "Agent",
                         arguments: [.text(name: "Scope",
                                           placeholder: "What to document...",
                                           isOptional: true)]),
        MetaSlashCommand(id: "debug", name: "/debug", title: "Debug",
                         description: "Diagnose a failure from build logs, compiler diagnostics, runtime diagnostics, or crash logs",
                         syntax: "/debug [issue]",
                         icon: "ant", category: "Agent",
                         arguments: [.text(name: "Issue",
                                           placeholder: "Failure, error, or crash to diagnose...",
                                           isOptional: true)]),
        MetaSlashCommand(id: "profile", name: "/profile", title: "Profile Performance",
                         description: "Benchmark performance and measure code metrics and complexity hot spots",
                         syntax: "/profile [scope]",
                         icon: "speedometer", category: "Agent",
                         arguments: [.text(name: "Scope",
                                           placeholder: "What to profile...",
                                           isOptional: true)]),
        MetaSlashCommand(id: "plan", name: "/plan", title: "Plan Mode",
                         description: "Switch to Plan mode: read, search, and plan only, with no file changes",
                         syntax: "/plan",
                         icon: "list.clipboard", category: "Agent"),
        MetaSlashCommand(id: "turbo", name: "/turbo", title: "Turbo Mode",
                         description: "Switch to Turbo mode: autonomous parallel work with maximum reasoning effort",
                         syntax: "/turbo",
                         icon: "tornado", category: "Agent"),
        MetaSlashCommand(id: "agent", name: "/agent", title: "Agent Mode",
                         description: "Switch to Agent mode: normal tool use with confirmations and reviewable file changes",
                         syntax: "/agent",
                         icon: "sparkles", category: "Agent"),
        MetaSlashCommand(id: "chat", name: "/chat", title: "Chat Mode",
                         description: "Switch to Chat mode: conversational answers only, with no agent tool attachment",
                         syntax: "/chat",
                         icon: "bubble.left.and.text.bubble.right", category: "Agent"),
        MetaSlashCommand(id: "summarize", name: "/summarize", title: "Summarize",
                         description: "Summarize the conversation so far into decisions, open questions, and next steps",
                         syntax: "/summarize [focus]",
                         icon: "text.quote", category: "Session",
                         arguments: [.text(name: "Focus",
                                           placeholder: "What the summary should focus on...",
                                           isOptional: true)]),
        MetaSlashCommand(id: "onboard", name: "/onboard", title: "Onboard Workspace",
                         description: "Explore the workspace and create or improve AGENTS.md so future sessions start grounded",
                         syntax: "/onboard [focus]",
                         icon: "map", category: "Agent",
                         arguments: [.text(name: "Focus",
                                           placeholder: "Area to focus the onboarding on...",
                                           isOptional: true)]),
        MetaSlashCommand(id: "fix", name: "/fix", title: "Fix Errors",
                         description: "Diagnose build or test errors and apply automated fixes, then verify the build",
                         syntax: "/fix [issue]",
                         icon: "wrench", category: "Agent",
                         arguments: [.text(name: "Issue",
                                           placeholder: "Error or failing area to fix...",
                                           isOptional: true)]),
    ]

    public static func parseSkillsList(_ stdout: String) -> [MetaSlashCommand] {
        var skills: [MetaSlashCommand] = []
        for line in stdout.components(separatedBy: .newlines) {
            let parts = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard parts.count >= 2 else { continue }
            let skillName = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !skillName.isEmpty, !skillName.hasPrefix("#") else { continue }

            var description = "Execute \(skillName) skill"
            if parts.count >= 5 {
                let fullDesc = parts[4].trimmingCharacters(in: .whitespacesAndNewlines)
                if !fullDesc.isEmpty { description = fullDesc }
            } else if parts.count >= 4 {
                let fullDesc = parts[3].trimmingCharacters(in: .whitespacesAndNewlines)
                if !fullDesc.isEmpty { description = fullDesc }
            }

            let formattedTitle = skillName
                .replacingOccurrences(of: "-", with: " ")
                .replacingOccurrences(of: "_", with: " ")
                .capitalized

            skills.append(MetaSlashCommand(
                id: "skill-\(skillName)",
                name: "/\(skillName)",
                title: formattedTitle,
                description: description,
                syntax: "/\(skillName) [prompt]",
                icon: "bolt.badge.automatic.fill",
                category: "Meta Skills",
                arguments: [.text(name: "Instructions",
                                  placeholder: "Optional instructions for \(formattedTitle)...",
                                  isOptional: true)],
                isTerminalSkill: true
            ))
        }
        return skills
    }

    public mutating func mergeCapturedSkills(_ skills: [MetaSlashCommand]) -> Bool {
        guard !skills.isEmpty else { return false }
        var merged = commands.filter { !$0.isTerminalSkill }
        merged.append(contentsOf: skills)
        commands = merged
        lastCapturedAt = Date()
        return true
    }

    public mutating func captureCommandsFromTerminal(
        executable: URL?,
        timeoutSeconds: TimeInterval = Self.skillsListTimeout,
        runner: (@Sendable (URL) async throws -> String)? = nil
    ) async {
        guard !isCapturing else { return }
        guard let executable else { return }
        isCapturing = true
        defer { isCapturing = false }
        let stdout: String
        do {
            if let runner {
                stdout = try await runner(executable)
            } else {
                stdout = try await Self.runSkillsList(executable: executable, timeoutSeconds: timeoutSeconds)
            }
        } catch {
            return
        }
        guard !stdout.isEmpty else { return }
        _ = mergeCapturedSkills(Self.parseSkillsList(stdout))
    }

    static func runSkillsList(executable: URL, timeoutSeconds: TimeInterval) async throws -> String {
        try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask {
                try await Task.detached {
                    let process = Process()
                    process.executableURL = executable
                    process.arguments = ["skills", "list"]
                    let out = Pipe()
                    process.standardOutput = out
                    process.standardError = FileHandle.nullDevice
                    process.standardInput = FileHandle.nullDevice
                    try process.run()
                    let data = out.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    guard process.terminationStatus == 0 else {
                        throw MuseCodeCLIError.executionFailed(
                            exitCode: process.terminationStatus,
                            stderr: "muse skills list failed.")
                    }
                    return String(decoding: data, as: UTF8.self)
                }.value
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                throw MuseCodeCLIError.timeout
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    public func searchCommands(query: String) -> [MetaSlashCommand] {
        let trimmed = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return commands }
        let cleanQuery = trimmed.hasPrefix("/") ? String(trimmed.dropFirst()) : trimmed
        return commands.filter { cmd in
            let cmdNameClean = cmd.name.hasPrefix("/") ? String(cmd.name.dropFirst()).lowercased() : cmd.name.lowercased()
            return cmdNameClean.contains(cleanQuery) ||
                cmd.title.lowercased().contains(cleanQuery) ||
                cmd.description.lowercased().contains(cleanQuery) ||
                cmd.category.lowercased().contains(cleanQuery)
        }
    }

    public func executeCommand(_ command: MetaSlashCommand, argument: String?) -> (text: String, effect: MetaSlashCommandEffect?) {
        let argString = (argument ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        switch command.id {
        case "effort":
            if !argString.isEmpty {
                return ("Meta reasoning effort set to '\(argString)'.", .setReasoningEffort(argString))
            }
        case "model":
            if !argString.isEmpty {
                return ("Meta Assist model switched to '\(argString)'.", .setModel(argString))
            }
        case "clear":
            return ("Cleared Assist session.", .clearSession)
        case "login":
            return ("Starting Meta authentication flow...", .startLogin)
        case "plan":
            return ("Switched to Plan mode.", .setAssistMode(.plan))
        case "agent":
            return ("Switched to Agent mode.", .setAssistMode(.agent))
        case "turbo":
            return ("Switched to Turbo mode.", .setAssistMode(.turbo))
        case "chat":
            return ("Switched to Chat mode.", .setChatMode)
        case "boost":
            return ("Boost engaged: Turbo mode with maximum effort and parallel subagents.", .boost(argString))
        case "interview":
            return ("Interview started.", .guidedFlow(.interview, argString))
        case "learn":
            return ("Learning from this session.", .guidedFlow(.learn, argString))
        case "reverse", "decompile":
            return ("DecompileAssist handoff prepared.", .startDecompile(argString))
        case "test":
            return ("Running the project test suite.", .sendAgentPrompt(MetaSlashCommandEffectApplier.agentPrompt(for: .test, target: argString)))
        case "review":
            return ("Running code review.", .sendAgentPrompt(MetaSlashCommandEffectApplier.agentPrompt(for: .review, target: argString)))
        case "audit":
            return ("Running security audit.", .sendAgentPrompt(MetaSlashCommandEffectApplier.agentPrompt(for: .audit, target: argString)))
        case "refactor":
            return ("Refactoring with verification.", .sendAgentPrompt(MetaSlashCommandEffectApplier.agentPrompt(for: .refactor, target: argString)))
        case "docs":
            return ("Generating documentation.", .sendAgentPrompt(MetaSlashCommandEffectApplier.agentPrompt(for: .docs, target: argString)))
        case "debug":
            return ("Diagnosing the failure.", .sendAgentPrompt(MetaSlashCommandEffectApplier.agentPrompt(for: .debug, target: argString)))
        case "profile":
            return ("Profiling performance.", .sendAgentPrompt(MetaSlashCommandEffectApplier.agentPrompt(for: .profile, target: argString)))
        case "explain":
            return ("Explaining the code.", .sendAgentPrompt(MetaSlashCommandEffectApplier.agentPrompt(for: .explain, target: argString)))
        case "summarize":
            return ("Summarizing the conversation.", .sendAgentPrompt(MetaSlashCommandEffectApplier.agentPrompt(for: .summarize, target: argString)))
        case "onboard":
            return ("Onboarding this workspace.", .sendAgentPrompt(MetaSlashCommandEffectApplier.agentPrompt(for: .onboard, target: argString)))
        case "fix":
            return ("Diagnosing and fixing errors.", .sendAgentPrompt(MetaSlashCommandEffectApplier.agentPrompt(for: .fix, target: argString)))
        default:
            if let entry = BuiltInActionCatalogData.entries.first(where: { $0.id == command.id }) {
                return ("\(entry.title) started.", .sendAgentPrompt(BuiltInActionCatalogData.basePrompt(id: entry.id, argument: argString)))
            }
        }

        if argString.isEmpty {
            return (command.name, .insertText(command.name))
        }
        return ("\(command.name) \(argString)", .insertText("\(command.name) \(argString)"))
    }
}

public struct SlashCommandPaletteState: Sendable {
    public var manager: MetaSlashCommandManager
    public private(set) var query: String
    public private(set) var selectedIndex: Int?

    public init(manager: MetaSlashCommandManager = MetaSlashCommandManager(), query: String = "") {
        self.manager = manager
        self.query = query
        self.selectedIndex = manager.searchCommands(query: query).isEmpty ? nil : 0
    }

    public var filtered: [MetaSlashCommand] { manager.searchCommands(query: query) }

    public var selected: MetaSlashCommand? {
        guard let selectedIndex, filtered.indices.contains(selectedIndex) else { return nil }
        return filtered[selectedIndex]
    }

    public mutating func update(query: String) {
        self.query = query
        let count = filtered.count
        if count == 0 {
            selectedIndex = nil
        } else if let selectedIndex, selectedIndex < count {
        } else {
            selectedIndex = 0
        }
    }

    public mutating func moveUp() {
        guard let selectedIndex, !filtered.isEmpty else { return }
        self.selectedIndex = (selectedIndex - 1 + filtered.count) % filtered.count
    }

    public mutating func moveDown() {
        guard let selectedIndex, !filtered.isEmpty else { return }
        self.selectedIndex = (selectedIndex + 1) % filtered.count
    }

    public func commitText(argument: String?) -> String? {
        guard let selected else { return nil }
        return manager.executeCommand(selected, argument: argument).text
    }

    public func shouldSendImmediately(argument: String?) -> Bool {
        guard let selected else { return false }
        switch manager.executeCommand(selected, argument: argument).effect {
        case .none, .some(.insertText): return false
        default: return true
        }
    }
}
