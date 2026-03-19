import SwiftUI

struct CommitManagerView: View {
    @ObservedObject var manager: CollaborationManager
    let actorID: String
    @State private var commitMessage = ""

    var body: some View {
        List {
            Section("Undo / Redo") {
                HStack(spacing: 12) {
                    actionButton(title: "Undo", icon: "arrow.uturn.backward.circle.fill", tint: .orange, enabled: manager.commits.canUndo) {
                        _ = manager.commits.undo()
                    }
                    actionButton(title: "Redo", icon: "arrow.uturn.forward.circle.fill", tint: .blue, enabled: manager.commits.canRedo) {
                        _ = manager.commits.redo()
                    }
                }
            }

            Section("Staging Area") {
                if manager.commits.stagedChanges.isEmpty {
                    Text("No staged changes. Tap a sample file below to stage live entries.")
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

                ForEach(sampleStageEntries, id: \.0) { sample in
                    Button {
                        manager.commits.stage(path: sample.0, diff: sample.1)
                    } label: {
                        Label("Stage \(sample.0)", systemImage: "plus.circle")
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
                    }
                }
            }
        }
        .navigationTitle("Commit Manager")
    }

    private var sampleStageEntries: [(String, String)] {
        [
            ("Sources/Editor/CollabSession.swift", "+ add reviewer assignment hooks"),
            ("Views/Projects/Toolbar.swift", "+ expose collaboration shortcut")
        ]
    }

    private func actionButton(title: String, icon: String, tint: Color, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
        .disabled(!enabled)
    }
}
