import SwiftUI

struct CollaborationMainView: View {
    @ObservedObject var manager: CollaborationManager
    @State private var selectedTab: CollaborationTab = .overview
    private let currentUserID = UIDevice.current.name

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                headerCards
                Picker("Section", selection: $selectedTab) {
                    ForEach(CollaborationTab.allCases) { tab in
                        Label(tab.title, systemImage: tab.icon).tag(tab)
                    }
                }
                .pickerStyle(.segmented)

                selectedContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .padding()
            .background(
                LinearGradient(colors: [Color(.systemBackground), Color.blue.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
            )
            .navigationTitle("Collaboration")
            .toolbar { toolbarContent }
        }
    }

    private var headerCards: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                statCard(title: "Branch", value: manager.branches.currentBranch.name, icon: "arrow.triangle.branch")
                statCard(title: "Members", value: "\(manager.permissions.memberRoles.count)", icon: "person.3.fill")
                statCard(title: "Pending Reviews", value: "\(manager.reviews.reviews.values.filter { $0.status == .pending }.count)", icon: "checkmark.bubble")
                statCard(title: "Notifications", value: "\(manager.notifications.filter { !$0.isRead }.count)", icon: "bell.badge.fill")
            }
        }
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch selectedTab {
        case .overview:
            List {
                Section("Workspace") {
                    NavigationLink { BranchGraphView(manager: manager) } label: { Label("Branch Visualization", systemImage: "point.3.connected.trianglepath.dotted") }
                    NavigationLink { CommitManagerView(manager: manager, actorID: currentUserID) } label: { Label("Advanced Commit Manager", systemImage: "shippingbox.circle") }
                    NavigationLink { PullRequestView(manager: manager, actorID: currentUserID) } label: { Label("Pull Requests", systemImage: "tray.full") }
                    NavigationLink { CodeReviewView(manager: manager, actorID: currentUserID) } label: { Label("Code Review Dashboard", systemImage: "checkmark.seal.text.page") }
                    NavigationLink { PushPullManagerView(manager: manager, actorID: currentUserID) } label: { Label("Push/Pull Management", systemImage: "arrow.up.arrow.down.circle") }
                    NavigationLink { MemberManagementView(manager: manager, actorID: currentUserID) } label: { Label("Collaborator Management", systemImage: "person.badge.plus") }
                    NavigationLink { ActivityLogView(manager: manager) } label: { Label("Activity Log & Notifications", systemImage: "clock.badge.checkmark") }
                    NavigationLink { ConflictResolverView(manager: manager, actorID: currentUserID) } label: { Label("Conflict Resolver", systemImage: "arrow.triangle.merge") }
                    NavigationLink { FilePermissionView(manager: manager, actorID: currentUserID) } label: { Label("File Locking & Permissions", systemImage: "lock.doc") }
                }
            }
            .scrollContentBackground(.hidden)
        case .branches:
            BranchGraphView(manager: manager)
        case .commits:
            CommitManagerView(manager: manager, actorID: currentUserID)
        case .reviews:
            CodeReviewView(manager: manager, actorID: currentUserID)
        case .pullRequests:
            PullRequestView(manager: manager, actorID: currentUserID)
        case .sync:
            PushPullManagerView(manager: manager, actorID: currentUserID)
        case .people:
            MemberManagementView(manager: manager, actorID: currentUserID)
        case .activity:
            ActivityLogView(manager: manager)
        case .conflicts:
            ConflictResolverView(manager: manager, actorID: currentUserID)
        case .files:
            FilePermissionView(manager: manager, actorID: currentUserID)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                if manager.commits.canUndo { _ = manager.commits.undo() }
            } label: {
                Label("Undo", systemImage: "arrow.uturn.backward.circle.fill")
            }
            .disabled(!manager.commits.canUndo)
            .tint(.orange)

            Button {
                if manager.commits.canRedo { _ = manager.commits.redo() }
            } label: {
                Label("Redo", systemImage: "arrow.uturn.forward.circle.fill")
            }
            .disabled(!manager.commits.canRedo)
            .tint(.blue)
        }
    }

    private func statCard(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .padding()
        .frame(width: 170, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private enum CollaborationTab: String, CaseIterable, Identifiable {
    case overview, branches, commits, pullRequests, reviews, sync, people, activity, conflicts, files
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var icon: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .branches: return "arrow.triangle.branch"
        case .commits: return "shippingbox"
        case .pullRequests: return "tray.full"
        case .reviews: return "text.badge.checkmark"
        case .sync: return "arrow.up.arrow.down"
        case .people: return "person.3"
        case .activity: return "clock"
        case .conflicts: return "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90"
        case .files: return "lock.doc"
        }
    }
}
