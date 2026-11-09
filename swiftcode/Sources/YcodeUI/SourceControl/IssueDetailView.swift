import SwiftUI
import SwiftCodeGitHub
import YcodeAssistant

@MainActor
struct IssueDetailView: View {
    let issue: GitHubIssue
    let owner: String
    let repo: String
    @Environment(\.dismiss) private var dismiss

    @State private var commentText = ""
    @State private var commentList: [GitHubIssueComment] = []
    @State private var isLoadingComments = false
    @State private var isPostingComment = false
    @State private var isClosing = false
    @State private var issueState: String
    @State private var errorMessage: String?

    @State private var isRunningAISummary = false
    @State private var aiSummaryText = ""

    init(issue: GitHubIssue, owner: String, repo: String) {
        self.issue = issue
        self.owner = owner
        self.repo = repo
        _issueState = State(initialValue: issue.state)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Issue #\(issue.number): \(issue.title)", systemImage: "exclamationmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.cyan)

                Spacer()

                Button(issueState == "open" ? "Close Issue" : "Reopen Issue") {
                    Task { await toggleIssueState() }
                }
                .buttonStyle(.bordered)
                .disabled(isClosing)

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .liquidGlass(style: .subtle, cornerRadius: 10)

            Divider()

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Text(issueState.uppercased())
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.cyan.opacity(0.12))
                                    .foregroundStyle(.cyan)
                                    .cornerRadius(4)

                                Text("opened by \(issue.userLogin) on \(issue.createdAt?.formatted(date: .abbreviated, time: .shortened) ?? "unknown date")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Text(issue.body ?? "No description provided.")
                                .font(.body)
                                .padding(.top, 6)
                        }
                        .padding()
                        .background(Color.secondary.opacity(0.04))
                        .cornerRadius(6)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("LABELS")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)

                        if issue.labels.isEmpty {
                            Text("No labels.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            HStack(spacing: 8) {
                                ForEach(issue.labels, id: \.self) { label in
                                    Label(label, systemImage: "tag.fill")
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.red.opacity(0.1))
                                        .foregroundStyle(.red)
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("AI Issue Analyzer").font(.subheadline.bold())
                        Text("Let AI analyze the issue's scope, bug origin, and recommend a specific solution plan.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button {
                            generateAIIssueSummary()
                        } label: {
                            Label(isRunningAISummary ? "Analyzing Bug..." : "Analyze Issue with AI", systemImage: "sparkles")
                        }
                        .buttonStyle(.bordered)
                        .disabled(isRunningAISummary)

                        if isRunningAISummary {
                            ProgressView().controlSize(.small)
                        }

                        if !aiSummaryText.isEmpty {
                            Text(aiSummaryText)
                                .font(.system(size: 11, design: .monospaced))
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.black.opacity(0.12))
                                .cornerRadius(6)
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("CONVERSATION FEED")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)

                        if isLoadingComments {
                            ProgressView().controlSize(.small)
                        } else if commentList.isEmpty {
                            Text("No comments yet.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        ForEach(commentList) { comment in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(comment.userLogin).bold().font(.caption)
                                    Spacer()
                                    if let created = comment.createdAt {
                                        Text(created, style: .relative).font(.caption2).foregroundStyle(.secondary)
                                    }
                                }
                                Text(comment.body)
                                    .font(.subheadline)
                            }
                            .padding(.vertical, 4)
                            Divider()
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Add comment").font(.caption.bold())
                            TextEditor(text: $commentText)
                                .frame(height: 80)
                                .border(Color.secondary.opacity(0.2), width: 1)

                            Button(isPostingComment ? "Posting..." : "Comment") {
                                executePostComment()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.cyan)
                            .disabled(commentText.trimmingCharacters(in: .whitespaces).isEmpty || isPostingComment)
                        }
                    }
                }
                .padding(24)
            }
        }
        .frame(width: 550, height: 520)
        .task { await loadComments() }
    }

    private func loadComments() async {
        isLoadingComments = true
        defer { isLoadingComments = false }
        commentList = (try? await GitHubTokenProvider.service().listIssueComments(owner: owner, repo: repo, number: issue.number)) ?? []
    }

    private func toggleIssueState() async {
        isClosing = true
        defer { isClosing = false }
        let target = issueState == "open" ? "closed" : "open"
        do {
            let updated = try await GitHubTokenProvider.service().updateIssue(owner: owner, repo: repo, number: issue.number, state: target)
            issueState = updated.state
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func executePostComment() {
        let text = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isPostingComment = true
        Task {
            do {
                let posted = try await GitHubTokenProvider.service().createIssueComment(owner: owner, repo: repo, number: issue.number, body: text)
                commentList.append(posted)
                commentText = ""
            } catch {
                errorMessage = "Failed to post comment: \(error.localizedDescription)"
            }
            isPostingComment = false
        }
    }

    private func generateAIIssueSummary() {
        isRunningAISummary = true
        aiSummaryText = ""

        let prompt = """
        You are an expert AI software debugging engineer.
        Analyze this issue description and prepare an automated bug report:
        - Title: \(issue.title)
        - Body: \(issue.body ?? "No description provided.")

        Provide exactly 3 lines:
        1. [Root Cause Analysis] Hypothesis of what is triggering the reported issue.
        2. [Correction Prescription] Code change suggestion.
        3. [Severity Rating] CVSS 3.1 Severity index evaluation (e.g. Medium 4.2).
        """

        Task {
            do {
                let response = try await LLMService.shared.generateResponse(prompt: prompt, useContext: false)
                aiSummaryText = response.trimmingCharacters(in: .whitespacesAndNewlines)
            } catch {
                aiSummaryText = "AI analysis failed: \(error.localizedDescription)"
            }
            isRunningAISummary = false
        }
    }
}
