import SwiftUI

struct CommitManagerView: View {
    @ObservedObject var manager: CollaborationManager
    let actorID: String

    @State private var commitMessage = ""
    @State private var selectedPath: String?
    @State private var customPath = ""
    @State private var customDiff = ""
    @State private var selectedKind: CommitChangeKind = .modified
    @State private var operationMessage: String?

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
                Text("Undo and redo stay synchronized with the collaboration backend commit history.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Working Tree") {
                TextField("File path", text: $customPath)
                Picker("Change type", selection: $selectedKind) {
                    ForEach(CommitChangeKind.allCases, id: \.self) { kind in
                        Text(kind.rawValue.capitalized).tag(kind)
                    }
                }
                TextField("Diff content", text: $customDiff, axis: .vertical)
                    .lineLimit(3...8)
                Button("Add / Update Change") {
                    manager.commits.updateWorkingChange(path: customPath, diff: customDiff, kind: selectedKind, authorID: actorID)
                    customPath = ""
                    customDiff = ""
                }
                .disabled(customPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || customDiff.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                ForEach(manager.commits.workingChanges) { change in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(change.path).font(.headline)
                                Text("\(change.kind.rawValue.capitalized) • \(change.authorID) • \(change.timestamp.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(change.isStaged ? "Unstage" : "Stage") {
                                if change.isStaged {
                                    manager.commits.unstage(path: change.path, actorID: actorID)
                                } else {
                                    manager.commits.stage(path: change.path, authorID: actorID)
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                        NavigationLink("Open Diff") {
                            CollaborationDiffViewerView(diff: change.diff)
                        }
                    }
                }
            }

            Section("Create Commit") {
                TextField("Commit message", text: $commitMessage)
                Button {
                    manager.commit(message: commitMessage, authorID: actorID, changes: [:])
                    commitMessage = ""
                    operationMessage = "Commit created successfully."
                } label: {
                    Label("Commit Staged Changes", systemImage: "checkmark.circle.fill")
                }
                .disabled(commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || manager.commits.stagedChanges.isEmpty)
            }

            Section("History") {
                ForEach(manager.commits.commits(for: manager.branches.currentBranch.id)) { commit in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(commit.message).font(.headline)
                                Text("\(commit.authorID) • \(commit.timestamp.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Menu {
                                Button("Undo Last Commit") { _ = manager.commits.undo() }
                                Button("Revert Commit") {
                                    _ = manager.commits.revert(commitID: commit.id, actorID: actorID)
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                        }
                        ForEach(commit.changes.keys.sorted(), id: \.self) { path in
                            NavigationLink(path) {
                                CollaborationDiffViewerView(diff: commit.changes[path] ?? "")
                            }
                        }
                    }
                }
            }

            if let operationMessage {
                Section {
                    Label(operationMessage, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
        .navigationTitle("Commit Manager")
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
