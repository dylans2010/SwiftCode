import SwiftUI

@MainActor
struct CollaborationMainView: View {
    @ObservedObject var manager: CollaborationManager
    @State private var selectedTab: CollaborationTab = .dashboard
    @State private var chatDraft = ""
    private var currentUserID: String { UIDevice.current.name }

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                sidebar
                    .frame(width: 170)
                    .background(.ultraThinMaterial)

                ZStack {
                    LinearGradient(colors: [Color.black.opacity(0.85), Color.blue.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        .ignoresSafeArea()
                    content
                        .padding()
                }
            }
            .navigationTitle("Collaboration")
            .toolbar { toolbarContent }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(CollaborationTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Label(tab.title, systemImage: tab.icon)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(selectedTab == tab ? Color.blue.opacity(0.25) : .clear, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding()
    }

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .dashboard:
            CollaborationDashboardView(manager: manager)
        case .members:
            MemberManagementView(manager: manager, actorID: currentUserID)
        case .prs:
            CollaborationPullRequestView(manager: manager, actorID: currentUserID)
        case .branches:
            VStack { BranchGraphView(manager: manager); BranchWorkspaceView(manager: manager, actorID: currentUserID) }
        case .activity:
            ActivityLogView(manager: manager)
        case .chat:
            chatView
        case .notifications:
            ActivityLogView(manager: manager)
        case .files:
            FilePermissionView(manager: manager, actorID: currentUserID)
        case .conflicts:
            ConflictResolverView(manager: manager, actorID: currentUserID)
        }
    }

    private var chatView: some View {
        VStack(alignment: .leading) {
            Text("Project Chat").font(.title3.bold()).foregroundStyle(.white)
            List {
                ForEach(manager.chatMessages) { item in
                    VStack(alignment: .leading) {
                        Text("\(item.authorID) • #\(item.channel.rawValue)").font(.caption).foregroundStyle(.secondary)
                        Text(item.text)
                        if let code = item.codeSnippet { Text(code).font(.caption.monospaced()).foregroundStyle(.cyan) }
                    }
                }
            }
            .scrollContentBackground(.hidden)

            HStack {
                TextField("Message or @mention", text: $chatDraft)
                    .textFieldStyle(.roundedBorder)
                Button("Send") {
                    manager.sendChat(channel: .general, scopeID: "project", authorID: currentUserID, text: chatDraft)
                    chatDraft = ""
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Toggle("Lock", isOn: .constant(!manager.fileLocks.isEmpty)).labelsHidden()
            Button("Sync") { Task { await manager.syncCurrentBranch(actorID: currentUserID) } }
            Button("Offline") { manager.isOfflineMode.toggle(); if !manager.isOfflineMode { manager.flushOfflineQueue() } }
        }
    }
}

private enum CollaborationTab: String, CaseIterable, Identifiable {
    case dashboard, members, prs, branches, activity, chat, notifications, files, conflicts
    var id: String { rawValue }
    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .members: return "Members"
        case .prs: return "PRs"
        case .branches: return "Branches"
        case .activity: return "Activity"
        case .chat: return "Chat"
        case .notifications: return "Notifications"
        case .files: return "File Presence"
        case .conflicts: return "Conflicts"
        }
    }
    var icon: String {
        switch self {
        case .dashboard: return "rectangle.3.group"
        case .members: return "person.3"
        case .prs: return "arrow.triangle.pull"
        case .branches: return "arrow.triangle.branch"
        case .activity: return "clock"
        case .chat: return "bubble.left.and.bubble.right"
        case .notifications: return "bell"
        case .files: return "doc.text.magnifyingglass"
        case .conflicts: return "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90"
        }
    }
}
