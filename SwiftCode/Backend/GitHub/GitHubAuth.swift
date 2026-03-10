import Foundation

/// Handles GitHub authentication using personal access tokens (PAT).
///
/// Tokens are stored securely in the iOS Keychain via KeychainService.
/// This manager provides a single access point for token retrieval and validation.
final class GitHubAuth {
    static let shared = GitHubAuth()
    private init() {}

    // MARK: - Token Management

    /// The current GitHub personal access token, if set.
    var token: String? {
        KeychainService.shared.get(forKey: KeychainService.githubToken)
    }

    /// Returns true if a GitHub token is stored and non-empty.
    var isAuthenticated: Bool {
        guard let t = token else { return false }
        return !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Store a new personal access token in the Keychain.
    func saveToken(_ token: String) {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        KeychainService.shared.set(trimmed, forKey: KeychainService.githubToken)
    }

    /// Remove the stored token from the Keychain.
    func clearToken() {
        KeychainService.shared.delete(forKey: KeychainService.githubToken)
    }

    // MARK: - Validation

    /// Validate the stored token by fetching the authenticated user.
    /// - Returns: The authenticated GitHub user on success.
    func validateToken() async throws -> GitHubUser {
        guard isAuthenticated else { throw GitHubAuthError.missingToken }
        return try await GitHubAPIBackend.shared.getAuthenticatedUser()
    }

    // MARK: - Authorization Headers

    /// Build an authorized URLRequest for the given URL and HTTP method.
    func authorizedRequest(url: URL, method: String = "GET") -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }
}

// MARK: - Errors

enum GitHubAuthError: LocalizedError {
    case missingToken
    case invalidToken

    var errorDescription: String? {
        switch self {
        case .missingToken:
            return "No GitHub token found. Please add your personal access token in Settings."
        case .invalidToken:
            return "The GitHub token is invalid or has expired."
        }
    }
}
