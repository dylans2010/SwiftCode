import Foundation

/// A built-in Assist action (slash command) that gathers real workspace evidence with
/// read-only tools, then hands the model a precise, verifiable workflow.
public struct BuiltInAction: Identifiable, Sendable, Hashable {
    public struct Preflight: Sendable, Hashable {
        public let toolID: String
        public let arguments: [String: String]
        public init(_ toolID: String, _ arguments: [String: String] = [:]) {
            self.toolID = toolID
            self.arguments = arguments
        }
    }

    public let id: String
    public var command: String { "/" + id }
    public let title: String
    public let subtitle: String
    public let icon: String
    public let category: String
    public let argumentPlaceholder: String
    public let preflight: [Preflight]
    public let workflow: [String]
    public let systemAssets: [String]

    public var placeholder: String { argumentPlaceholder }
}

/// Nonisolated view of the built-in actions for value-type palettes (Meta Assist).
public enum BuiltInActionCatalogData {
    public static var entries: [BuiltInAction] { BuiltInActionCatalog.actions }

    public static func basePrompt(id: String, argument: String?) -> String {
        guard let action = BuiltInActionCatalog.action(for: id) else { return "/" + id + " " + (argument ?? "") }
        return BuiltInActionCatalog.basePrompt(for: action, argument: argument)
    }
}

public enum BuiltInActionCatalog {

    /// Every built-in action: the 20 core actions plus `extendedActions`.
    public static let actions: [BuiltInAction] = coreActions + extendedActions

