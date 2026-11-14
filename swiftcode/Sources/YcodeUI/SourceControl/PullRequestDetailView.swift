import SwiftUI
import AppKit
import SwiftCodeGitHub
import YcodeAssistant

@MainActor
struct PullRequestDetailView: View {
    let pr: GitHubPullRequest
    @Environment(\.dismiss) private var dismiss

    @State private var activeTab: DetailTab = .conversation

    @State private var filesModified: [GitHubPullRequestFile] = []
    @State private var prCommits: [GitHubCommit] = []
    @State private var prReviews: [GitHubReview] = []
    @State private var remoteComments: [GitHubIssueComment] = []
    @State private var isLoadingReviews = false
    @State private var isPostingComment = false
    @State private var isLoadingFiles = false
    @State private var isLoadingCommits = false
    @State private var isMerging = false
    @State private var selectedFileIdx = 0

    @State private var replyText = ""
    @State private var localComments: [LocalComment] = []

    @State private var isRunningAIReview = false
    @State private var aiReviewSummaryText = ""

    @State private var successMessage: String?
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @State private var showError = false

    struct LocalComment: Identifiable {
        let id = UUID()
        let author: String
        let body: String
        let date: Date
    }

    enum DetailTab: String, CaseIterable, Identifiable {
        case conversation = "Conversation"
        case files = "Files Changed"
        case aiReviews = "AI Review Assistant"

        var id: String { rawValue }
    }

    private var context: RepositoryContext {
        RepositoryContext.shared
    }

    private var ownerAndRepo: (String, String)? {
        guard let repoStr = context.connectedRepository, !repoStr.isEmpty else { return nil }
        let parts = repoStr.split(separator: "/")
        guard parts.count == 2 else { return nil }
        return (String(parts[0]), String(parts[1]))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("PR #\(pr.number): \(pr.title)", systemImage: "arrow.triangle.pull")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Spacer()

                Picker("Tabs", selection: $activeTab) {
                    ForEach(DetailTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 380)

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .liquidGlass(style: .subtle, cornerRadius: 10)

            Divider()

            switch activeTab {
            case .conversation:
                conversationPane
            case .files:
                filesChangedPane
            case .aiReviews:
                aiReviewsPane
            }
        }
        .frame(width: 750, height: 600)
        .onAppear {
            fetchPRData()
        }
        .alert("Success", isPresented: $showSuccess, presenting: successMessage) { _ in
            Button("OK") { dismiss() }
        } message: { msg in Text(msg) }
        .alert("Error", isPresented: $showError, presenting: errorMessage) { _ in
            Button("OK") {}
        } message: { msg in Text(msg) }
    }

    private var conversationPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(pr.state.uppercased())
                                .font(.caption2.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.secondary.opacity(0.12))
                                .foregroundStyle(.secondary)
                                .cornerRadius(4)

