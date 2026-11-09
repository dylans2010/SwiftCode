import Foundation













public enum AssistMode: String, Codable, Sendable, CaseIterable {
    case plan
    case agent
    case turbo

    public var displayName: String {
        switch self {
        case .plan: "Plan"
        case .agent: "Agent"
        case .turbo: "Turbo"
        }
    }

    
    public var shortDescription: String {
        switch self {
        case .plan:
            "Read, search and plan only — no files are changed. Approve the plan, then switch modes to build it."
        case .agent:
            "Normal agent work: tools run with the usual confirmations, and every file change is shown for review."
        case .turbo:
            "Autonomous agent: parallel Workers, minimal confirmations, multi-step tasks run through with progress reported back."
        }
    }

    public var iconName: String {
        switch self {
        case .plan: "list.clipboard"
        case .agent: "sparkles"
        case .turbo: "bolt.fill"
        }
    }

    
    
    
    
    public var systemPromptAddendum: String {
        switch self {
        case .plan:
            """
            # MODE: PLAN — READ-ONLY
            You are in Plan mode. Read files, search the codebase, run builds and diagnostics, and reason about the work — but do not write, edit, create or delete any file, do not run terminal commands that change anything, and do not delegate mutating work to Workers. End every reply with a structured plan: the goal, the ordered steps, the files each step touches, the risks, and what you need the user to approve. Do not start implementing until the user approves the plan and switches modes.
            """
        case .agent:
            """
            # MODE: AGENT
            Work normally: use the available tools as needed, honour the usual confirmations, and present every file change as a proposal for the user to review.
            """
        case .turbo:
            """
            # MODE: TURBO — AUTONOMOUS
            Work autonomously and fast. Break multi-step work into independent subtasks and run them in parallel with the use_workers tool. Do not pause for confirmation on routine steps; keep going until the task is done or genuinely blocked. Report progress and results back to the main agent session as you go. File changes are still shown as proposals for the user to review.
            """
        }
    }

    
    
    
    public var executionMode: ExecutionMode {
        switch self {
        case .plan: .plan
        case .agent, .turbo: .autopilot
        }
    }
}
