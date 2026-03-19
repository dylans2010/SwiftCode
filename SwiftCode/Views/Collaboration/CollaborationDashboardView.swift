import SwiftUI

struct CollaborationDashboardView: View {
    @ObservedObject var manager: CollaborationManager
    @State private var showBranchManagement = false
    @State private var showInviteMembers = false
    @State private var showCommitHistory = false
    @State private var showPushPull = false

    var body: some View {
        List {
            Section("Current Project Status") {
                HStack {
                    Label("Branch", systemImage: "arrow.branch")
                    Spacer()
                    Text(manager.branches.currentBranch.name)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Label("Members", systemImage: "person.2.fill")
                    Spacer()
                    Text("\(manager.permissions.memberRoles.count)")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Label("Commits", systemImage: "clock.arrow.2.circlepath")
                    Spacer()
                    Text("\(manager.commits.commits(for: manager.branches.currentBranch.id).count)")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Quick Actions") {
                Button { showBranchManagement = true } label: {
                    Label("Manage Branches", systemImage: "list.bullet.indent")
                }

                Button { showInviteMembers = true } label: {
                    Label("Invite Members", systemImage: "person.badge.plus")
                }

                Button { showCommitHistory = true } label: {
                    Label("View Commit History", systemImage: "clock.fill")
                }

                Button { showPushPull = true } label: {
                    Label("Push/Pull Changes", systemImage: "arrow.up.arrow.down")
                }
            }

            Section("Collaborators") {
                ForEach(Array(manager.permissions.memberRoles.keys), id: \.self) { memberID in
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.title2)
                        VStack(alignment: .leading) {
                            Text(memberID)
                                .font(.headline)
                            Text(manager.permissions.memberRoles[memberID]?.rawValue.capitalized ?? "Unknown")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Collaboration")
        .sheet(isPresented: $showBranchManagement) { BranchManagementView(manager: manager) }
        .sheet(isPresented: $showInviteMembers) { InviteMembersView(manager: manager) }
        .sheet(isPresented: $showCommitHistory) { CommitHistoryView(manager: manager) }
        .sheet(isPresented: $showPushPull) { PushPullView(manager: manager) }
    }
}
