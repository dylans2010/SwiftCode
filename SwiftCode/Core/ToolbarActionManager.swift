import Foundation

/// Central manager that maps toolbar button IDs to their correct destination.
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
        case terminal
        case codeReview
        case gitHistory
        case filePreview
        case gitHubIssues
        case complexityAnalyzer
        case symbolOutline
        case localSimulation
        case pluginManager
    }

    func destination(for toolId: String) -> SheetDestination? {
        switch toolId {
        case "file_navigator":
            return .fileNavigator
        case "code_search", "project_index", "project_analyzer":
            return .codeSearch
        case "symbol_navigator":
            return .symbolNavigator
        case "go_to_line":
            return .goToLine

        case "ai_code_gen":
            return .aiAgent

        case "build_trigger", "build_status":
            return .buildStatus
        case "build_logs":
            return .buildLogs

        case "github_actions":
            return .gitHub

        case "errors_viewer":
            return .errorsPanel

        case "dependency_manager", "install_dependency":
            return .dependencyManager
        case "project_settings":
            return .projectSettings

        case "command_palette":
            return .commandPalette
        case "diff_viewer":
            return .diffViewer
        case "minimap_settings":
            return .minimapSettings
        case "sf_symbols_browser":
            return .sfSymbolsBrowser

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
        case "plugin_manager":
            return .pluginManager

        default:
            return nil
        }
    }
}