                            Text("opened by \(pr.userLogin) on \((pr.createdAt?.formatted(date: .abbreviated, time: .shortened) ?? ""))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text(pr.body ?? "No description provided.")
                            .font(.body)
                            .padding(.top, 6)
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.04))
                    .cornerRadius(6)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("REVIEWS")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)

                    if isLoadingReviews {
                        ProgressView().controlSize(.small)
                    } else if prReviews.isEmpty {
                        Text("No reviews yet.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(prReviews) { review in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(review.userLogin).bold().font(.caption)
                                    Text(review.state)
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.secondary.opacity(0.12))
                                        .cornerRadius(4)
                                    Spacer()
                                    if let submitted = review.submittedAt {
                                        Text(submitted, style: .relative)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                if let body = review.body, !body.isEmpty {
                                    Text(body).font(.subheadline)
                                }
                            }
                            .padding(.vertical, 4)
                            Divider()
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("MERGE INTEGRATION CONTROLS")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        Button {
                            performMerge(method: "merge")
                        } label: {
                            Label(isMerging ? "Merging..." : "Merge Pull Request", systemImage: "arrow.merge")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.accentColor)
                        .disabled(isMerging)

                        Button {
                            performMerge(method: "squash")
                        } label: {
                            Text("Squash & Merge")
                        }
                        .buttonStyle(.bordered)
                        .disabled(isMerging)

                        Button {
                            performMerge(method: "rebase")
                        } label: {
                            Text("Rebase & Merge")
                        }
                        .buttonStyle(.bordered)
                        .disabled(isMerging)
                    }
                    .padding(.top, 4)
                }
                .padding()
                .background(Color.secondary.opacity(0.04))
                .cornerRadius(6)

                VStack(alignment: .leading, spacing: 10) {
                    Text("TIMELINE ACTIVITY (COMMITS)")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)

                    if isLoadingCommits {
                        ProgressView().controlSize(.small)
                    } else if prCommits.isEmpty {
                        Text("No commits in this Pull Request.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(prCommits) { commit in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "arrow.triangle.branch")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    Text(commit.commit.author?.name ?? "Developer").bold()
                                        .font(.caption)

                                    Spacer()

                                    Text(commit.sha.prefix(7))
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                                Text(commit.commit.message)
                                    .font(.subheadline)
                                    .padding(.leading, 18)
                            }
                            .padding(.vertical, 4)
                            Divider()
                        }
                    }

                    if !remoteComments.isEmpty {
                        Text("COMMENTS")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                            .padding(.top, 10)

                        ForEach(remoteComments) { comment in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "bubble.left.fill")
                                        .font(.caption)
                                        .foregroundStyle(Color.accentColor)
                                    Text(comment.userLogin).bold().font(.caption)
                                    Spacer()
                                    if let created = comment.createdAt {
                                        Text(created, style: .relative)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Text(comment.body)
                                    .font(.subheadline)
                                    .padding(.leading, 18)
                            }
                            .padding(.vertical, 4)
                            Divider()
                        }
                    }

                    if !localComments.isEmpty {
                        Text("SESSION COMMENTS")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                            .padding(.top, 10)

                        ForEach(localComments) { comment in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "bubble.left.fill")
                                        .font(.caption)
                                        .foregroundStyle(Color.accentColor)
                                    Text(comment.author).bold().font(.caption)
                                    Spacer()
                                    Text(comment.date, style: .relative)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Text(comment.body)
                                    .font(.subheadline)
                                    .padding(.leading, 18)
                            }
                            .padding(.vertical, 4)
                            Divider()
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Add Comment").font(.caption.bold())
                        TextEditor(text: $replyText)
                            .frame(height: 80)
                            .border(Color.secondary.opacity(0.2), width: 1)

                        Button(isPostingComment ? "Posting..." : "Comment") {
                            executePostComment()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.accentColor)
                        .disabled(replyText.trimmingCharacters(in: .whitespaces).isEmpty || isPostingComment)
                    }
                    .padding(.top, 10)
                }
            }
            .padding(20)
        }
    }

    private var filesChangedPane: some View {
        VStack(spacing: 0) {
            if isLoadingFiles {
                ProgressView("Loading files changed...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filesModified.isEmpty {
                ContentUnavailableView("No Files Changed", systemImage: "doc.text")
            } else {
                HSplitView {
                    List(0..<filesModified.count, id: \.self) { idx in
                        let file = filesModified[idx]
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text((file.filename as NSString).lastPathComponent)
                                    .font(.subheadline.bold())
                                Text(file.filename)
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            HStack(spacing: 4) {
                                Text("+\(file.additions)").foregroundStyle(.secondary).font(.caption.bold())
                                Text("-\(file.deletions)").foregroundStyle(.secondary).font(.caption.bold())
                            }
                        }
                        .padding(.vertical, 2)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedFileIdx = idx
                        }
                        .listRowBackground(selectedFileIdx == idx ? Color.accentColor.opacity(0.1) : Color.clear)
                    }
                    .frame(width: 250)

                    VStack(alignment: .leading, spacing: 0) {
                        let activeFile = filesModified.indices.contains(selectedFileIdx) ? filesModified[selectedFileIdx] : filesModified[0]
                        Text("Diff for \(activeFile.filename)")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.secondary.opacity(0.08))

                        Divider()

                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                if let patch = activeFile.patch, !patch.isEmpty {
                                    ForEach(patch.components(separatedBy: .newlines), id: \.self) { line in
                                        diffLineView(line)
                                    }
                                } else {
                                    Text("Binary file or no preview available.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding()
                                }
                            }
                            .font(.system(size: 11, design: .monospaced))
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.black.opacity(0.85))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    @ViewBuilder
    private func diffLineView(_ line: String) -> some View {
        let type: DiffLineType = {
            if line.hasPrefix("@@") { return .hunk }
            if line.hasPrefix("+") { return .added }
            if line.hasPrefix("-") { return .deleted }
            return .normal
        }()

        Text(line)
            .foregroundStyle(diffLineColor(type))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(diffLineBgColor(type))
    }

    enum DiffLineType {
        case hunk
        case normal
        case added
        case deleted
    }

    private func diffLineColor(_ type: DiffLineType) -> Color {
        switch type {
        case .hunk: return .cyan
        case .normal: return .white.opacity(0.8)
        case .added: return .green
        case .deleted: return .red
        }
    }

    private func diffLineBgColor(_ type: DiffLineType) -> Color {
        switch type {
        case .hunk: return .cyan.opacity(0.12)
        case .normal: return .clear
        case .added: return .green.opacity(0.1)
        case .deleted: return .red.opacity(0.1)
        }
    }

    private var aiReviewsPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("AI Code Reviewer & Assistant")
                    .font(.headline)

                Text("Automate pull request reviews! AI reads files changed in this branch, reviews coding patterns against macOS standards, and drafts summaries.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    generateAIPRReview()
                } label: {
                    Label(isRunningAIReview ? "Conducting Code Audits..." : "Run AI Pull Request Review Audit", systemImage: "sparkles")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.accentColor)
                .disabled(isRunningAIReview)

                if isRunningAIReview {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("AI evaluation running on modified diff files...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if !aiReviewSummaryText.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("AI Code Audit Summary Report:")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)

                        Text(aiReviewSummaryText)
                            .font(.system(size: 11, design: .monospaced))
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.black.opacity(0.12))
                            .cornerRadius(6)
                    }
                }
            }
            .padding(24)
        }
    }

    private func fetchPRData() {
        guard let (owner, repo) = ownerAndRepo else { return }

        isLoadingFiles = true
        isLoadingCommits = true
        isLoadingReviews = true

        Task {
            do {
                let fetchedFiles = try await GitHubTokenProvider.service().listPullRequestFiles(owner: owner, repo: repo, number: pr.number)
                self.filesModified = fetchedFiles
            } catch {
                errorMessage = "Failed to load files changed: \(error.localizedDescription)"
                showError = true
            }
            isLoadingFiles = false
        }

        Task {
            do {
                let fetchedCommits = try await GitHubTokenProvider.service().listPullRequestCommits(owner: owner, repo: repo, number: pr.number)
                self.prCommits = fetchedCommits
            } catch {
            }
            isLoadingCommits = false
        }

        Task {
            do {
                self.prReviews = try await GitHubTokenProvider.service().listPullRequestReviews(owner: owner, repo: repo, number: pr.number)
            } catch {
            }
            isLoadingReviews = false
        }

        Task {
            do {
                self.remoteComments = try await GitHubTokenProvider.service().listIssueComments(owner: owner, repo: repo, number: pr.number)
            } catch {
            }
        }
    }

    private func executePostComment() {
        guard let (owner, repo) = ownerAndRepo else { return }
        let text = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isPostingComment = true
        Task {
            do {
                let posted = try await GitHubTokenProvider.service().createIssueComment(owner: owner, repo: repo, number: pr.number, body: text)
                remoteComments.append(posted)
                replyText = ""
            } catch {
                
                localComments.append(LocalComment(author: "You", body: text, date: Date()))
                replyText = ""
                errorMessage = "Comment was saved locally only — posting failed: \(error.localizedDescription)"
                showError = true
            }
            isPostingComment = false
        }
    }

    private func performMerge(method: String) {
        guard let (owner, repo) = ownerAndRepo else { return }

        isMerging = true
        Task {
            do {
                let success = try await GitHubTokenProvider.service().mergePullRequest(owner: owner, repo: repo, number: pr.number, method: method)
                if success {
                    successMessage = "Successfully merged Pull Request #\(pr.number) via \(method)!"
                    showSuccess = true
                } else {
                    errorMessage = "Failed to merge Pull Request."
                    showError = true
                }
            } catch {
                errorMessage = "Merge operation failed: \(error.localizedDescription)"
                showError = true
            }
            isMerging = false
        }
    }

    private func generateAIPRReview() {
        isRunningAIReview = true
        aiReviewSummaryText = ""

        let filesStr = filesModified.map(\.filename).joined(separator: ", ")

        let prompt = """
        You are an AI Pull Request review auditor. Review the following PR state details:
        - PR Number: #\(pr.number)
        - Title: \(pr.title)
        - Description: \(pr.body ?? "No description provided.")
        - Files modified: \(filesStr.isEmpty ? "None" : filesStr)

        Generate an automated review report of exactly 4 lines:
        1. [Overall Assessment] Quick rating (e.g., Looks Good, Requires changes) and summary.
        2. [Suggested Changes] Highlight a minor point (e.g., suggest adding documentation comments or performance parameters).
        3. [Gaps/Risks] Assessment of dependencies or conflicts.
        4. [Review Approval Verdict] Safe to Merge recommendation.
        """

        Task {
            do {
                let response = try await LLMService.shared.generateResponse(prompt: prompt, useContext: false)
                aiReviewSummaryText = response.trimmingCharacters(in: .whitespacesAndNewlines)
            } catch {
                aiReviewSummaryText = "AI review error: \(error.localizedDescription)"
            }
            isRunningAIReview = false
        }
    }
}
