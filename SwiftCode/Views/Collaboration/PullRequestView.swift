import SwiftUI

struct PullRequestView: View {
    @ObservedObject var manager: CollaborationManager
    let actorID: String

    @State private var showingCreatePR = false
    @State private var prTitle = ""
    @State private var prDescription = ""
    @State private var sourceBranch: Branch?
    @State private var targetBranch: Branch?
    @State private var selectedPR: PullRequest?

    var body: some View {
        List {
            Section {
                Button {
                    showingCreatePR = true
                } label: {
                    Label("Create New Pull Request", systemImage: "plus.circle.fill")
                }
            }

            Section("Open Pull Requests") {
                let openPRs = manager.reviews.pullRequests.filter { $0.status == .open }
                if openPRs.isEmpty {
                    Text("No open pull requests.")
                        .foregroundStyle(.secondary)
                }
                ForEach(openPRs) { pr in
                    prRow(for: pr)
                }
            }

            Section("Recently Merged / Closed") {
                let closedPRs = manager.reviews.pullRequests.filter { $0.status != .open }
                ForEach(closedPRs) { pr in
                    prRow(for: pr)
                        .opacity(0.6)
                }
            }
        }
        .navigationTitle("Pull Requests")
        .sheet(isPresented: $showingCreatePR) {
            createPRSheet
        }
        .sheet(item: $selectedPR) { pr in
            prDetailView(for: pr)
        }
    }

    @ViewBuilder
    private func prRow(for pr: PullRequest) -> some View {
        Button {
            selectedPR = pr
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(pr.title).font(.headline)
                    Spacer()
                    Text(pr.status.rawValue.capitalized)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(statusColor(for: pr.status).opacity(0.15), in: Capsule())
                        .foregroundStyle(statusColor(for: pr.status))
                }

                let source = manager.branches.branches.first(where: { $0.id == pr.sourceBranchID })?.name ?? "unknown"
                let target = manager.branches.branches.first(where: { $0.id == pr.targetBranchID })?.name ?? "unknown"
                Text("\(source) → \(target)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Opened by \(pr.authorID) on \(pr.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func statusColor(for status: PullRequest.PRStatus) -> Color {
        switch status {
        case .open: return .green
        case .merged: return .purple
        case .closed: return .red
        }
    }

    private var createPRSheet: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Title", text: $prTitle)
                    TextField("Description", text: $prDescription, axis: .vertical)
                        .lineLimit(3...10)
                }

                Section("Branches") {
                    Picker("Source", selection: $sourceBranch) {
                        Text("Select Source Branch").tag(nil as Branch?)
                        ForEach(manager.branches.branches) { branch in
                            Text(branch.name).tag(branch as Branch?)
                        }
                    }

                    Picker("Target", selection: $targetBranch) {
                        Text("Select Target Branch").tag(nil as Branch?)
                        ForEach(manager.branches.branches) { branch in
                            Text(branch.name).tag(branch as Branch?)
                        }
                    }
                }
            }
            .navigationTitle("New Pull Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingCreatePR = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Open PR") {
                        if let source = sourceBranch, let target = targetBranch {
                            _ = manager.reviews.createPR(title: prTitle, description: prDescription, sourceBranchID: source.id, targetBranchID: target.id, authorID: actorID)
                            showingCreatePR = false
                            prTitle = ""
                            prDescription = ""
                        }
                    }
                    .disabled(prTitle.isEmpty || sourceBranch == nil || targetBranch == nil || sourceBranch?.id == targetBranch?.id)
                }
            }
        }
    }

    @ViewBuilder
    private func prDetailView(for pr: PullRequest) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(pr.title).font(.title.bold())
                            Spacer()
                            Text("#\(pr.id.uuidString.prefix(6))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text(pr.description)
                            .font(.body)
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

                    Divider()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Discussion").font(.headline)

                        if pr.comments.isEmpty {
                            Text("No comments yet.")
                                .foregroundStyle(.secondary)
                                .italic()
                        }

                        ForEach(pr.comments) { comment in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(comment.authorID).font(.caption.bold())
                                Text(comment.text).font(.subheadline)
                                Text(comment.timestamp.formatted()).font(.caption2).foregroundStyle(.secondary)
                            }
                            .padding(10)
                            .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }

                    if pr.status == .open {
                        HStack(spacing: 12) {
                            Button {
                                manager.reviews.mergePR(pr.id, actorID: actorID)
                                manager.merge(branch: pr.sourceBranchID, into: pr.targetBranchID, actorID: actorID)
                                selectedPR = nil
                            } label: {
                                Label("Merge PR", systemImage: "arrow.triangle.merge")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.purple)

                            Button {
                                manager.reviews.closePR(pr.id, actorID: actorID)
                                selectedPR = nil
                            } label: {
                                Label("Close PR", systemImage: "xmark.circle")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("PR Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { selectedPR = nil }
                }
            }
        }
    }
}

extension Branch: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
