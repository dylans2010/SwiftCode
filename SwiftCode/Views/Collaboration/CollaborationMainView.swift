import SwiftUI

struct CollaborationMainView: View {
    @ObservedObject var manager: CollaborationManager
    @State private var selectedTab: CollaborationTab = .overview
    private let currentUserID = UIDevice.current.name

    var body: some View {
        VStack(spacing: 16) {
            headerCards

            Picker("Section", selection: $selectedTab) {
                ForEach(CollaborationTab.allCases) { tab in
                    Label(tab.title, systemImage: tab.icon).tag(tab)
                }
            }
            .pickerStyle(.menu) // Using menu style for better fit of 11 items
            .padding(.horizontal)

            selectedContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(.vertical)
        .background(
            LinearGradient(colors: [Color(.systemBackground), Color.blue.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
        )
        .navigationTitle("Collaboration")
        .toolbar { toolbarContent }
    }

    private var headerCards: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                statCard(title: "Branch", value: manager.branches.currentBranch.name, icon: "arrow.triangle.branch")
                statCard(title: "Members", value: "\(manager.permissions.memberRoles.count)", icon: "person.3.fill")
                statCard(title: "PRs", value: "\(manager.reviews.pullRequests.filter { $0.status == .open }.count)", icon: "arrow.triangle.pull")
                statCard(title: "Notifications", value: "\(manager.activity.notifications.filter { !$0.isRead }.count)", icon: "bell.badge.fill")
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
                    NavigationLink { CommitManagerView(manager: manager, actorID: currentUserID) } label: { Label("Advanced Commit Manager", systemImage: "shippingbox.circle") }
                    NavigationLink { CodeReviewView(manager: manager, actorID: currentUserID) } label: { Label("Code Review Dashboard", systemImage: "checkmark.seal.text.page") }
                    NavigationLink { PullRequestView(manager: manager, actorID: currentUserID) } label: { Label("Pull Requests", systemImage: "arrow.triangle.pull") }
                    NavigationLink { PushPullManagerView(manager: manager, actorID: currentUserID) } label: { Label("Push/Pull Management", systemImage: "arrow.up.arrow.down.circle") }
                    NavigationLink { InviteMembersView(manager: manager, actorID: currentUserID) } label: { Label("Invite Members", systemImage: "person.badge.plus") }
                    NavigationLink { ActivityLogView(manager: manager) } label: { Label("Activity Log & Notifications", systemImage: "clock.badge.checkmark") }
                    NavigationLink { ConflictResolverView(manager: manager, actorID: currentUserID) } label: { Label("Conflict Resolver", systemImage: "arrow.triangle.merge") }
                    NavigationLink { MemberManagementView(manager: manager, actorID: currentUserID) } label: { Label("Member Management", systemImage: "person.2.fill") }
                    NavigationLink { FilePermissionView(manager: manager, actorID: currentUserID) } label: { Label("File Locking & Permissions", systemImage: "lock.doc") }
                    NavigationLink { DiffViewerView(filePath: "Sources/Shared/Project.swift", diff: "+ example change") } label: { Label("Diff Viewer", systemImage: "doc.text.magnifyingglass") }
                }
            }
            .scrollContentBackground(.hidden)
        case .branches:
            BranchGraphView(manager: manager)
        case .commits:
            CommitManagerView(manager: manager, actorID: currentUserID)
        case .prs:
            PullRequestView(manager: manager, actorID: currentUserID)
        case .reviews:
            CodeReviewView(manager: manager, actorID: currentUserID)
        case .sync:
            PushPullManagerView(manager: manager, actorID: currentUserID)
        case .invite:
            InviteMembersView(manager: manager, actorID: currentUserID)
        case .activity:
            ActivityLogView(manager: manager)
        case .conflicts:
            ConflictResolverView(manager: manager, actorID: currentUserID)
        case .members:
            MemberManagementView(manager: manager, actorID: currentUserID)
        case .files:
            FilePermissionView(manager: manager, actorID: currentUserID)
        case .diff:
            DiffViewerView(filePath: "Overview", diff: "+ Global Changes\n- Old System")
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                manager.undo(actorID: currentUserID)
            } label: {
                Label("Undo", systemImage: "arrow.uturn.backward.circle.fill")
            }
            .tint(.orange)

            Button {
                manager.redo(actorID: currentUserID)
            } label: {
                Label("Redo", systemImage: "arrow.uturn.forward.circle.fill")
            }
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
    case overview, branches, commits, prs, reviews, sync, invite, activity, conflicts, members, files, diff
    var id: String { rawValue }
    var title: String {
        switch self {
        case .prs: return "PRs"
        case .sync: return "Sync"
        case .files: return "Permissions"
        default: return rawValue.capitalized
        }
    }
    var icon: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .branches: return "arrow.triangle.branch"
        case .commits: return "shippingbox"
        case .prs: return "arrow.triangle.pull"
        case .reviews: return "text.badge.checkmark"
        case .sync: return "arrow.up.arrow.down"
        case .invite: return "person.badge.plus"
        case .activity: return "clock"
        case .conflicts: return "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90"
        case .members: return "person.2"
        case .files: return "lock.doc"
        case .diff: return "doc.text.magnifyingglass"
        }
    }
}
