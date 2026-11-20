import Foundation

public struct MetaSlashCommandEffectOutcome: Sendable, Equatable {
    public var settings: AssistantSettings
    public var message: String
    public var clearsSession: Bool
    public var assistMode: AssistMode?
    public var promptToSend: String?
    public var decompileTarget: String?
    public var learnedRule: String?

    public init(
        settings: AssistantSettings,
        message: String,
        clearsSession: Bool = false,
        assistMode: AssistMode? = nil,
        promptToSend: String? = nil,
        decompileTarget: String? = nil,
        learnedRule: String? = nil
    ) {
        self.settings = settings
        self.message = message
        self.clearsSession = clearsSession
        self.assistMode = assistMode
        self.promptToSend = promptToSend
        self.decompileTarget = decompileTarget
        self.learnedRule = learnedRule
    }
}

public enum MetaSlashCommandEffectApplier {
    public static let validReasoningEfforts: [String] = [
        "none", "minimal", "low", "medium", "high", "xhigh", "max", "ultra",
    ]

    public static let loginInstruction =
        "Assist with Meta signs in outside SwiftCode: run `muse` once in Terminal and sign in there, then try again. " +
        "SwiftCode never launches an interactive `muse login` and cannot sign you in by itself."

    public static let executionModeDefaultsKey = "com.swiftcode.assist.executionMode"
    public static let agentModeDefaultsKey = "com.swiftcode.assist.mode"
    public static let reasoningLevelDefaultsKey = "com.swiftcode.assist.reasoningLevel"

    public static func interviewPrompt(topic: String) -> String {
        let focus = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        let focusText = focus.isEmpty ? "Gathering requirements and architectural trade-offs." : focus
        return """
        ### INTERVIEW PHASE ACTIVE
        Focus: \(focusText)

        Do not make code edits or mutations yet. Conduct an interactive interview to clarify user requirements, assess architectural tradeoffs, and gather critical specifications.
        Use the `plan-AskUser` decision tool to present structured questions with recommended choices before preparing the final execution plan.
        """
    }

    public static func learnPrompt() -> String {
        """
        ### LEARN FROM THIS SESSION
        Review the recent conversation and distill the durable rules, conventions, and preferences it established.
        Save each one to User Memory under the Rules category so future sessions follow them, then report back the rules you saved.
        Do not save one-off facts or anything the user has not actually established.
        """
    }

    public static func boostPrompt(objective: String) -> String {
        let objectiveText = objective.trimmingCharacters(in: .whitespacesAndNewlines)
        let objectiveLine = objectiveText.isEmpty ? "High-complexity software engineering challenge." : objectiveText
        return """
        ### MASTER ORCHESTRATOR MODE (BOOST) ACTIVE
        Objective: \(objectiveLine)

        You are the Master Orchestrator and Chief Technical Lead. Maximum reasoning effort is activated.
        1. Engage in deep strategic thinking, exploring codebase dependencies and architectural design before acting.
        2. Delegate discrete modules, refactors, and test suites to parallel subagents using `use_workers`.
        3. Supervise, review, and rigorously verify all worker output against strict compiler diagnostics and unit tests.
        4. Do not stop until the entire system is verified with zero regressions.
        """
    }

    public static func decompilePrompt(target: String) -> String {
        """
        ### DECOMPILEASSIST HANDOFF ACTIVE
        Target: \(target)

        Open a DecompileAssist session on this target and work through it with the DecompileAssist tools: inspect its symbols, strings, and functions, decompile the functions that matter, and reconstruct the implementation from the recovered evidence.
        Report the recovered structure, the key functions and their behavior, and anything the decompilation could not establish with confidence.
        """
    }

