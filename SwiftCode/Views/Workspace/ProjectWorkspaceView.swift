import SwiftUI

struct ProjectWorkspaceView: View {
    let project: Project
    @EnvironmentObject private var projectManager: ProjectManager

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
    @State private var showLocalSimulation = false
    @State private var showPluginManager = false
    @State private var showSearchDocumentation = false
    @State private var showSnippetsLibrary = false
    @State private var showCodeRefactoring = false
    @State private var showErrorDiagnostics = false
    @State private var showExtensionMarketplace = false
    @State private var showCodeIntelligence = false
    @State private var showCrashLogAnalyzer = false
    @State private var showProjectDependencyGraph = false
    @State private var showSymbolIndex = false
    @State private var showCodeMetrics = false
    @State private var showDocumentationBrowser = false
    @State private var showWorkspaceProfiles = false
    @State private var showAssetManager = false
    @State private var showDebugTools = false
    @State private var showProjectTemplates = false
    @State private var showDeployments = false
    @State private var showTestTools = false
    @State private var showAllToolsSheet = false
    @State private var showPaywall = false
    @State private var showCollaboration = false

    var body: some View {
        ZStack {
            Color(red: 0.10, green: 0.10, blue: 0.14).ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Header (Project Info & Navigation)
                projectHeader
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)

                Divider().opacity(0.3)

                // Horizontal toolbar at the top for iOS-friendly access
                MainToolbarView()
                    .environmentObject(projectManager)

                Divider().opacity(0.3)

                // Code Editor fills the available space
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
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showBuildStatus) {
            BuildStatusView(project: project, owner: ownerFromRepo, repo: repoNameFromRepo)
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
        .sheet(isPresented: $showLocalSimulation) {
            LocalSimulationView()
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showPluginManager) {
            PluginManagerView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSearchDocumentation) {
            SearchDocumentationView()
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showSnippetsLibrary) { SnippetsLibraryView() }
        .sheet(isPresented: $showCodeRefactoring) { CodeRefactoringView() }
        .sheet(isPresented: $showErrorDiagnostics) { ErrorDiagnosticsView() }
        .sheet(isPresented: $showExtensionMarketplace) { ExtensionMarketplaceView() }
        .sheet(isPresented: $showCodeIntelligence) { CodeIntelligenceView() }
        .sheet(isPresented: $showCrashLogAnalyzer) { CrashLogAnalyzerView() }
        .sheet(isPresented: $showProjectDependencyGraph) { ProjectDependencyGraphView() }
        .sheet(isPresented: $showSymbolIndex) { SymbolIndexView() }
        .sheet(isPresented: $showCodeMetrics) { CodeMetricsDashboardView() }
        .sheet(isPresented: $showDocumentationBrowser) { DocumentationBrowserView() }
        .sheet(isPresented: $showWorkspaceProfiles) { WorkspaceProfilesView() }
        .sheet(isPresented: $showAssetManager) { AssetManagerView() }
        .sheet(isPresented: $showDebugTools) { DebuggingToolsView() }
        .sheet(isPresented: $showProjectTemplates) {
            ProjectTemplateView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showDeployments) {
            DeploymentsView()
                .environmentObject(projectManager)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showTestTools) {
            TestToolsView()
                .environmentObject(projectManager)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAllToolsSheet) {
            ToolbarExpandedPanelView(isPresented: $showAllToolsSheet)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $showCollaboration) {
            if let activeProject = projectManager.activeProject ?? Optional(project) {
                CollaborationMainView(manager: CollaborationSessionStore.shared.manager(for: activeProject))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .toolbarToolActivated)) { notification in
            guard
                let toolId = notification.userInfo?["toolID"] as? String,
                let destination = ToolbarActionManager.shared.destination(for: toolId)
            else { return }

            openSheet(for: destination)
        }
        .onReceive(NotificationCenter.default.publisher(for: .showProjectTemplatesOnOpen)) { _ in
            showProjectTemplates = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowAllToolsPanel"))) { _ in
            showAllToolsSheet = true
        }
    }

    // MARK: - UI Components

