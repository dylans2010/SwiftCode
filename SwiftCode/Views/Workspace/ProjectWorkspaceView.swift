import SwiftUI

struct ProjectWorkspaceView: View {
    let project: Project
    @EnvironmentObject private var projectManager: ProjectManager
    @StateObject private var toolbarManager = ToolbarManager.shared

    // Sheet state
    @State private var showNavigatorSheet = false
    @State private var showAISheet = false
    @State private var showBuildStatus = false
    @State private var showGitHubSheet = false
    @State private var showSettingsSheet = false
    @State private var showCodeSearch = false
    @State private var showErrorsPanel = false
    @State private var showDependencyManager = false
    @State private var showCommandPalette = false
    @State private var showGoToLine = false
    @State private var showSymbolNavigator = false
    @State private var showDiffViewer = false
    @State private var showToolbarCustomization = false
    @State private var showProjectSettings = false
    @State private var showBuildLogs = false
    @State private var showMinimapSettings = false
    @State private var showSFSymbolsBrowser = false
    // New sheets
    @State private var showTerminal = false
    @State private var showCodeReview = false
    @State private var showGitHistory = false
    @State private var showFilePreview = false
    @State private var showGitHubIssues = false
    @State private var showComplexityAnalyzer = false
    @State private var showSymbolOutline = false