    public static func agentPrompt(for task: MetaAgentTask, target: String) -> String {
        let scope = target.trimmingCharacters(in: .whitespacesAndNewlines)
        let scopeText = scope.isEmpty ? "the workspace" : scope
        switch task {
        case .test:
            return """
            ### TEST RUN ACTIVE
            Scope: \(scopeText)

            Run the project test suite with the `project_test` tool. Where tests are missing for changed behavior, generate them with the `intel_generate_tests` tool, then report results and coverage with the `test_coverage_reporter` tool. Fix any failure you find and re-run until the suite is green.
            """
        case .review:
            return """
            ### CODE REVIEW ACTIVE
            Scope: \(scopeText)

            Run the `code_review` tool over \(scopeText). Report every finding with file and line, severity, and the concrete fix for each issue. Do not claim the review passed if the tool reports findings.
            """
        case .audit:
            return """
            ### SECURITY AUDIT ACTIVE
            Scope: \(scopeText)

            Audit \(scopeText) with the `security_audit_scanner`, `access_level_audit`, and `permissions_audit` tools, then run the `autonomous_review_engine` tool over the same scope. Report every finding with file and line, severity, and the concrete fix for each issue.
            """
        case .refactor:
            return """
            ### REFACTOR ACTIVE
            Target: \(scopeText)

            Refactor \(scopeText) with the `code_refactor` tool, preserving behavior and public interfaces. Run the project build and the affected tests afterwards and report the result; revert any refactor step the build or tests reject.
            """
        case .docs:
            return """
            ### DOCUMENTATION ACTIVE
            Scope: \(scopeText)

            Generate documentation for \(scopeText) with the `docs_generate` tool, verify it builds with the `docc_build` tool, and check API documentation coverage with the `api_docs_coverage` tool. Report what was generated and what coverage gaps remain.
            """
        case .debug:
            return """
            ### DEBUG ACTIVE
            Issue: \(scopeText)

            Diagnose this failure from real evidence: run the `build_log_analyze` tool on the latest build log, the `compiler_diagnostics_engine` tool on the reported diagnostics, the `runtime_diagnostics_engine` tool for runtime behavior, and the `crash_log_parse` tool if a crash log exists. Report the root cause with the evidence that proves it, then propose the fix.
            """
        case .profile:
            return """
            ### PROFILE ACTIVE
            Scope: \(scopeText)

            Profile \(scopeText) with the `performance_benchmark` tool, measure its code metrics with the `code_metrics_analyzer` tool, and locate complexity hot spots with the `complexity_analysis` tool. Report the measured numbers and the three highest-impact optimizations with the evidence behind each.
            """
        case .explain:
            return """
            ### EXPLAIN ACTIVE
            Target: \(scopeText)

            Explain \(scopeText) with the `intel_explain_code` tool: what it does, how it works, why it is shaped that way, and what depends on it. Ground every claim in the actual code.
            """
        case .summarize:
            return """
            ### SUMMARIZE ACTIVE
            Focus: \(scopeText)

            Summarize this conversation so far, focusing on \(scopeText): the decisions made, the work completed, the open questions, and the next steps. Keep it concise and do not invent decisions that were never made.
            """
        case .onboard:
            return """
            ### ONBOARDING ACTIVE
            Focus: \(scopeText)

            Explore this workspace with a focus on \(scopeText): its layout, build system, conventions, and existing AGENTS.md if one exists. Then create or improve AGENTS.md so a future session starts grounded in how this project actually works.
            """
        case .fix:
            return """
            ### FIX ACTIVE
            Issue: \(scopeText)

            Diagnose the failure behind \(scopeText) with the `compiler_diagnostics_engine` and `build_log_analyze` tools, apply fixes with the `intel_autofix` tool, and verify with a project build and the affected tests. Report the root cause, what changed, and the verification result.
            """
        }
    }

