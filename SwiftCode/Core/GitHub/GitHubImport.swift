import Foundation

/// High-level entry point for importing a GitHub repository into SwiftCode.
///
/// This manager wraps the lower-level `GitHubImporter` from the Backend layer,
/// providing a simple API for the UI layer to import repositories by URL or owner/repo pair.
///
/// All import logic, ZIP extraction, and project registration are handled by
/// `GitHubImporter` in the Backend/GitHub layer.
final class GitHubImportManager {
    static let shared = GitHubImportManager()
    private init() {}

    // MARK: - Import from URL

    /// Import a GitHub repository from a URL string such as "https://github.com/owner/repo".
    /// - Returns: The newly created Project.
    func importRepository(from urlString: String, branch: String = "main") async throws -> Project {
        try await GitHubImporter.shared.importRepository(from: urlString, branch: branch)
    }

    /// Import a GitHub repository given explicit owner and repo name.
    /// - Returns: The newly created Project.
    func importRepository(owner: String, repo: String, branch: String = "main") async throws -> Project {
        try await GitHubImporter.shared.importRepository(owner: owner, repo: repo, branch: branch)
    }
}