    private var projectHeader: some View {
        HStack(spacing: 12) {
            Button {
                projectManager.closeProject()
            } label: {
                Image(systemName: "chevron.left")
                    .imageScale(.medium)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 0) {
                Text(project.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                if let branch = projectManager.activeProject?.githubRepo {
                    Text(branch)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            Spacer()

            // Toolbar customization moved here as a small gear
            Button {
                showToolbarCustomization = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Tool Actions

    private func openSheet(for destination: ToolbarActionManager.SheetDestination) {
        if destination.isPro && !EntitlementManager.shared.proAccess {
            showPaywall = true
            return
        }

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
        case .localSimulation: showLocalSimulation = true
        case .pluginManager: showPluginManager = true
        case .searchDocumentation: showSearchDocumentation = true
        case .snippetsLibrary: showSnippetsLibrary = true
        case .codeRefactoring: showCodeRefactoring = true
        case .errorDiagnostics: showErrorDiagnostics = true
        case .extensionMarketplace: showExtensionMarketplace = true
        case .codeIntelligence: showCodeIntelligence = true
        case .crashLogAnalyzer: showCrashLogAnalyzer = true
        case .projectDependencyGraph: showProjectDependencyGraph = true
        case .symbolIndex: showSymbolIndex = true
        case .codeMetrics: showCodeMetrics = true
        case .documentationBrowser: showDocumentationBrowser = true
        case .workspaceProfiles: showWorkspaceProfiles = true
        case .assetManager: showAssetManager = true
        case .debugTools: showDebugTools = true
        case .deployments: showDeployments = true
        case .testTools: showTestTools = true
        case .collaboration: showCollaboration = true
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


@MainActor
final class CollaborationSessionStore: ObservableObject {
    static let shared = CollaborationSessionStore()

    private var managers: [UUID: CollaborationManager] = [:]

    private init() {}

    func manager(for project: Project, creatorID: String = UIDevice.current.name) -> CollaborationManager {
        if let manager = managers[project.id] {
            return manager
        }

        let manager = CollaborationManager(projectID: project.id, creatorID: creatorID)
        managers[project.id] = manager
        return manager
    }
}

@MainActor
final class CollaborationManager: ObservableObject {
    let projectID: UUID
    let creatorID: String

    @Published private(set) var branches: [String]
    @Published private(set) var currentBranch: String
    @Published private(set) var collaborators: [String]
    @Published private(set) var notifications: [String]
    @Published private(set) var recentActivity: [String]

    init(projectID: UUID, creatorID: String) {
        self.projectID = projectID
        self.creatorID = creatorID
        self.currentBranch = "main"
        self.branches = ["main"]
        self.collaborators = [creatorID]
        self.notifications = ["Collaboration is available for this project."]
        self.recentActivity = ["Workspace ready"]
    }

    func addBranch(named name: String) {
        guard !name.isEmpty, !branches.contains(name) else { return }
        branches.append(name)
        recentActivity.insert("Created branch \(name)", at: 0)
    }

    func addCollaborator(_ collaboratorID: String) {
        guard !collaboratorID.isEmpty, !collaborators.contains(collaboratorID) else { return }
        collaborators.append(collaboratorID)
        notifications.insert("Invited \(collaboratorID)", at: 0)
        recentActivity.insert("Added collaborator \(collaboratorID)", at: 0)
    }

    func recordSync() {
        notifications.insert("Project synced successfully.", at: 0)
        recentActivity.insert("Synced branch \(currentBranch)", at: 0)
    }
}

struct CollaborationMainView: View {
    @ObservedObject var manager: CollaborationManager
    @State private var newBranchName = ""
    @State private var invitee = ""
    @State private var selectedTab: CollaborationFallbackTab = .overview

    var body: some View {
        List {
            Picker("Section", selection: $selectedTab) {
                ForEach(CollaborationFallbackTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)

            switch selectedTab {
            case .overview:
                overviewSection
            case .branches:
                branchesSection
            case .people:
                peopleSection
            case .activity:
                activitySection
            }
        }
        .navigationTitle("Collaboration")
    }

    private var overviewSection: some View {
        Section("Overview") {
            LabeledContent("Current Branch", value: manager.currentBranch)
            LabeledContent("Branches", value: "\(manager.branches.count)")
            LabeledContent("Collaborators", value: "\(manager.collaborators.count)")
            LabeledContent("Notifications", value: "\(manager.notifications.count)")

            Button("Sync Now") {
                manager.recordSync()
            }
        }
    }

    private var branchesSection: some View {
        Section("Branches") {
            ForEach(manager.branches, id: \.self) { branch in
                Text(branch)
            }

            TextField("New branch", text: $newBranchName)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Button("Create Branch") {
                let trimmed = newBranchName.trimmingCharacters(in: .whitespacesAndNewlines)
                manager.addBranch(named: trimmed)
                newBranchName = ""
            }
        }
    }

    private var peopleSection: some View {
        Section("Collaborators") {
            ForEach(manager.collaborators, id: \.self) { collaborator in
                Text(collaborator)
            }

            TextField("Invite collaborator", text: $invitee)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Button("Invite") {
                let trimmed = invitee.trimmingCharacters(in: .whitespacesAndNewlines)
                manager.addCollaborator(trimmed)
                invitee = ""
            }
        }
    }

    private var activitySection: some View {
        Section("Recent Activity") {
            ForEach(manager.recentActivity, id: \.self) { item in
                Text(item)
            }
        }

        Section("Notifications") {
            ForEach(manager.notifications, id: \.self) { item in
                Text(item)
            }
        }
    }
}

private enum CollaborationFallbackTab: String, CaseIterable, Identifiable {
    case overview
    case branches
    case people
    case activity

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return "Overview"
        case .branches: return "Branches"
        case .people: return "People"
        case .activity: return "Activity"
        }
    }
}
