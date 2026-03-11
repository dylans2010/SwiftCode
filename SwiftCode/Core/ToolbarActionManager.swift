import Foundation

/// Central manager that maps toolbar button IDs to their correct destination.
/// This fixes the bug where buttons open wrong views or feel laggy by providing
/// a single authoritative mapping from tool IDs to sheet destinations.
@MainActor
final class ToolbarActionManager {
    static let shared = ToolbarActionManager()
    private init() {}

    enum SheetDestination: String {
        case fileNavigator
        case aiAgent
        case buildStatus
        case gitHub
        case codeSearch
        case errorsPanel
        case dependencyManager
        case commandPalette
        case goToLine
        case symbolNavigator
        case diffViewer
        case toolbarCustomization
        case projectSettings
        case buildLogs
        case minimapSettings
        case sfSymbolsBrowser
        case settings
        // New destinations
        case terminal
        case codeReview
        case gitHistory
        case filePreview
        case gitHubIssues
        case complexityAnalyzer
        case symbolOutline
        case localSimulation
        case pluginManager
        case projectTemplates
    }

    /// Returns the correct sheet destination for a toolbar tool ID.
    func destination(for toolId: String) -> SheetDestination? {
        switch toolId {
        // Navigation
        case "file_navigator":
            return .fileNavigator
        case "code_search", "project_index", "project_analyzer":
            return .codeSearch
        case "symbol_navigator":
            return .symbolNavigator
        case "go_to_line":
            return .goToLine

        // AI
        case "ai_agent", "ai_code_gen", "ai_code_fix", "ai_refactor":
            return .aiAgent

        // Build
        case "build_trigger", "build_status":
            return .buildStatus
        case "build_logs":
            return .buildLogs

        // Git
        case "github_actions", "commit_changes", "push_repo", "pull_repo":
            return .gitHub

        // Diagnostics
        case "errors_viewer":
            return .errorsPanel

        // Project
        case "dependency_manager", "install_dependency", "update_dependencies":
            return .dependencyManager
        case "project_settings":
            return .projectSettings

        // Tools
        case "command_palette":
            return .commandPalette
        case "diff_viewer":
            return .diffViewer
        case "minimap_settings":
            return .minimapSettings
        case "sf_symbols_browser":
            return .sfSymbolsBrowser

        // File operations go to file navigator
        case "create_file", "create_folder", "rename_file", "delete_file", "refactor_file":
            return .fileNavigator

        // New features
        case "terminal":
            return .terminal
        case "code_review":
            return .codeReview
        case "git_history":
            return .gitHistory
        case "file_preview":
            return .filePreview
        case "github_issues":
            return .gitHubIssues
        case "complexity_analyzer":
            return .complexityAnalyzer
        case "symbol_outline":
            return .symbolOutline
        case "local_simulation":
            return .localSimulation
        case "terminal":
            return .terminal
        case "git_history":
            return .gitHistory
        case "project_templates":
            return .projectTemplates
        case "symbol_outline":
            return .symbolOutline
        case "plugin_manager":
            return .pluginManager
        case "file_preview":
            return .filePreview

        default:
            return nil
        }
    }
}