    public static let coreActions: [BuiltInAction] = [
        BuiltInAction(id: "verify", title: "Verify Changes", subtitle: "Build, test and review every uncommitted change before calling the work done",
                      icon: "checkmark.seal.fill", category: "Quality", argumentPlaceholder: "Optional scope (target or path)...",
                      preflight: [.init("git_diff_stat_range"), .init("git_untracked_files")],
                      workflow: ["Read each changed file region and confirm it matches the intent.", "Build the affected targets (swiftpm_build_target or xcodebuild).", "Run the relevant tests, then the full suite (swiftpm_run_filtered_tests / test tools).", "Run git_whitespace_check and the safety scans on touched files.", "Report a pass/fail table with the exact commands and outputs; fix any failure before reporting success."],
                      systemAssets: ["AutonomousVerificationProtocols", "BuildAndTesting"]),
        BuiltInAction(id: "harden", title: "Security Hardening", subtitle: "Scan for secrets, weak crypto and insecure transport, then fix the findings",
                      icon: "lock.shield.fill", category: "Security", argumentPlaceholder: "Optional path to harden...",
                      preflight: [.init("scan_hardcoded_secrets"), .init("scan_weak_crypto"), .init("scan_insecure_http_urls"), .init("scan_insecure_random")],
                      workflow: ["Triage every finding below as real issue or false positive with a reason.", "Fix real issues: move secrets to the Keychain/config, use CryptoKit, enforce HTTPS, use SystemRandomNumberGenerator.", "Re-run the same scans to prove the findings are gone.", "Build and run tests for touched modules.", "Summarize fixes, remaining risks and any secrets that must be rotated."],
                      systemAssets: ["SecretsManagementInApps", "KeychainSecurityArchitecture", "SSLPinningAndNetworkSecurity"]),
        BuiltInAction(id: "commit", title: "Draft Commit", subtitle: "Write a precise commit message from the real staged diff",
                      icon: "text.badge.checkmark", category: "Git", argumentPlaceholder: "Optional context for the message...",
                      preflight: [.init("git_staged_diff_stat"), .init("git_last_commit")],
                      workflow: ["Inspect the staged diff (git diff --cached) for the files listed below.", "If nothing is staged, say so and propose which files belong together.", "Write an imperative subject ≤ 72 characters and a body explaining why.", "Flag unrelated changes that should be split into separate commits.", "Only commit when the user asked you to; otherwise present the message."],
                      systemAssets: ["GitWorkflowsAndBranching"]),
        BuiltInAction(id: "changelog", title: "Generate Changelog", subtitle: "Turn git history since the last tag into user-facing release notes",
                      icon: "list.bullet.rectangle.portrait", category: "Documentation", argumentPlaceholder: "Optional base tag/revision...",
                      preflight: [.init("git_tag_list"), .init("git_describe_version")],
                      workflow: ["Pick the base: the given revision or the latest tag below.", "Collect commits since the base (git_changed_files_since, git_log_search_messages).", "Group into Added / Changed / Fixed / Removed / Security, written for users.", "Recommend the next version with semver_bump and explain why.", "Update CHANGELOG.md in Keep a Changelog format when the user asked for a file change."],
                      systemAssets: ["ReleaseNotesAndVersioning"]),
        BuiltInAction(id: "a11y", title: "Accessibility Pass", subtitle: "Find and fix VoiceOver, Dynamic Type and contrast problems in SwiftUI code",
                      icon: "accessibility", category: "UI Design", argumentPlaceholder: "Optional view or folder...",
                      preflight: [.init("scan_accessibility_modifiers"), .init("scan_fixed_font_sizes"), .init("scan_sf_symbol_images")],
                      workflow: ["Review the findings below and open the affected views.", "Add accessibilityLabel/Hint/Value to icon-only and custom controls.", "Replace fixed font sizes with text styles; check contrast with color_contrast_ratio.", "Build and preview at large Dynamic Type.", "Report fixed issues by file and any remaining manual checks (VoiceOver walkthrough)."],
                      systemAssets: ["AccessibilityAuditAndRemediation"]),
        BuiltInAction(id: "deps", title: "Dependency Audit", subtitle: "Review package dependencies for health, licenses, pinning and unused packages",
                      icon: "shippingbox.and.arrow.backward", category: "Security", argumentPlaceholder: "Optional dependency name...",
                      preflight: [.init("swift_list_imports")],
                      workflow: ["Describe the package (swiftpm_describe_package) and its resolved tree (swiftpm_dependency_tree).", "For each direct dependency check activity, license and latest release (github_repository_info).", "Find dependencies never imported in sources using the imports below.", "Flag branch/revision pins and outdated majors.", "Produce a table: dependency, version, license, status, recommendation."],
                      systemAssets: ["ThirdPartyDependencyAudit", "SPMConfigurationDeepDive"]),
        BuiltInAction(id: "cleanup", title: "Cleanup Pass", subtitle: "Remove debug prints, empty files, stale TODOs and dead code safely",
                      icon: "sparkles", category: "Quality", argumentPlaceholder: "Optional path...",
                      preflight: [.init("scan_print_statements"), .init("workspace_empty_files"), .init("scan_todo_fixme_markers")],
                      workflow: ["Classify each finding: remove, keep (with reason) or convert (print → Logger).", "Confirm declarations are unused with swift_symbol_references before deleting.", "Apply changes in small steps; build after each step.", "Run tests.", "List everything removed and everything intentionally kept."],
                      systemAssets: ["RefactoringLegacyCode"]),
        BuiltInAction(id: "spec", title: "Write Spec", subtitle: "Produce a technical specification with goals, design, risks and test plan",
                      icon: "doc.text.magnifyingglass", category: "Planning", argumentPlaceholder: "Feature or change to specify...",
                      preflight: [.init("workspace_extension_stats")],
                      workflow: ["Explore the code areas the feature touches before writing.", "Write Problem, Goals, Non-goals, Design (types, data flow, APIs), Alternatives, Risks, Test plan, Rollout.", "Reference real files and symbols, never invented ones.", "List open questions for the user.", "Save as a Markdown file only when the user asked for a file."],
                      systemAssets: ["ExecutionPlans", "MultiTurnPlanningStrategy"]),
        BuiltInAction(id: "swift6", title: "Swift 6 Readiness", subtitle: "Find concurrency-safety blockers and migrate toward Swift 6 language mode",
                      icon: "swift", category: "Swift", argumentPlaceholder: "Optional module/path...",
                      preflight: [.init("scan_unchecked_sendable"), .init("scan_nonisolated_unsafe"), .init("scan_dispatch_main_queue")],
                      workflow: ["Rank the findings by risk (shared mutable state first).", "Replace @unchecked Sendable / nonisolated(unsafe) with actors, immutability or locks with justification.", "Convert DispatchQueue.main hops to @MainActor isolation.", "Build with strict concurrency checking and fix diagnostics.", "Report remaining blockers per module."],
                      systemAssets: ["Swift6Concurrency", "ActorsAndIsolation"]),
        BuiltInAction(id: "standup", title: "Standup Summary", subtitle: "Summarize recent repository activity, open branches and work in progress",
                      icon: "person.3.sequence.fill", category: "Git", argumentPlaceholder: "Optional author filter...",
                      preflight: [.init("git_last_commit"), .init("git_branch_overview"), .init("git_diff_stat_range")],
                      workflow: ["Summarize what changed recently (git_log_viewer / git_log_by_author for the given author).", "List branches with recent activity and their ahead/behind state.", "Describe uncommitted work in progress.", "Call out risks or blockers visible in the history.", "Format as Yesterday / Today / Blockers bullets."],
                      systemAssets: ["ResponseFormatting"]),
        BuiltInAction(id: "coverage", title: "Coverage Gaps", subtitle: "Map tests to sources and add tests for the riskiest untested code",
                      icon: "chart.bar.doc.horizontal", category: "Testing", argumentPlaceholder: "Optional module/path...",
                      preflight: [.init("swift_list_test_functions")],
                      workflow: ["Compare test functions below with source types (swift_list_types).", "Run tests with coverage enabled and read the report.", "Pick the riskiest uncovered logic.", "Write focused tests (swift_generate_test_skeleton) with real assertions.", "Run them and report coverage before/after."],
                      systemAssets: ["UnitTestingBestPractices", "TestDataManagement"]),
        BuiltInAction(id: "optimize", title: "Optimize Hot Paths", subtitle: "Find SwiftUI and Foundation performance anti-patterns and fix the costliest",
                      icon: "gauge.with.dots.needle.67percent", category: "Performance", argumentPlaceholder: "Optional screen or path...",
                      preflight: [.init("scan_formatter_allocations"), .init("scan_anyview_usage"), .init("file_long_functions_report")],
                      workflow: ["Identify the user-visible slowness to target.", "Review findings and fix the most expensive patterns first.", "Keep behavior identical; add a performance test or measurement where possible.", "Build and run tests.", "Report measured or reasoned impact per change."],
                      systemAssets: ["PerformanceProfilingInstruments", "PerformanceBudgets"]),
        BuiltInAction(id: "testgen", title: "Generate Tests", subtitle: "Write real unit tests for a type or file and run them",
                      icon: "testtube.2", category: "Testing", argumentPlaceholder: "Type name or file path...",
                      preflight: [.init("swift_list_test_functions")],
                      workflow: ["Read the target type and its dependencies.", "Enumerate behaviors and edge cases.", "Generate a skeleton with swift_generate_test_skeleton and fill real expectations.", "Run the new tests (swiftpm_run_filtered_tests) and make them pass without weakening assertions.", "Report what is covered and what still needs integration tests."],
                      systemAssets: ["UnitTestingBestPractices", "MockingAndStubbing"]),
        BuiltInAction(id: "design", title: "UI Design Review", subtitle: "Review SwiftUI screens against the design system, layout and platform conventions",
                      icon: "paintpalette.fill", category: "UI Design", argumentPlaceholder: "Optional view name...",
                      preflight: [.init("swift_list_swiftui_views"), .init("scan_hardcoded_colors")],
                      workflow: ["Pick the views in scope from the list below.", "Check spacing, typography, color tokens, states (empty/loading/error) and dark mode.", "Replace hardcoded colors/fonts with design tokens.", "Add or update #Preview variants.", "Report changes and remaining design debt."],
                      systemAssets: ["DesignSystemTokens", "SwiftUIArchitecture"]),
        BuiltInAction(id: "localize", title: "Localization Pass", subtitle: "Find hardcoded user-facing strings and move them into String Catalogs",
                      icon: "globe", category: "Internationalization", argumentPlaceholder: "Optional path...",
                      preflight: [.init("localization_audit")],
                      workflow: ["Review the audit results below.", "Wrap user-facing literals with String(localized:) / LocalizedStringKey and translator comments.", "Use plural variations and FormatStyle for numbers and dates.", "Build and check the String Catalog.", "Report counts of strings moved and remaining issues."],
                      systemAssets: ["LocalizationStringCatalogs", "LocalizingApps"]),
        BuiltInAction(id: "readme", title: "Refresh README", subtitle: "Rewrite the README from the real project structure with verified commands",
                      icon: "book.closed.fill", category: "Documentation", argumentPlaceholder: "Optional focus...",
                      preflight: [.init("readme_locate"), .init("workspace_extension_stats")],
                      workflow: ["Read the current README and the package/project manifests.", "Write purpose, features, requirements, quick start, usage, configuration, contributing, license.", "Verify every command you include actually works.", "Check links with http_status_check.", "Show the diff and explain what changed."],
                      systemAssets: ["DocCAndDocumentationStandards", "DocumentationWithGitHub"]),
        BuiltInAction(id: "architecture", title: "Architecture Map", subtitle: "Map modules, dependencies and data flow of the codebase",
                      icon: "square.stack.3d.up.fill", category: "Planning", argumentPlaceholder: "Optional subsystem...",
                      preflight: [.init("workspace_extension_stats"), .init("swift_list_imports")],
                      workflow: ["Identify modules/targets and their responsibilities.", "Derive the dependency graph from imports and the package manifest.", "Trace one representative feature end to end.", "Note layering violations, cycles and hotspots.", "Present a concise map (Mermaid diagram plus bullets) grounded in real files."],
                      systemAssets: ["ModularAppDesign", "CleanArchitectureSwift"]),
        BuiltInAction(id: "triage", title: "Bug Triage", subtitle: "Reproduce, localize and explain a bug before proposing a fix",
                      icon: "ladybug.fill", category: "Debugging", argumentPlaceholder: "Bug description or error message...",
                      preflight: [.init("git_last_commit"), .init("git_diff_stat_range")],
                      workflow: ["Restate the bug and define a reproduction (command or test).", "Search for the failing code (search tools, git_log_pickaxe for recent changes).", "Form and test hypotheses one at a time.", "Write a failing regression test, then fix the root cause.", "Report cause, fix and verification."],
                      systemAssets: ["ErrorRecoveryProtocols", "CrashLogAnalysisForAssist"]),
        BuiltInAction(id: "modernize", title: "Modernize Code", subtitle: "Migrate legacy APIs (completion handlers, NavigationView, ObservableObject) to modern Swift",
                      icon: "arrow.triangle.2.circlepath", category: "Swift", argumentPlaceholder: "Optional path...",
                      preflight: [.init("scan_navigation_view_deprecated"), .init("scan_dispatch_main_queue"), .init("scan_observable_state")],
                      workflow: ["Prioritize findings by user impact and risk.", "Migrate one pattern at a time (async/await, NavigationStack, @Observable).", "Keep behavior identical and build after each step.", "Run tests for touched modules.", "Report migrated sites and anything deferred."],
                      systemAssets: ["CombineToAsyncAwait", "MVVMAndStateManagement"]),
        BuiltInAction(id: "release", title: "Release Readiness", subtitle: "Check versioning, changelog, signing, privacy and tests before shipping",
                      icon: "paperplane.circle.fill", category: "Build", argumentPlaceholder: "Target version...",
                      preflight: [.init("git_describe_version"), .init("git_untracked_files"), .init("scan_todo_fixme_markers")],
                      workflow: ["Confirm the working tree is clean and the version is correct.", "Run the full build and test suite in Release configuration.", "Check privacy manifests, entitlements and signing (codesign_inspect).", "Ensure the changelog covers the release.", "Produce a go/no-go checklist with evidence for each item."],
                      systemAssets: ["AppStoreSubmissionChecklist", "CodeSigningAndNotarization", "PrivacyManifests"]),
    ]

