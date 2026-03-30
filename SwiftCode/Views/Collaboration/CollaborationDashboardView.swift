import SwiftUI

struct CollaborationDashboardView: View {
    @ObservedObject var manager: CollaborationManager
    @EnvironmentObject private var projectManager: ProjectManager

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Top Status Cards
                HStack(spacing: 16) {
                    DashboardStatCard(title: "Active Users", value: "\(manager.invites.invites.filter { $0.status == .accepted }.count + 1)", icon: "person.2.fill", color: .blue)
                    DashboardStatCard(title: "Open PRs", value: "\(manager.pullRequests.pullRequests.filter { $0.status == .open }.count)", icon: "arrow.triangle.pull", color: .purple)
                }

                HStack(spacing: 16) {
                    DashboardStatCard(title: "Branches", value: "\(manager.branches.branches.count)", icon: "arrow.triangle.branch", color: .green)
                    DashboardStatCard(title: "Recent Commits", value: "\(manager.commits.commits.count)", icon: "clock.fill", color: .orange)
                }

                // Quick Actions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick Actions")
                        .font(.headline)
                        .foregroundStyle(.white)

                    HStack(spacing: 12) {
                        QuickActionButton(title: "New PR", icon: "plus.square.fill.on.square.fill") {
                            // Trigger PR creation
                        }
                        QuickActionButton(title: "Invite", icon: "person.badge.plus") {
                            // Show invite sheet
                        }
                        QuickActionButton(title: "Sync", icon: "arrow.triangle.2.circlepath") {
                            Task { await manager.syncCurrentBranch(actorID: manager.creatorID) }
                        }
                    }
                }

                // Active Collaborators
                VStack(alignment: .leading, spacing: 12) {
                    Text("Collaborators")
                        .font(.headline)
                        .foregroundStyle(.white)

                    VStack(spacing: 10) {
                        CollaboratorRow(name: "You", role: "Owner", isOnline: true)
                        ForEach(manager.invites.invites.filter { $0.status == .accepted }) { invite in
                            CollaboratorRow(name: invite.memberID, role: "Member", isOnline: false)
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                }

                // Activity Preview
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Recent Activity")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Spacer()
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(manager.activityLog.prefix(5)) { activity in
                            ActivityItemRow(activity: activity)
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
        }
        .background(Color(red: 0.05, green: 0.05, blue: 0.07))
        .navigationTitle("Collaboration")
    }
}

struct DashboardStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.05), lineWidth: 1))
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.caption.bold())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.blue.opacity(0.15))
            .foregroundStyle(.blue)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

struct CollaboratorRow: View {
    let name: String
    let role: String
    let isOnline: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 32, height: 32)

                Circle()
                    .fill(isOnline ? Color.green : Color.gray)
                    .frame(width: 10, height: 10)
                    .overlay(Circle().stroke(Color.black, lineWidth: 2))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Text(role)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

struct ActivityItemRow: View {
    let activity: CollaborationActivity

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: activityIcon(activity.kind))
                .font(.caption)
                .foregroundStyle(activityColor(activity.kind))
                .frame(width: 24, height: 24)
                .background(activityColor(activity.kind).opacity(0.1), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(activity.title)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                Text(activity.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(activity.timestamp, style: .relative)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
    }

    private func activityIcon(_ kind: CollaborationActivity.Kind) -> String {
        switch kind {
        case .branch: return "arrow.triangle.branch"
        case .commit: return "circle.fill"
        case .review: return "checkmark.seal.fill"
        case .pullRequest: return "arrow.triangle.pull"
        case .sync: return "arrow.triangle.2.circlepath"
        case .invite: return "person.badge.plus"
        case .permissions: return "key.fill"
        case .conflict: return "exclamationmark.triangle.fill"
        case .fileLock: return "lock.fill"
        }
    }

    private func activityColor(_ kind: CollaborationActivity.Kind) -> Color {
        switch kind {
        case .branch: return .blue
        case .commit: return .orange
        case .review: return .green
        case .pullRequest: return .purple
        case .sync: return .teal
        case .invite: return .yellow
        case .permissions: return .red
        case .conflict: return .red
        case .fileLock: return .gray
        }
    }
}
