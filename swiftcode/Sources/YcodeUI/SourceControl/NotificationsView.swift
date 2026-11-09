import SwiftUI
import SwiftCodeGitHub

@MainActor
struct NotificationsView: View {
    @State private var notifications: [GitHubNotification] = []
    @State private var isFetching = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("GitHub Notifications Inbox", systemImage: "bell.fill")
                    .font(.headline)
                    .foregroundStyle(.yellow)

                Spacer()

                Button {
                    fetchNotifications()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isFetching)
            }
            .padding()
            .liquidGlass(style: .subtle, cornerRadius: 10)

            Divider()

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            if isFetching {
                GitHubLoadingView(message: "Loading notifications...")
            } else if notifications.isEmpty {
                GitHubEmptyStateView(
                    title: "Inbox Zero!",
                    description: "No unread notifications in your GitHub account. Looking clean!",
                    systemImage: "bell.slash",
                    accentColor: .yellow
                )
            } else {
                List(notifications) { item in
                    Button {
                        Task { await markRead(item) }
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: item.unread ? "envelope.fill" : "envelope.open.fill")
                                .foregroundStyle(.yellow)
                                .font(.title3)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.subjectTitle)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.primary)
                                Text("\(item.repositoryFullName) • \(item.reason)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let updated = item.updatedAt {
                                    Text(updated, style: .relative)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }

                            Spacer()

                            if item.unread {
                                Circle().fill(Color.yellow).frame(width: 8, height: 8)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onAppear {
            fetchNotifications()
        }
    }

    private func fetchNotifications() {
        isFetching = true
        errorMessage = nil
        Task {
            do {
                self.notifications = try await GitHubTokenProvider.service().listNotifications()
            } catch {
                self.errorMessage = error.localizedDescription
            }
            isFetching = false
        }
    }

    private func markRead(_ notification: GitHubNotification) async {
        guard notification.unread else { return }
        do {
            try await GitHubTokenProvider.service().markNotificationRead(threadId: notification.id)
            notifications.removeAll { $0.id == notification.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

}