    public static func apply(
        _ effect: MetaSlashCommandEffect,
        settings: AssistantSettings,
        knownModelIDs: Set<String> = []
    ) -> MetaSlashCommandEffectOutcome {
        switch effect {
        case .setReasoningEffort(let raw):
            let value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard validReasoningEfforts.contains(value) else {
                return MetaSlashCommandEffectOutcome(
                    settings: settings,
                    message: "Unknown reasoning effort '\(raw)'. Valid levels: \(validReasoningEfforts.joined(separator: ", ")).")
            }
            var updated = settings
            updated.metaReasoningEffort = value
            return MetaSlashCommandEffectOutcome(
                settings: updated,
                message: "Meta reasoning effort set to '\(value)'.")
        case .setModel(let raw):
            let modelID = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            var updated = settings
            updated.setModel(modelID, for: .metaAssist)
            if knownModelIDs.contains(modelID) {
                return MetaSlashCommandEffectOutcome(
                    settings: updated,
                    message: "Meta Assist model switched to '\(modelID)'.")
            }
            return MetaSlashCommandEffectOutcome(
                settings: updated,
                message: "Meta Assist model switched to '\(modelID)'. That model is not in the known Meta catalog, " +
                    "so the next turn sends it as-is and the Muse host will report it if it does not exist.")
        case .clearSession:
            return MetaSlashCommandEffectOutcome(settings: settings, message: "Cleared Assist session.", clearsSession: true)
        case .startLogin:
            return MetaSlashCommandEffectOutcome(settings: settings, message: loginInstruction)
        case .setAssistMode(let mode):
            var updated = settings
            UserDefaults.standard.set(mode.executionMode.rawValue, forKey: Self.executionModeDefaultsKey)
            UserDefaults.standard.set(true, forKey: Self.agentModeDefaultsKey)
            if mode == .turbo {
                updated.metaReasoningEffort = "max"
                UserDefaults.standard.set("Extended", forKey: Self.reasoningLevelDefaultsKey)
            }
            return MetaSlashCommandEffectOutcome(
                settings: updated,
                message: "Switched to \(mode.displayName) mode. \(mode.shortDescription)",
                assistMode: mode)
        case .setChatMode:
            var updated = settings
            updated.agentMode = false
            UserDefaults.standard.set(false, forKey: Self.agentModeDefaultsKey)
            UserDefaults.standard.set(ExecutionMode.autopilot.rawValue, forKey: Self.executionModeDefaultsKey)
            return MetaSlashCommandEffectOutcome(
                settings: updated,
                message: "Switched to Chat mode. Assist answers conversationally and does not attach agent tools or start an autonomous agent session.",
                assistMode: .agent)
        case .boost(let objective):
            var updated = settings
            updated.metaReasoningEffort = "max"
            UserDefaults.standard.set(ExecutionMode.autopilot.rawValue, forKey: Self.executionModeDefaultsKey)
            UserDefaults.standard.set(true, forKey: Self.agentModeDefaultsKey)
            UserDefaults.standard.set("Extended", forKey: Self.reasoningLevelDefaultsKey)
            return MetaSlashCommandEffectOutcome(
                settings: updated,
                message: "Boost engaged: Turbo mode with maximum reasoning effort and parallel subagents.",
                assistMode: .turbo,
                promptToSend: Self.boostPrompt(objective: objective))
        case .guidedFlow(let kind, let topic):
            switch kind {
            case .interview:
                UserDefaults.standard.set(ExecutionMode.plan.rawValue, forKey: Self.executionModeDefaultsKey)
                UserDefaults.standard.set(true, forKey: Self.agentModeDefaultsKey)
                return MetaSlashCommandEffectOutcome(
                    settings: settings,
                    message: "Interview started in Plan mode. Assist asks structured questions before planning any work.",
                    assistMode: .plan,
                    promptToSend: Self.interviewPrompt(topic: topic))
            case .learn:
                let rule = topic.trimmingCharacters(in: .whitespacesAndNewlines)
                if rule.isEmpty {
                    return MetaSlashCommandEffectOutcome(
                        settings: settings,
                        message: "Distilling durable rules from the recent conversation into User Memory.",
                        promptToSend: Self.learnPrompt())
                }
                return MetaSlashCommandEffectOutcome(
                    settings: settings,
                    message: "Rule captured for User Memory under Rules: \(rule)",
                    learnedRule: rule)
            }
        case .sendAgentPrompt(let prompt):
            return MetaSlashCommandEffectOutcome(
                settings: settings,
                message: "Sent to Assist for execution.",
                promptToSend: prompt)
        case .startDecompile(let raw):
            let target = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            let display = target.isEmpty ? "the current binary" : target
            return MetaSlashCommandEffectOutcome(
                settings: settings,
                message: "DecompileAssist handoff prepared for \(display).",
                promptToSend: Self.decompilePrompt(target: display),
                decompileTarget: display)
        case .insertText:
            return MetaSlashCommandEffectOutcome(settings: settings, message: "")
        }
    }
}
