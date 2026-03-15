import Foundation

enum GitHubSecrets {
    static let clientSecretKey = "CLIENT_SECRET"
    static let secretIDKey = "SECRET_ID"

    nonisolated static var clientSecret: String {
        EnvironmentValueLoader.value(for: clientSecretKey, fallback: "missing_client_secret")
    }

    nonisolated static var secretID: String {
        EnvironmentValueLoader.value(for: secretIDKey, fallback: "missing_secret_id")
    }

    nonisolated static var hasRequiredSecrets: Bool {
        clientSecret != "missing_client_secret" && secretID != "missing_secret_id"
    }
}
