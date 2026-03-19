import SwiftUI

struct CommitHistoryView: View {
    @ObservedObject var manager: CollaborationManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCommit: Commit?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Button {
                            _ = manager.commits.undo()
                        } label: {
                            Label("Undo Commit", systemImage: "arrow.uturn.backward")
                        }
                        .buttonStyle(.bordered)

                        Spacer()

                        Button {
                            _ = manager.commits.redo()
                        } label: {
                            Label("Redo Commit", systemImage: "arrow.uturn.forward")
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 4)
                }

                Section("History") {
                    let commits = manager.commits.commits(for: manager.branches.currentBranch.id)
                    if commits.isEmpty {
                        Text("No commits on this branch.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(commits) { commit in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(commit.message)
                                    .font(.headline)
                                HStack {
                                    Text(commit.authorID)
                                    Spacer()
                                    Text(commit.timestamp, style: .date)
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)

                                let reviewStatus = manager.reviews.reviews[commit.id]?.status
                                if let status = reviewStatus {
                                    Text("Review: \(status.rawValue.capitalized)")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(statusColor(for: status).opacity(0.2), in: Capsule())
                                        .foregroundStyle(statusColor(for: status))
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedCommit = commit
                            }
                        }
                    }
                }
            }
            .navigationTitle("Commit History")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(item: $selectedCommit) { commit in
                CodeReviewView(manager: manager, commit: commit)
            }
        }
    }

    private func statusColor(for status: ReviewStatus) -> Color {
        switch status {
        case .pending: return .orange
        case .approved: return .green
        case .rejected: return .red
        }
    }
}