    public static var commandNames: [String] { actions.map(\.command) }

    public static func action(for command: String) -> BuiltInAction? {
        let key = command.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let id = key.hasPrefix("/") ? String(key.dropFirst()) : key
        return actions.first { $0.id == id }
    }

    /// Prompt without evidence (for synchronous callers such as the Meta palette).
    /// The action's specification markdown bundled in `SC Skills/<id>.md`
    /// (SwiftPM keeps the folder; Xcode app builds flatten it into Resources).
    public static func specification(for action: BuiltInAction) -> String? {
        let name = action.id + ".md"
        let bases = [Bundle.module.resourceURL, Bundle.main.resourceURL].compactMap { $0 }
        for base in bases {
            for url in [base.appendingPathComponent("SC Skills", isDirectory: true).appendingPathComponent(name),
                        base.appendingPathComponent(name)] {
                if let text = try? String(contentsOf: url, encoding: .utf8), !text.isEmpty {
                    return text
                }
            }
        }
        return nil
    }

    public static func basePrompt(for action: BuiltInAction, argument: String?) -> String {
        let target = argument?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var lines = ["### BUILT-IN ACTION: \(action.command) — \(action.title)"]
        lines.append("Goal: \(action.subtitle).")
        if !target.isEmpty { lines.append("Scope / input: \(target)") }
        lines.append("")
        lines.append("Workflow:")
        lines.append(contentsOf: action.workflow.enumerated().map { "\($0.offset + 1). \($0.element)" })
        lines.append("")
        lines.append("Before starting, load guidance with system_asset_read for: \(action.systemAssets.joined(separator: ", ")).")
        lines.append("Use real SwiftCode tools for every step (tool_catalog_search finds them). Never fabricate results; verify before reporting.")
        if let spec = specification(for: action) {
            lines.append("")
            lines.append("### Action specification (SC Skills/\(action.id).md)")
            lines.append(spec)
        }
        return lines.joined(separator: "\n")
    }

