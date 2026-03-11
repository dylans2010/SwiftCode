import Foundation

// MARK: - Repository Permission Model

struct RepoPermission: Identifiable {
    var id: String { scope }
    let scope: String
    let humanReadable: String
    let icon: String

    /// Maps a GitHub OAuth scope string to a human-readable description and icon.
    static func from(scope: String) -> RepoPermission {
        switch scope {
        // Repo scopes
        case "repo":
            return RepoPermission(scope: scope, humanReadable: "Full control of private repositories", icon: "folder.fill.badge.gearshape")
        case "repo:status":
            return RepoPermission(scope: scope, humanReadable: "Access commit status", icon: "checkmark.circle.fill")
        case "repo_deployment":
            return RepoPermission(scope: scope, humanReadable: "Access deployment status", icon: "airplane")
        case "public_repo":
            return RepoPermission(scope: scope, humanReadable: "Access public repositories", icon: "globe")
        case "repo:invite":
            return RepoPermission(scope: scope, humanReadable: "Access repository invitations", icon: "envelope.fill")
        case "security_events":
            return RepoPermission(scope: scope, humanReadable: "Read and write security events", icon: "shield.fill")
        // Workflow
        case "workflow":
            return RepoPermission(scope: scope, humanReadable: "Update GitHub Actions workflows", icon: "gearshape.2.fill")
        // Packages
        case "write:packages":
            return RepoPermission(scope: scope, humanReadable: "Upload packages to GitHub Package Registry", icon: "shippingbox.fill")
        case "read:packages":
            return RepoPermission(scope: scope, humanReadable: "Download packages from GitHub Package Registry", icon: "shippingbox")
        case "delete:packages":
            return RepoPermission(scope: scope, humanReadable: "Delete packages from GitHub Package Registry", icon: "shippingbox.fill")
        // Org scopes
        case "admin:org":
            return RepoPermission(scope: scope, humanReadable: "Full control of organizations and teams", icon: "building.2.fill")
        case "write:org":
            return RepoPermission(scope: scope, humanReadable: "Read and write org/team membership and projects", icon: "person.3.fill")
        case "read:org":
            return RepoPermission(scope: scope, humanReadable: "Read org/team membership and projects", icon: "person.3")
        // Public key
        case "admin:public_key":
            return RepoPermission(scope: scope, humanReadable: "Full control of user public keys", icon: "key.fill")
        case "write:public_key":
            return RepoPermission(scope: scope, humanReadable: "Write user public keys", icon: "key")
        case "read:public_key":
            return RepoPermission(scope: scope, humanReadable: "Read user public keys", icon: "key")
        // Hooks
        case "admin:repo_hook":
            return RepoPermission(scope: scope, humanReadable: "Full control of repository hooks", icon: "webhook")
        case "write:repo_hook":
            return RepoPermission(scope: scope, humanReadable: "Write repository hooks", icon: "webhook")
        case "read:repo_hook":
            return RepoPermission(scope: scope, humanReadable: "Read repository hooks", icon: "webhook")
        case "admin:org_hook":
            return RepoPermission(scope: scope, humanReadable: "Full control of organization webhooks", icon: "building.2.crop.circle")
        // User
        case "user":
            return RepoPermission(scope: scope, humanReadable: "Update all user data", icon: "person.fill.badge.plus")
        case "read:user":
            return RepoPermission(scope: scope, humanReadable: "Read all user profile data", icon: "person.fill")
        case "user:email":
            return RepoPermission(scope: scope, humanReadable: "Access user email addresses", icon: "envelope")
        case "user:follow":
            return RepoPermission(scope: scope, humanReadable: "Follow and unfollow users", icon: "person.fill.badge.plus")
        // Misc
        case "gist":
            return RepoPermission(scope: scope, humanReadable: "Create gists", icon: "doc.text.fill")
        case "notifications":
            return RepoPermission(scope: scope, humanReadable: "Access notifications", icon: "bell.fill")
        case "delete_repo":
            return RepoPermission(scope: scope, humanReadable: "Delete repositories", icon: "trash.fill")
        case "write:discussion":
            return RepoPermission(scope: scope, humanReadable: "Read and write team discussions", icon: "bubble.left.and.bubble.right.fill")
        case "read:discussion":
            return RepoPermission(scope: scope, humanReadable: "Read team discussions", icon: "bubble.left.and.bubble.right")
        case "audit_log":
            return RepoPermission(scope: scope, humanReadable: "Full control of audit log", icon: "list.clipboard.fill")
        case "read:audit_log":
            return RepoPermission(scope: scope, humanReadable: "Read audit log", icon: "list.clipboard")
        case "codespace":
            return RepoPermission(scope: scope, humanReadable: "Full control of codespaces", icon: "terminal.fill")
        case "copilot":
            return RepoPermission(scope: scope, humanReadable: "Full control of GitHub Copilot settings", icon: "sparkles")
        case "project":
            return RepoPermission(scope: scope, humanReadable: "Full control of projects", icon: "checklist")
        case "read:project":
            return RepoPermission(scope: scope, humanReadable: "Read access to projects", icon: "checklist")
        case "admin:enterprise":
            return RepoPermission(scope: scope, humanReadable: "Full control of enterprises", icon: "building.columns.fill")
        case "manage_runners:enterprise":
            return RepoPermission(scope: scope, humanReadable: "Manage enterprise runners and runner groups", icon: "server.rack")
        case "manage_billing:enterprise":
            return RepoPermission(scope: scope, humanReadable: "Read and write enterprise billing data", icon: "creditcard.fill")
        case "read:enterprise":
            return RepoPermission(scope: scope, humanReadable: "Read enterprise profile data", icon: "building.columns")
        default:
            return RepoPermission(scope: scope, humanReadable: scope.replacingOccurrences(of: "_", with: " ").capitalized, icon: "lock.open.fill")
        }
    }
}

// MARK: - Repo Permission Manager

final class RepoPermManager: ObservableObject {
    static let shared = RepoPermManager()
    private init() {}

    @Published var permissions: [RepoPermission] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hasChecked = false

    private let baseURL = URL(string: "https://api.github.com")!

    /// Fetches the scopes for the stored GitHub token by inspecting the X-OAuth-Scopes response header.
    @MainActor
    func fetchPermissions() async {
        guard let token = KeychainService.shared.get(forKey: KeychainService.githubToken), !token.isEmpty else {
            errorMessage = "No GitHub token configured. Add one in GitHub & Git Configuration."
            permissions = []
            hasChecked = true
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let url = baseURL.appendingPathComponent("user")
            var request = URLRequest(url: url)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (_, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }

            guard (200...299).contains(http.statusCode) else {
                let msg = http.statusCode == 401
                    ? "Invalid or expired token."
                    : "GitHub API error \(http.statusCode)."
                errorMessage = msg
                permissions = []
                isLoading = false
                hasChecked = true
                return
            }

            let scopesHeader = http.value(forHTTPHeaderField: "X-OAuth-Scopes") ?? ""
            let scopes = scopesHeader
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            permissions = scopes.map { RepoPermission.from(scope: $0) }
            hasChecked = true
        } catch {
            errorMessage = error.localizedDescription
            permissions = []
            hasChecked = true
        }

        isLoading = false
    }
}
