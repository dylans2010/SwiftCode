import SwiftUI

struct CodeReviewView: View {
    @ObservedObject var manager: CollaborationManager
    let commit: Commit
    @Environment(\.dismiss) private var dismiss
    @State private var commentText = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Commit Info") {
                    Text(commit.message)
                        .font(.headline)
                    Text("Author: \(commit.authorID)")
                    Text("Time: \(commit.timestamp.formatted())")
                }

                Section("Changes") {
                    ForEach(Array(commit.changes.keys), id: \.self) { path in
                        HStack {
                            Image(systemName: "doc.text")
                            Text(path)
                            Spacer()
                            Text("Modified")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }

                Section("Comments") {
                    if let review = manager.reviews.reviews[commit.id] {
                        ForEach(review.comments) { comment in
                            VStack(alignment: .leading) {
                                Text(comment.authorID)
                                    .font(.caption.bold())
                                Text(comment.text)
                            }
                        }
                    }

                    HStack {
                        TextField("Add a comment...", text: $commentText)
                        Button("Send") {
                            manager.reviews.addComment(to: commit.id, authorID: UIDevice.current.name, text: commentText)
                            commentText = ""
                        }
                        .disabled(commentText.isEmpty)
                    }
                }

                Section {
                    HStack {
                        Button {
                            manager.reviews.approveReview(for: commit.id)
                            dismiss()
                        } label: {
                            Label("Approve", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                        .frame(maxWidth: .infinity)

                        Divider()

                        Button {
                            manager.reviews.rejectReview(for: commit.id)
                            dismiss()
                        } label: {
                            Label("Reject", systemImage: "xmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Code Review")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                if manager.reviews.reviews[commit.id] == nil {
                    manager.reviews.initiateReview(for: commit.id)
                }
            }
        }
    }
}
