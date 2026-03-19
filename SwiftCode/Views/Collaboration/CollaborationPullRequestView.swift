import SwiftUI

struct CollaborationPullRequestView: View {
    @ObservedObject var manager: CollaborationManager
    let actorID: String

    @State private var showingCreatePR = false
    @State private var selectedPRID: UUID?
    @State private var commentText = ""
    @State private var reviewerID = ""
    @State private var reviewSummary = ""
    @State private var editTitle = ""
    @State private var editDescription = ""
    @State private var selectedCommitToLink: UUID?
    @State private var inlinePath = "Sources/Editor/CollabSession.swift"
    @State private var inlineLine = 1
    @State private var selectedThreadParentID: UUID?
    @State private var isSubmitting = false
    @State private var feedback: ViewFeedback?

    var body: some View {
        List {
            Section("Pull Requests") {
                if manager.pullRequests.pullRequests.isEmpty {
                    ContentUnavailableView("No Pull Requests", systemImage: "arrow.triangle.branch", description: Text("Create unrestricted pull requests between any branches, including draft or empty PRs."))
                }
                ForEach(manager.pullRequests.pullRequests) { pr in
                    Button {
                        selectedPRID = pr.id
                        syncEditorFields(with: pr)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(pr.title).font(.headline)
                                Spacer()
                                statusBadge(pr.status)
                            }
                            Text(pr.description.isEmpty ? "No description" : pr.description)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                            HStack {
                                Label(pr.authorID, systemImage: "person")
                                Label("\(pr.linkedCommitIDs.count) commits", systemImage: "shippingbox")
                                Label("\(pr.comments.count) comments", systemImage: "text.bubble")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if let pr = selectedPR {
                Section("PR Overview") {
                    TextField("Title", text: $editTitle)
                    TextField("Description", text: $editDescription, axis: .vertical)
                        .lineLimit(3...8)
                    Button {
                        manager.pullRequests.editPullRequest(prID: pr.id, title: editTitle, description: editDescription, actorID: actorID)
                        feedback = .success("Pull request details updated.")
                    } label: {
                        Label("Save Changes", systemImage: "square.and.pencil")
                    }
                    summaryGrid(for: pr)
                    if let summary = pr.conflictSummary, !summary.isEmpty {
                        Label(summary, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }

                Section("Merge Controls") {
                    actionRow(title: "Approve", systemImage: "checkmark.seal.fill", tint: .green) {
                        manager.pullRequests.submitReview(prID: pr.id, reviewerID: actorID, decision: .approve, summary: reviewSummary.isEmpty ? "Approved" : reviewSummary)
                    }
                    actionRow(title: "Request Changes", systemImage: "arrow.uturn.backward.circle.fill", tint: .orange) {
                        manager.pullRequests.submitReview(prID: pr.id, reviewerID: actorID, decision: .requestChanges, summary: reviewSummary.isEmpty ? "Requested changes" : reviewSummary)
                    }
                    actionRow(title: "Reject", systemImage: "xmark.seal.fill", tint: .red) {
                        manager.pullRequests.submitReview(prID: pr.id, reviewerID: actorID, decision: .reject, summary: reviewSummary.isEmpty ? "Rejected" : reviewSummary)
                    }
                    actionRow(title: "Merge Immediately", systemImage: "arrow.triangle.merge", tint: .purple) {
                        manager.merge(branch: pr.sourceBranchID, into: pr.targetBranchID, actorID: actorID, pullRequestID: pr.id)
                    }
                    HStack {
                        if pr.status == .closed {
                            Button("Reopen") { manager.pullRequests.reopen(prID: pr.id, actorID: actorID) }
                        } else if pr.status != .merged {
                            Button("Close", role: .destructive) { manager.pullRequests.close(prID: pr.id, actorID: actorID) }
                        }
                        Spacer()
                        TextField("Review summary", text: $reviewSummary)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                Section("Reviewers & Linked Commits") {
                    HStack {
                        TextField("Assign reviewer", text: $reviewerID)
                        Button("Add") {
                            manager.pullRequests.assignReviewer(reviewerID, to: pr.id, actorID: actorID)
                            reviewerID = ""
                        }
                        .disabled(reviewerID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    if !pr.reviewerIDs.isEmpty {
                        ForEach(pr.reviewerIDs, id: \.self) { reviewer in
                            Label(reviewer, systemImage: "person.badge.shield.checkmark")
                        }
                    }
                    Picker("Link commit", selection: $selectedCommitToLink) {
                        Text("Select commit").tag(UUID?.none)
                        ForEach(manager.commits.commits(for: pr.sourceBranchID)) { commit in
                            Text(commit.message).tag(UUID?.some(commit.id))
                        }
                    }
                    Button("Link Selected Commit") {
                        if let selectedCommitToLink {
                            manager.pullRequests.linkCommit(selectedCommitToLink, to: pr.id, actorID: actorID)
                        }
                    }
                    .disabled(selectedCommitToLink == nil)
                    ForEach(pr.linkedCommitIDs, id: \.self) { commitID in
                        if let commit = manager.commits.commits.first(where: { $0.id == commitID }) {
                            VStack(alignment: .leading) {
                                Text(commit.message).font(.headline)
                                Text("\(commit.authorID) • \(commit.timestamp.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Diff Preview") {
                    ForEach(Array(prDiffEntries(pr).enumerated()), id: \.offset) { _, entry in
                        NavigationLink(entry.key) {
                            CollaborationDiffViewerView(diff: entry.value)
                        }
                    }
                }

                Section("Inline Comments & Threads") {
                    TextField("File path", text: $inlinePath)
                    Stepper("Line \(inlineLine)", value: $inlineLine, in: 1...2000)
                    TextField("Comment or reply", text: $commentText, axis: .vertical)
                        .lineLimit(2...5)
                    Button {
                        isSubmitting = true
                        manager.pullRequests.addComment(to: pr.id, authorID: actorID, text: commentText, filePath: inlinePath, lineNumber: inlineLine, parentID: selectedThreadParentID)
                        commentText = ""
                        selectedThreadParentID = nil
                        isSubmitting = false
                    } label: {
                        Label(isSubmitting ? "Posting..." : selectedThreadParentID == nil ? "Post Inline Comment" : "Reply To Thread", systemImage: "paperplane.fill")
                    }
                    .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)

                    ForEach(rootComments(for: pr)) { comment in
                        VStack(alignment: .leading, spacing: 8) {
                            commentCard(comment)
                            ForEach(replies(for: comment, in: pr)) { reply in
                                commentCard(reply)
                                    .padding(.leading, 18)
                            }
                            Button("Reply") { selectedThreadParentID = comment.id }
                                .font(.caption)
                        }
                    }
                }

                Section("Review History") {
                    if pr.reviews.isEmpty {
                        Text("No reviews yet.").foregroundStyle(.secondary)
                    }
                    ForEach(pr.reviews) { review in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(review.reviewerID).font(.headline)
                                Spacer()
                                Text(review.decision.title).font(.caption.bold())
                            }
                            Text(review.summary)
                            Text(review.timestamp.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Activity Timeline") {
                    ForEach(pr.timeline) { event in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.title).font(.headline)
                            Text(event.detail)
                            Text("\(event.actorID) • \(event.timestamp.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
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
        .overlay(alignment: .bottom) {
            if let feedback {
                Label(feedback.message, systemImage: feedback.isError ? "xmark.octagon.fill" : "checkmark.circle.fill")
                    .padding()
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 8)
            }
        }
        .sheet(isPresented: $showingCreatePR) {
            CreatePullRequestView(manager: manager, actorID: actorID)
        }
        .onAppear {
            if selectedPRID == nil {
                selectedPRID = manager.pullRequests.pullRequests.first?.id
                if let pr = selectedPR { syncEditorFields(with: pr) }
            }
        }
    }

    private var selectedPR: PullRequest? {
        guard let selectedPRID else { return nil }
        return manager.pullRequests.pullRequests.first(where: { $0.id == selectedPRID })
    }

    private func syncEditorFields(with pr: PullRequest) {
        editTitle = pr.title
        editDescription = pr.description
    }

    private func prDiffEntries(_ pr: PullRequest) -> [(key: String, value: String)] {
        let linked = manager.commits.commits.filter { pr.linkedCommitIDs.contains($0.id) }
        let changes = linked.flatMap { $0.changes.map { ($0.key, $0.value) } }
        let grouped = Dictionary(grouping: changes, by: { $0.0 })
        return grouped.map { key, value in
            (key, value.map { $0.1 }.joined(separator: "\n"))
        }.sorted { $0.key < $1.key }
    }

    private func rootComments(for pr: PullRequest) -> [PullRequestComment] {
        pr.comments.filter { $0.parentID == nil }
    }

    private func replies(for comment: PullRequestComment, in pr: PullRequest) -> [PullRequestComment] {
        pr.comments.filter { $0.parentID == comment.id }
    }

    private func commentCard(_ comment: PullRequestComment) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(comment.authorID).font(.caption.bold())
                Spacer()
                if let filePath = comment.filePath, let lineNumber = comment.lineNumber {
                    Text("\(filePath):\(lineNumber)").font(.caption2)
                }
            }
            Text(comment.text)
            Text(comment.timestamp.formatted(date: .abbreviated, time: .shortened))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private func statusBadge(_ status: PullRequestStatus) -> some View {
        Text(status.rawValue.capitalized)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(statusColor(status).opacity(0.15), in: Capsule())
            .foregroundStyle(statusColor(status))
    }

    private func statusColor(_ status: PullRequestStatus) -> Color {
        switch status {
        case .open: return .green
        case .draft: return .gray
        case .approved: return .blue
        case .rejected: return .red
        case .merged: return .purple
        case .closed: return .orange
        }
    }

    private func actionRow(title: String, systemImage: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
    }

    private func summaryGrid(for pr: PullRequest) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
            GridRow { Text("Source").bold(); Text(branchName(pr.sourceBranchID)) }
            GridRow { Text("Target").bold(); Text(branchName(pr.targetBranchID)) }
            GridRow { Text("Commits").bold(); Text("\(pr.linkedCommitIDs.count)") }
            GridRow { Text("Comments").bold(); Text("\(pr.comments.count)") }
            GridRow { Text("Status").bold(); Text(pr.status.rawValue.capitalized) }
        }
        .font(.caption)
    }

    private func branchName(_ id: UUID) -> String {
        manager.branches.branches.first(where: { $0.id == id })?.name ?? "Unknown"
    }
}

struct CreatePullRequestView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var manager: CollaborationManager
    let actorID: String

    @State private var title = ""
    @State private var description = ""
    @State private var sourceBranchID: UUID
    @State private var targetBranchID: UUID
    @State private var isDraft = false
    @State private var includeEmpty = false
    @State private var selectedCommitIDs = Set<UUID>()
    @State private var isCreating = false
    @State private var errorMessage: String?

    init(manager: CollaborationManager, actorID: String) {
        self.manager = manager
        self.actorID = actorID
        let fallback = manager.branches.currentBranch.id
        _sourceBranchID = State(initialValue: manager.branches.branches.dropFirst().first?.id ?? fallback)
        _targetBranchID = State(initialValue: manager.branches.branches.first?.id ?? fallback)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Information") {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...8)
                    Toggle("Create as draft", isOn: $isDraft)
                    Toggle("Allow empty pull request", isOn: $includeEmpty)
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
                    Text("Any branch can target any branch. Empty or partial pull requests are permitted.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Commits Included") {
                    let commits = manager.commits.commits(for: sourceBranchID)
                    if commits.isEmpty {
                        Text("No commits on source branch. You can still create an empty PR.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(commits) { commit in
                        MultipleSelectionRow(title: commit.message, subtitle: "\(commit.authorID) • \(commit.timestamp.formatted(date: .abbreviated, time: .shortened))", isSelected: selectedCommitIDs.contains(commit.id)) {
                            if selectedCommitIDs.contains(commit.id) {
                                selectedCommitIDs.remove(commit.id)
                            } else {
                                selectedCommitIDs.insert(commit.id)
                            }
                        }
                    }
                }

                Section("Diff Preview") {
                    let preview = previewDiffs
                    if preview.isEmpty {
                        Text("No diff selected.").foregroundStyle(.secondary)
                    }
                    ForEach(preview, id: \.key) { entry in
                        NavigationLink(entry.key) {
                            CollaborationDiffViewerView(diff: entry.value)
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
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
                    Button(isCreating ? "Creating..." : "Create") {
                        createPR()
                    }
                    .disabled(isCreating)
                }
            }
        }
    }

    private var previewDiffs: [(key: String, value: String)] {
        let commits = manager.commits.commits(for: sourceBranchID).filter { selectedCommitIDs.contains($0.id) }
        if commits.isEmpty { return [] }
        let flattened = commits.flatMap { $0.changes.map { ($0.key, $0.value) } }
        let grouped = Dictionary(grouping: flattened, by: { $0.0 })
        return grouped.map { ($0.key, $0.value.map { $0.1 }.joined(separator: "\n")) }.sorted { $0.key < $1.key }
    }

    private func createPR() {
        isCreating = true
        let commits = manager.commits.commits(for: sourceBranchID).filter { selectedCommitIDs.contains($0.id) }
        if commits.isEmpty == false || includeEmpty {
            manager.createPullRequest(sourceID: sourceBranchID, targetID: targetBranchID, title: title, description: description, actorID: actorID, status: isDraft ? .draft : .open, linkedCommitIDs: commits.map { $0.id }, conflictSummary: sourceBranchID == targetBranchID ? "Source and target are identical; merge will create a no-op PR." : nil)
            dismiss()
        } else {
            errorMessage = "Select at least one commit, or enable empty pull requests."
        }
        isCreating = false
    }
}

private struct MultipleSelectionRow: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading) {
                    Text(title)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .green : .secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct ViewFeedback: Equatable {
    let message: String
    let isError: Bool

    static func success(_ message: String) -> Self { .init(message: message, isError: false) }
    static func error(_ message: String) -> Self { .init(message: message, isError: true) }
}