    /// Runs the action's read-only preflight tools against the active workspace and
    /// returns the full prompt including that evidence.
    @MainActor
    public static func prompt(for action: BuiltInAction, argument: String?) async -> String {
        var prompt = basePrompt(for: action, argument: argument)
        let evidence = await runPreflight(action, argument: argument)
        if !evidence.isEmpty {
            prompt += "\n\n### Workspace evidence (collected by SwiftCode)\n" + evidence
        }
        return prompt
    }

    @MainActor
    public static func runPreflight(_ action: BuiltInAction, argument: String?) async -> String {
        let registry = AssistToolRegistry.shared
        let root = AssistContextBuilder.resolvedWorkspaceRoot(project: ProjectSessionStore.shared.activeProject)
        let builder = AssistContextBuilder(
            logger: AssistLogger(),
            permissions: AssistPermissionsManager(),
            memory: AssistMemoryGraph(),
            fileSystem: AssistFileSystem(workspaceRoot: root),
            git: AssistGitManager(project: ProjectSessionStore.shared.activeProject)
        )
        let context = builder.buildContext(sessionId: UUID())
        var sections: [String] = []
        for step in action.preflight {
            guard let tool = registry.allTools.first(where: { $0.id == step.toolID }), tool.isReadOnly else { continue }
            var input: [String: Any] = step.arguments
            if let arg = argument?.trimmingCharacters(in: .whitespacesAndNewlines), !arg.isEmpty,
               tool.parametersSchema.properties?["path"] != nil,
               AssistWorkspacePaths.resolve(arg, workspaceRoot: root).map({ FileManager.default.fileExists(atPath: $0.path) }) == true {
                input["path"] = arg
            }
            let result: AssistToolResult
            do { result = try await tool.execute(input: input, context: context) } catch { continue }
            let body = AssistTextFormat.truncated(result.success ? result.output : (result.error ?? result.output), limit: 3_000).0
            sections.append("#### \(tool.id)\n```\n\(body)\n```")
        }
        return sections.joined(separator: "\n\n")
    }

    @MainActor
    public static func execute(command: String, argument: String?) async -> SlashExecutionResult? {
        guard let action = action(for: command) else { return nil }
        let prompt = await prompt(for: action, argument: argument)
        return SlashExecutionResult(
            command: action.command,
            messageToInsert: prompt,
            feedbackText: "**\(action.title)** — \(action.subtitle). Workspace evidence collected; running the workflow.",
            shouldSubmitImmediately: true
        )
    }
}
