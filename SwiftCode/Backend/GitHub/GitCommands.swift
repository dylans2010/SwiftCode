import Foundation

/// Handles Git-style operations for projects: push, pull, commit, and branch management.
///
/// All operations read GitHub configuration (token, repository URL) from
/// the active project and GeneralSettingsView's GitHub settings stored in AppSettings.
///
/// Push stages changed files, creates a commit, and pushes to the remote repository
/// using the GitHub Contents API.
///
/// Pull downloads the latest file versions from the remote and merges them into the
/// local project directory.
final class GitCommands {
    static let shared = GitCommands()
    private init() {}

    // MARK: - Push

    /// Stage all changed files, create a commit, and push to the remote repository.
    ///
    /// - Parameters:
    ///   - project: The local project to push.
    ///   - commitMessage: The commit message.
    /// - Throws: `GitCommandsError.missingRemote` if no GitHub repo is linked to the project.
    func push(project: Project, commitMessage: String) async throws {
        guard let repoURL = project.githubRepo, !repoURL.isEmpty else {
            throw GitCommandsError.missingRemote
        }
        let (owner, repo) = try GitHubRepositoryManager.shared.parseRepoURL(repoURL)
        try await GitHubRepositoryManager.shared.pushProject(
            project,
            owner: owner,
            repo: repo,
            commitMessage: commitMessage
        )
    }

    /// Push a single file to the remote repository.
    func pushFile(path: String, content: String, commitMessage: String, project: Project) async throws {
        guard let repoURL = project.githubRepo, !repoURL.isEmpty else {
            throw GitCommandsError.missingRemote
        }
        let (owner, repo) = try GitHubRepositoryManager.shared.parseRepoURL(repoURL)
        let existingSHA = try? await GitHubAPIBackend.shared.getFileSHA(owner: owner, repo: repo, path: path)
        try await GitHubAPIBackend.shared.pushFile(
            owner: owner,
            repo: repo,
            path: path,
            content: content,
            message: commitMessage,
            sha: existingSHA
        )
    }

    // MARK: - Pull

    /// Fetch remote changes and merge them into the local project.
    ///
    /// Each file in the remote repository tree is downloaded and written to disk.
    /// Local files not present in the remote are preserved (non-destructive pull).
    ///
    /// - Parameters:
    ///   - project: The local project to update.
    ///   - branch: The remote branch to pull from (default: main).
    func pull(project: Project, branch: String = "main") async throws {
        guard let repoURL = project.githubRepo, !repoURL.isEmpty else {
            throw GitCommandsError.missingRemote
        }
        let (owner, repo) = try GitHubRepositoryManager.shared.parseRepoURL(repoURL)
        let tree = try await GitHubAPIBackend.shared.getRepoTree(owner: owner, repo: repo, branch: branch)
        let files = tree.filter { $0.type == "blob" }

        for entry in files {
            try await GitHubRepositoryManager.shared.pullFile(
                owner: owner,
                repo: repo,
                path: entry.path,
                into: project
            )
        }

        // Refresh the file tree on the main actor after pulling
        await MainActor.run {
            ProjectManager.shared.refreshFileTree(for: project)
        }
    }

    // MARK: - Branch Listing

    /// List all branches for the repository linked to the project.
    func listBranches(for project: Project) async throws -> [GitHubBranch] {
        guard let repoURL = project.githubRepo, !repoURL.isEmpty else {
            throw GitCommandsError.missingRemote
        }
        let (owner, repo) = try GitHubRepositoryManager.shared.parseRepoURL(repoURL)
        return try await GitHubAPIBackend.shared.listBranches(owner: owner, repo: repo)
    }

    // MARK: - Recent Commits

    /// Fetch recent commits for the project's linked repository.
    func recentCommits(for project: Project, branch: String = "main", count: Int = 20) async throws -> [GitHubCommit] {
        guard let repoURL = project.githubRepo, !repoURL.isEmpty else {
            throw GitCommandsError.missingRemote
        }
        let (owner, repo) = try GitHubRepositoryManager.shared.parseRepoURL(repoURL)
        return try await GitHubAPIBackend.shared.listCommits(
            owner: owner,
            repo: repo,
            branch: branch,
            perPage: count
        )
    }
}

// MARK: - Errors

enum GitCommandsError: LocalizedError {
    case missingRemote
    case pushFailed(String)
    case pullFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingRemote:
            return "No GitHub repository is linked to this project. Please set a repository URL in the GitHub settings."
        case .pushFailed(let reason):
            return "Push failed: \(reason)"
        case .pullFailed(let reason):
            return "Pull failed: \(reason)"
        }
    }
}
