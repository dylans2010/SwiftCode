import SwiftUI

@MainActor
struct CollaborationMainView: View {
    @ObservedObject var manager: CollaborationManager
    @State private var selectedTab: CollaborationTab = .overview
    private var currentUserID: String { UIDevice.current.name }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background Gradient
                LinearGradient(colors: [Color(red: 0.05, green: 0.05, blue: 0.1), Color(red: 0.1, green: 0.1, blue: 0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    headerCards

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(CollaborationTab.allCases) { tab in
                                TabButton(tab: tab, isSelected: selectedTab == tab) {
                                    selectedTab = tab
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    selectedContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .padding(.vertical)
            }
            .collaborationFeedback(message: manager.workspaces.lastSuccessMessage, icon: "checkmark.circle.fill", color: .green)
            .collaborationFeedback(message: manager.workspaces.lastErrorMessage, icon: "exclamationmark.triangle.fill", color: .red)
            .navigationTitle("Collaboration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
        }
    }

    private struct TabButton: View {
        let tab: CollaborationTab
        let isSelected: Bool
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                VStack(spacing: 6) {
                    Image(systemName: tab.icon)
                        .font(.system(size: 18, weight: isSelected ? .bold : .regular))
                    Text(tab.title)
                        .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                }
                .foregroundStyle(isSelected ? .white : .secondary)
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .background(isSelected ? Color.blue.opacity(0.3) : Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 1)
                )
            }
        }
    }

    private var headerCards: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                statCard(title: "Branch", value: manager.branches.currentBranch.name, icon: "arrow.triangle.branch", subtext: "Active development")
                statCard(title: "Members", value: "\(manager.permissions.memberRoles.count)", icon: "person.3.fill", subtext: "Team members")
                statCard(title: "Reviews", value: "\(manager.reviews.reviews.values.filter { $0.status == .pending }.count)", icon: "checkmark.bubble", subtext: "Pending approval")
                statCard(title: "Alerts", value: "\(manager.notifications.filter { !$0.isRead }.count)", icon: "bell.badge.fill", subtext: "Unread notifications")
            }
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch selectedTab {
        case .overview:
            List {
                Section("Workspace") {
                    NavigationLink { BranchGraphView(manager: manager) } label: { Label("Branch Visualization", systemImage: "point.3.connected.trianglepath.dotted") }
                    NavigationLink { BranchWorkspaceView(manager: manager, actorID: currentUserID) } label: { Label("Branch Workspace", systemImage: "rectangle.split.3x1") }
                    NavigationLink { CommitManagerView(manager: manager, actorID: currentUserID) } label: { Label("Advanced Commit Manager", systemImage: "shippingbox.circle") }
                    NavigationLink { CollaborationPullRequestView(manager: manager, actorID: currentUserID) } label: { Label("Pull Requests", systemImage: "tray.full") }
                    NavigationLink { CollaborationCodeReviewView(manager: manager, actorID: currentUserID) } label: { Label("Code Review Dashboard", systemImage: "checkmark.seal.text.page") }
                    NavigationLink { PushPullManagerView(manager: manager, actorID: currentUserID) } label: { Label("Push/Pull Management", systemImage: "arrow.up.arrow.down.circle") }
                    NavigationLink { MemberManagementView(manager: manager, actorID: currentUserID) } label: { Label("Collaborator Management", systemImage: "person.badge.plus") }
                    NavigationLink { ActivityLogView(manager: manager) } label: { Label("Activity Log & Notifications", systemImage: "clock.badge.checkmark") }
                    NavigationLink { ConflictResolverView(manager: manager, actorID: currentUserID) } label: { Label("Conflict Resolver", systemImage: "arrow.triangle.merge") }
                    NavigationLink { FilePermissionView(manager: manager, actorID: currentUserID) } label: { Label("File Locking & Permissions", systemImage: "lock.doc") }
                }
            }
            .scrollContentBackground(.hidden)
        case .branches:
            BranchWorkspaceView(manager: manager, actorID: currentUserID)
        case .commits:
            CommitManagerView(manager: manager, actorID: currentUserID)
        case .reviews:
            CollaborationCodeReviewView(manager: manager, actorID: currentUserID)
        case .pullRequests:
            CollaborationPullRequestView(manager: manager, actorID: currentUserID)
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

    private func statCard(title: String, value: String, icon: String, subtext: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.blue)
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                Text(subtext)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(width: 160, alignment: .leading)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
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
