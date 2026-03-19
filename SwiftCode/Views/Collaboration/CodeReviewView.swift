import SwiftUI

struct CodeReviewView: View {
    @ObservedObject var manager: CollaborationManager
    let actorID: String
    @State private var selectedCommitID: UUID?
    @State private var commentText = ""
    @State private var reviewerID = ""
    @State private var inlinePath = "Sources/Editor/CollabSession.swift"
    @State private var lineNumber = 42

    var body: some View {
        List {
            Section("Commits Pending Review") {
                ForEach(manager.commits.commits(for: manager.branches.currentBranch.id)) { commit in
                    Button {
                        selectedCommitID = commit.id
                        manager.reviews.initiateReview(for: commit.id)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(commit.message).font(.headline)
                                Text(commit.authorID).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(manager.reviews.reviews[commit.id]?.status.rawValue.capitalized ?? "Pending")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.thinMaterial, in: Capsule())
                        }
                    }
                }
            }

            if let commit = selectedCommit {
                Section("Reviewer Assignment") {
                    TextField("Reviewer name", text: $reviewerID)
                    Button("Assign Reviewer") {
                        manager.reviews.assignReviewer(reviewerID, to: commit.id, actorID: actorID, permissions: manager.permissions)
                        reviewerID = ""
                    }
                    .disabled(reviewerID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if let reviewers = manager.reviews.reviews[commit.id]?.reviewerIDs, !reviewers.isEmpty {
                        ForEach(reviewers, id: \.self) { reviewer in
                            Label(reviewer, systemImage: "person.crop.circle.badge.checkmark")
                        }
                    }
                }

                Section("Inline Comments") {
                    TextField("File path", text: $inlinePath)
                    Stepper("Line \(lineNumber)", value: $lineNumber, in: 1...999)
                    TextField("Add comment", text: $commentText)
                    Button("Post Comment") {
                        manager.reviews.addComment(to: commit.id, authorID: actorID, filePath: inlinePath, lineNumber: lineNumber, text: commentText)
                        commentText = ""
                    }
                    .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    ForEach(manager.reviews.reviews[commit.id]?.comments ?? []) { comment in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(comment.filePath):\(comment.lineNumber)")
                                .font(.caption.bold())
                            Text(comment.text)
                            Text(comment.authorID)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Decision") {
                    Button {
                        manager.reviews.approveReview(for: commit.id, actorID: actorID, permissions: manager.permissions)
                    } label: {
                        Label("Approve", systemImage: "checkmark.seal.fill")
                    }
                    .tint(.green)

                    Button(role: .destructive) {
                        manager.reviews.rejectReview(for: commit.id, actorID: actorID, permissions: manager.permissions)
                    } label: {
                        Label("Reject", systemImage: "xmark.seal.fill")
                    }
                }
            }
        }
        .navigationTitle("Code Reviews")
        .onAppear {
            if selectedCommitID == nil {
                selectedCommitID = manager.commits.commits(for: manager.branches.currentBranch.id).first?.id
            }
        }
    }

    private var selectedCommit: Commit? {
        guard let selectedCommitID else { return nil }
        return manager.commits.commits.first(where: { $0.id == selectedCommitID })
    }
}
