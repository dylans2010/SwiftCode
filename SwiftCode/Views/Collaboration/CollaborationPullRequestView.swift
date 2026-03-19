import SwiftUI

struct CollaborationPullRequestView: View {
    @ObservedObject var manager: CollaborationManager
    let actorID: String

    @State private var showingCreatePR = false
    @State private var selectedPRID: UUID?

    var body: some View {
        List {
            Section("Pull Requests") {
                if manager.pullRequests.pullRequests.isEmpty {
                    Text("No pull requests yet.")
                        .foregroundStyle(.secondary)
                }
                ForEach(manager.pullRequests.pullRequests) { pr in
                    Button {
                        selectedPRID = pr.id
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(pr.title).font(.headline)
                                Text("\(pr.authorID) • \(pr.createdAt.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(pr.status.rawValue.capitalized)
                                .font(.caption.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(statusColor(pr.status).opacity(0.1), in: Capsule())
                                .foregroundStyle(statusColor(pr.status))
                        }
                    }
                }
            }

            if let selectedPR = manager.pullRequests.pullRequests.first(where: { $0.id == selectedPRID }) {
                Section("PR Details: \(selectedPR.title)") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(selectedPR.description)
                        Text("Source: \(manager.branches.branches.first(where: { $0.id == selectedPR.sourceBranchID })?.name ?? "Unknown")")
                            .font(.caption)
                        Text("Target: \(manager.branches.branches.first(where: { $0.id == selectedPR.targetBranchID })?.name ?? "Unknown")")
                            .font(.caption)
                    }

                    if selectedPR.status == .open {
                        Button {
                            manager.merge(branch: selectedPR.sourceBranchID, into: selectedPR.targetBranchID, actorID: actorID, pullRequestID: selectedPR.id)
                        } label: {
                            Label("Merge Pull Request", systemImage: "arrow.triangle.merge")
                        }
                        .tint(.purple)

                        Button(role: .destructive) {
                            manager.pullRequests.close(prID: selectedPR.id, actorID: actorID)
                        } label: {
                            Label("Close PR", systemImage: "xmark.circle")
                        }
                    }
                }

                Section("Comments") {
                    ForEach(selectedPR.comments) { comment in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(comment.authorID).font(.caption.bold())
                            Text(comment.text)
                            Text(comment.timestamp.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    CommentInputView { text in
                        manager.pullRequests.addComment(to: selectedPR.id, authorID: actorID, text: text)
                    }
                }
            }
        }
        .navigationTitle("Pull Requests")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingCreatePR = true } label: {
                    Image(systemName: "plus.circle.fill")
                }
            }
        }
        .sheet(isPresented: $showingCreatePR) {
            CreatePullRequestView(manager: manager, actorID: actorID)
        }
    }

    private func statusColor(_ status: PullRequestStatus) -> Color {
        switch status {
        case .open: return .green
        case .closed: return .red
        case .merged: return .purple
        }
    }
}

struct CommentInputView: View {
    @State private var text = ""
    var onPost: (String) -> Void

    var body: some View {
        HStack {
            TextField("Add a comment...", text: $text)
            Button("Post") {
                onPost(text)
                text = ""
            }
            .disabled(text.isEmpty)
        }
    }
}

struct CreatePullRequestView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var manager: CollaborationManager
    let actorID: String

    @State private var title = ""
    @State private var description = ""
    @State private var sourceBranchID: UUID
    @State private var targetBranchID: UUID

    init(manager: CollaborationManager, actorID: String) {
        self.manager = manager
        self.actorID = actorID
        _sourceBranchID = State(initialValue: manager.branches.branches.first { $0.id != manager.branches.branches.first?.id }?.id ?? manager.branches.currentBranch.id)
        _targetBranchID = State(initialValue: manager.branches.branches.first?.id ?? manager.branches.currentBranch.id)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Information") {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...10)
                }

                Section("Branches") {
                    Picker("Source", selection: $sourceBranchID) {
                        ForEach(manager.branches.branches) { branch in
                            Text(branch.name).tag(branch.id)
                        }
                    }
                    Picker("Target", selection: $targetBranchID) {
                        ForEach(manager.branches.branches) { branch in
                            Text(branch.name).tag(branch.id)
                        }
                    }
                }
            }
            .navigationTitle("New Pull Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        manager.createPullRequest(sourceID: sourceBranchID, targetID: targetBranchID, title: title, description: description, actorID: actorID)
                        dismiss()
                    }
                    .disabled(title.isEmpty || sourceBranchID == targetBranchID)
                }
            }
        }
    }
}
