import SwiftUI

// MARK: - Git History View

struct GitHistoryView: View {
    @EnvironmentObject private var projectManager: ProjectManager
    @EnvironmentObject private var settings: AppSettings

    @State private var commits: [GitHubCommit] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedBranch = "main"
    @State private var branches: [String] = ["main"]
    @State private var selectedCommit: GitHubCommit?

    private var owner: String {
        guard let repo = (projectManager.activeProject)?.githubRepo else { return "" }
        return String(repo.split(separator: "/").first ?? "")
    }

    private var repoName: String {
        guard let repo = (projectManager.activeProject)?.githubRepo else { return "" }
        return String(repo.split(separator: "/").last ?? "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.08, green: 0.08, blue: 0.12).ignoresSafeArea()

                if isLoading {
                    ProgressView("Loading Commits…")
                        .tint(.orange)
                } else if let error = errorMessage {
                    errorView(error)
                } else if commits.isEmpty {
                    emptyView
                } else {
                    commitList
                }
            }
            .navigationTitle("Git History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await loadHistory() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(.orange)
                    }
                    .disabled(isLoading || owner.isEmpty)
                }
            }
            .sheet(item: $selectedCommit) { commit in
                CommitDetailSheet(commit: commit, owner: owner, repo: repoName)
            }
        }
        .preferredColorScheme(.dark)
        .task {
            if commits.isEmpty && !owner.isEmpty {
                await loadHistory()
            }
        }
    }

    // MARK: - Commit List

    private var commitList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                // Branch selector
                if branches.count > 1 {
                    branchPicker
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }

                ForEach(Array(commits.enumerated()), id: \.element.id) { index, commit in
                    commitRow(commit: commit, isLast: index == commits.count - 1)
                        .onTapGesture { selectedCommit = commit }
                }
            }
            .padding(.top, 8)
        }
    }

    private var branchPicker: some View {
        Menu {
            ForEach(branches, id: \.self) { branch in
                Button {
                    selectedBranch = branch
                    Task { await loadHistory() }
                } label: {
                    HStack {
                        Text(branch)
                        if selectedBranch == branch {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Text(selectedBranch)
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.orange.opacity(0.15), in: Capsule())
        }
    }

    private func commitRow(commit: GitHubCommit, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Timeline
            VStack(spacing: 0) {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 10, height: 10)
                    .padding(.top, 5)
                if !isLast {
                    Rectangle()
                        .fill(Color.orange.opacity(0.3))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 14)

            VStack(alignment: .leading, spacing: 6) {
                Text(commit.commit.message.components(separatedBy: "\n").first ?? commit.commit.message)
                    .font(.callout.bold())
                    .foregroundStyle(.white)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if let author = commit.commit.author?.name {
                        Label(author, systemImage: "person.circle")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if let date = commit.commit.author?.date {
                        Text(date, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(String(commit.sha.prefix(8)))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.orange.opacity(0.7))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.top, 6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.02))
        .contentShape(Rectangle())
    }

    // MARK: - Empty / Error Views

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 44))
                .foregroundStyle(.orange.opacity(0.6))
            Text(owner.isEmpty ? "No GitHub Repo Linked" : "No Commits Found")
                .font(.headline)
                .foregroundStyle(.white)
            Text(owner.isEmpty
                 ? "Link a GitHub repository in the GitHub Integration panel."
                 : "This branch has no commit history yet.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 44))
                .foregroundStyle(.red.opacity(0.7))
            Text("Failed To Load History")
                .font(.headline)
                .foregroundStyle(.white)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Retry") {
                Task { await loadHistory() }
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
    }

    // MARK: - Load History

    private func loadHistory() async {
        guard !owner.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let commitsFetch = GitHubService.shared.listCommits(
                owner: owner, repo: repoName, branch: selectedBranch, perPage: 30
            )
            async let branchesFetch = GitHubService.shared.listBranches(owner: owner, repo: repoName)

            commits = try await commitsFetch
            let fetchedBranches = try await branchesFetch
            branches = fetchedBranches.map { $0.name }
            if !branches.contains(selectedBranch) {
                selectedBranch = branches.first ?? "main"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Commit Detail Sheet

struct CommitDetailSheet: View {
    let commit: GitHubCommit
    let owner: String
    let repo: String
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // SHA
                    HStack {
                        Label("SHA", systemImage: "tag")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(commit.sha)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.orange)
                            .textSelection(.enabled)
                            .lineLimit(1)
                    }

                    Divider().opacity(0.3)

                    // Message
                    Text("Commit Message")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Text(commit.commit.message)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)

                    Divider().opacity(0.3)

                    // Author info
                    if let author = commit.commit.author {
                        if let name = author.name {
                            infoRow(label: "Author", value: name, icon: "person.circle")
                        }
                        if let date = author.date {
                            infoRow(label: "Date", value: date.formatted(date: .long, time: .shortened), icon: "calendar")
                        }
                    }

                    // View on GitHub
                    if let urlStr = commit.htmlUrl, let url = URL(string: urlStr) {
                        Divider().opacity(0.3)
                        Link(destination: url) {
                            Label("View On GitHub", systemImage: "safari")
                                .font(.callout)
                                .foregroundStyle(.orange)
                        }
                    }
                }
                .padding(16)
            }
            .background(Color(red: 0.10, green: 0.10, blue: 0.14).ignoresSafeArea())
            .navigationTitle("Commit Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func infoRow(label: String, value: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(value)
                    .font(.callout)
                    .foregroundStyle(.primary)
            }
        }
    }
}
