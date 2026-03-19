import SwiftUI

struct CommitManagerView: View {
    @ObservedObject var manager: CollaborationManager
    let actorID: String
    @State private var commitMessage = ""

    var body: some View {
        List {
            Section("Staging Area") {
                if manager.commits.stagedChanges.isEmpty {
                    Text("No staged changes.")
                        .foregroundStyle(.secondary)
                }
                ForEach(Array(manager.commits.stagedChanges.keys.sorted()), id: \.self) { path in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(path).font(.headline)
                        Text(manager.commits.stagedChanges[path] ?? "")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .swipeActions {
                        Button(role: .destructive) { manager.commits.unstage(path: path) } label: {
                            Label("Unstage", systemImage: "minus.circle")
                        }
                    }
                }
            }

            Section("Create Commit") {
                TextField("Commit message", text: $commitMessage)
                Button {
                    manager.commit(message: commitMessage, authorID: actorID, changes: [:])
                    commitMessage = ""
                } label: {
                    Label("Commit Staged Changes", systemImage: "checkmark.circle.fill")
                }
                .disabled(commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || manager.commits.stagedChanges.isEmpty)
            }

            Section("History") {
                ForEach(manager.commits.commits(for: manager.branches.currentBranch.id)) { commit in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(commit.message).font(.headline)
                        Text("\(commit.authorID) • \(commit.timestamp.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        NavigationLink("View Diff") {
                            ScrollView {
                                VStack(spacing: 12) {
                                    ForEach(Array(commit.changes.keys.sorted()), id: \.self) { path in
                                        DiffViewerView(filePath: path, diff: commit.changes[path] ?? "")
                                    }
                                }
                                .padding()
                            }
                            .navigationTitle("Commit Diff")
                        }
                    }
                }
            }
        }
        .navigationTitle("Commit Manager")
    }
}