    var body: some View {
        ZStack {
            Color(red: 0.10, green: 0.10, blue: 0.14).ignoresSafeArea()

            VStack(spacing: 0) {
                // Toolbar
                workspaceToolbar
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)

                Divider().opacity(0.3)

                // Code Editor fills the full screen
                CodeEditorView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationBarHidden(true)
        // File Navigator sheet
        .sheet(isPresented: $showNavigatorSheet) {
            NavigationStack {
                FileNavigatorView(project: project)
                    .background(Color(red: 0.12, green: 0.12, blue: 0.16))
                    .navigationTitle("Files")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showNavigatorSheet = false }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        // Auto-dismiss navigator when a file is selected
        .onChange(of: projectManager.activeFileNode) {
            if projectManager.activeFileNode != nil {
                showNavigatorSheet = false
            }
        }
        // AI Assistant sheet
        .sheet(isPresented: $showAISheet) {
            AIAssistantView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showBuildStatus) {
            BuildStatusView(owner: ownerFromRepo, repo: repoNameFromRepo)
        }
        .sheet(isPresented: $showGitHubSheet) {
            GitHubIntegrationView(project: project)
        }
        .sheet(isPresented: $showSettingsSheet) {
            GeneralSettingsView()
        }
        // New sheets
        .sheet(isPresented: $showCodeSearch) {
            CodeSearchView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showErrorsPanel) {
            ErrorsPanelView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showDependencyManager) {
            DependencyManagerView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showCommandPalette) {
            CommandPaletteView { action in
                handleCommandAction(action)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showGoToLine) {
            GoToLineView { _ in }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSymbolNavigator) {
            SymbolNavigatorView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showDiffViewer) {
            DiffViewerView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showToolbarCustomization) {
            ToolbarCustomizationView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showProjectSettings) {
            ProjectSettingsView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showBuildLogs) {
            BuildLogsView(owner: ownerFromRepo, repo: repoNameFromRepo)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showMinimapSettings) {
            MinimapSettingsView()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSFSymbolsBrowser) {
            SFSymbolBrowserView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        // New feature sheets
        .sheet(isPresented: $showTerminal) {
            TerminalView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showCodeReview) {
            CodeReviewView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showGitHistory) {
            GitHistoryView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showFilePreview) {
            FilePreviewView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showGitHubIssues) {
            GitHubIssuesView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showComplexityAnalyzer) {
            ComplexityAnalyzerView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSymbolOutline) {
            SymbolOutlineView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Toolbar

    private var workspaceToolbar: some View {
        HStack(spacing: 10) {
            // Back
            Button {
                projectManager.closeProject()
            } label: {
                Image(systemName: "chevron.left")
                    .imageScale(.medium)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Divider().frame(height: 20)

            // Scrollable enabled tools
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(toolbarManager.enabledTools) { tool in
                        Button {
                            handleToolbarAction(tool.id)
                        } label: {
                            Image(systemName: tool.icon)
                                .imageScale(.medium)
                                .foregroundStyle(iconColor(for: tool.id))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Divider().frame(height: 20)

            // Toolbar customization
            Button {
                showToolbarCustomization = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .imageScale(.medium)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private func iconColor(for toolId: String) -> Color {
        switch toolId {
        case "file_navigator", "create_file", "create_folder": return .orange
        case "ai_agent", "ai_code_gen", "ai_code_fix", "ai_refactor": return .purple
        case "github_actions", "commit_changes", "push_repo", "pull_repo": return .blue
        case "build_trigger", "build_status", "build_logs": return .orange
        case "errors_viewer": return .red
        case "dependency_manager", "install_dependency", "update_dependencies": return .teal
        case "code_search", "symbol_navigator", "project_index", "go_to_line": return .cyan
        case "sf_symbols_browser": return .indigo
        default: return .secondary
        }
    }

    // MARK: - Tool Actions

    private func handleToolbarAction(_ toolId: String) {
        guard let destination = ToolbarActionManager.shared.destination(for: toolId) else { return }
        openSheet(for: destination)
    }

    private func openSheet(for destination: ToolbarActionManager.SheetDestination) {
        switch destination {
        case .fileNavigator: showNavigatorSheet = true
        case .aiAgent: showAISheet = true
        case .buildStatus: showBuildStatus = true
        case .gitHub: showGitHubSheet = true
        case .codeSearch: showCodeSearch = true
        case .errorsPanel: showErrorsPanel = true
        case .dependencyManager: showDependencyManager = true
        case .commandPalette: showCommandPalette = true
        case .goToLine: showGoToLine = true
        case .symbolNavigator: showSymbolNavigator = true
        case .diffViewer: showDiffViewer = true
        case .toolbarCustomization: showToolbarCustomization = true
        case .projectSettings: showProjectSettings = true
        case .buildLogs: showBuildLogs = true
        case .minimapSettings: showMinimapSettings = true
        case .sfSymbolsBrowser: showSFSymbolsBrowser = true
        case .settings: showSettingsSheet = true
        case .terminal: showTerminal = true
        case .codeReview: showCodeReview = true
        case .gitHistory: showGitHistory = true
        case .filePreview: showFilePreview = true
        case .gitHubIssues: showGitHubIssues = true
        case .complexityAnalyzer: showComplexityAnalyzer = true
        case .symbolOutline: showSymbolOutline = true
        }
    }

    // MARK: - Command Palette Actions

    private func handleCommandAction(_ action: CommandPaletteView.CommandAction) {
        switch action {
        case .createFile, .createFolder: showNavigatorSheet = true
        case .searchProject: showCodeSearch = true
        case .runAgent: showAISheet = true
        case .installDependency, .openDependencies: showDependencyManager = true
        case .openSettings: showSettingsSheet = true
        case .runBuild: showBuildStatus = true
        case .goToLine: showGoToLine = true
        case .openSymbolNav: showSymbolNavigator = true
        case .openDiffViewer: showDiffViewer = true
        case .openErrors: showErrorsPanel = true
        case .openBuildLogs: showBuildLogs = true
        case .customizeToolbar: showToolbarCustomization = true
        case .openProjectSettings: showProjectSettings = true
        case .openMinimap: showMinimapSettings = true
        }
    }

    // MARK: - Helpers

    private var ownerFromRepo: String {
        guard let repo = (projectManager.activeProject ?? project).githubRepo else { return "" }
        return String(repo.split(separator: "/").first ?? "")
    }

    private var repoNameFromRepo: String {
        guard let repo = (projectManager.activeProject ?? project).githubRepo else { return "" }
        return String(repo.split(separator: "/").last ?? "")
    }
}
