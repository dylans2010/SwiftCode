import SwiftUI
import SwiftCodeGitHub
import YcodeIDECore
import YcodeIDEShell









@MainActor
public struct GitHubSocialHubView: View {
    public var project: Project
    public var gitViewModel: GitViewModel

    @State private var tab: HubTab = .pullRequests
    @State private var showSuccess = false
    @State private var successMessage: String?
    @State private var showError = false
    @State private var errorMessage: String?

    public init(project: Project, gitViewModel: GitViewModel) {
        self.project = project
        self.gitViewModel = gitViewModel
    }

    public enum HubTab: String, CaseIterable, Identifiable {
        case dashboard = "Dashboard"
        case pullRequests = "Pull Requests"
        case issues = "Issues"
        case notifications = "Notifications"
        case organizations = "Organizations"
        case activity = "Activity"
        case codeSearch = "Code Search"
        case integration = "Integration"
        case inspector = "Inspector"
        case remoteBrowser = "Remote Browser"
        case discussions = "Discussions"

        public var id: String { rawValue }

        public var icon: String {
            switch self {
            case .dashboard: return "rectangle.grid.2x2"
            case .pullRequests: return "arrow.triangle.pull"
            case .issues: return "exclamationmark.circle"
            case .notifications: return "bell"
            case .organizations: return "building.2"
            case .activity: return "bolt"
            case .codeSearch: return "magnifyingglass"
            case .integration: return "folder.fill.badge.gearshape"
            case .inspector: return "info.circle"
            case .remoteBrowser: return "globe"
            case .discussions: return "bubble.left.and.bubble.right"
            }
        }
    }

    public var body: some View {
        TabView(selection: $tab) {
            dashboardTab.tag(HubTab.dashboard)
            PullRequestsView(
                project: project,
                showSuccess: $showSuccess,
                successMessage: $successMessage,
                showError: $showError,
                errorMessage: $errorMessage
            )
            .tabItem { Label("Pull Requests", systemImage: "arrow.triangle.pull") }
            .tag(HubTab.pullRequests)
            GitHubIssuesView(
                project: project,
                showSuccess: $showSuccess,
                successMessage: $successMessage,
                showError: $showError,
                errorMessage: $errorMessage
            )
            .tabItem { Label("Issues", systemImage: "exclamationmark.circle") }
            .tag(HubTab.issues)
            NotificationsView()
                .tabItem { Label("Notifications", systemImage: "bell") }
                .tag(HubTab.notifications)
            OrganizationsView()
                .tabItem { Label("Organizations", systemImage: "building.2") }
                .tag(HubTab.organizations)
            ActivityFeedView(project: project)
                .tabItem { Label("Activity", systemImage: "bolt") }
                .tag(HubTab.activity)
            GitHubCodeSearchView(project: project)
                .tabItem { Label("Code Search", systemImage: "magnifyingglass") }
                .tag(HubTab.codeSearch)
            GitHubIntegrationView(project: project)
                .tabItem { Label("Integration", systemImage: "folder.fill.badge.gearshape") }
                .tag(HubTab.integration)
            GitHubInspector(project: project, gitViewModel: gitViewModel)
                .tabItem { Label("Inspector", systemImage: "info.circle") }
                .tag(HubTab.inspector)
            GitHubRemoteBrowserView()
                .tabItem { Label("Remote Browser", systemImage: "globe") }
                .tag(HubTab.remoteBrowser)
            DiscussionsView(project: project)
                .tabItem { Label("Discussions", systemImage: "bubble.left.and.bubble.right") }
                .tag(HubTab.discussions)
        }
        .alert("Success", isPresented: $showSuccess, presenting: successMessage) { _ in
            Button("OK") {}
        } message: { msg in Text(msg) }
        .alert("Error", isPresented: $showError, presenting: errorMessage) { _ in
            Button("OK") {}
        } message: { msg in Text(msg) }
    }

    private var dashboardTab: some View {
        Group {
            if let repository = GitRepository(containing: project.directoryURL) {
                RepositoryDashboardView(
                    repository: repository,
                    client: GitHubTokenProvider.client(),
                    remote: RepositoryContext.shared.ownerAndRepo,
                    onNavigateToSection: { item in
                        switch item {
                        case .pullRequests: tab = .pullRequests
                        case .issues: tab = .issues
                        case .branches: tab = .integration
                        case .releases: tab = .remoteBrowser
                        default: tab = .dashboard
                        }
                    }
                )
            } else {
                ContentUnavailableView(
                    "No Local Repository",
                    systemImage: "folder.badge.questionmark",
                    description: Text("This project has no local git repository, so there is no dashboard to show. The other tabs work from the linked GitHub remote.")
                )
            }
        }
        .tabItem { Label("Dashboard", systemImage: "rectangle.grid.2x2") }
    }
}
