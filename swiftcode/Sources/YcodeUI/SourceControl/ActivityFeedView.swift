import SwiftUI
import SwiftCodeGitHub
import YcodeIDECore

@MainActor
struct ActivityFeedView: View {
    let project: Project?
    @State private var events: [GitHubRepositoryEvent] = []
    @State private var isFetching = false
    @State private var errorMessage: String?

    private var ownerAndRepo: (String, String)? {
        guard let repoStr = project?.githubRepo, !repoStr.isEmpty else { return nil }
        let parts = repoStr.split(separator: "/")
        guard parts.count == 2 else { return nil }
        return (String(parts[0]), String(parts[1]))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Repository Activity Feed", systemImage: "bolt.fill")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Button {
                    fetchEvents()
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
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }

            if isFetching {
                GitHubLoadingView(message: "Loading repository activity...")
            } else if events.isEmpty {
                GitHubEmptyStateView(
                    title: "No Activity",
                    description: "No recent activity has been recorded in this repository's feed.",
                    systemImage: "bolt.slash",
                    accentColor: .accentColor
                )
            } else {
                List(events) { item in
                    HStack(spacing: 16) {
                        Image(systemName: "circle.circle.fill")
                            .foregroundStyle(Color.accentColor)
                            .font(.title3)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.type)
                                .font(.subheadline.bold())
                                .foregroundStyle(.primary)
                            HStack(spacing: 4) {
                                if let actor = item.actorLogin {
                                    Text("By \(actor)")
                                }
                                if let created = item.createdAt {
                                    Text(created, style: .relative)
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .onAppear {
            fetchEvents()
        }
    }

    private func fetchEvents() {
        guard let (owner, repo) = ownerAndRepo else { return }
        isFetching = true
        errorMessage = nil
        Task {
            do {
                self.events = try await GitHubTokenProvider.service().listRepositoryEvents(owner: owner, repo: repo)
            } catch {
                self.errorMessage = error.localizedDescription
            }
            isFetching = false
        }
    }

}
