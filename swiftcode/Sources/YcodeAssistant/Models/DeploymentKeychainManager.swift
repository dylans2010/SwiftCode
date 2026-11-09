import Foundation

public final class DeploymentKeychainManager: Sendable {
    public static let shared = DeploymentKeychainManager()
    public init() {}

    public enum Service: String, Sendable {
        case netlify = "netlify_api_token"
        case vercel = "vercel_api_token"
        case github = "github_personal_access_token"
    }

    public func storeKey(service: Service, key: String) {
        KeychainService.shared.set(key, forKey: service.rawValue)
    }

    public func retrieveKey(service: Service) -> String? {
        return KeychainService.shared.get(forKey: service.rawValue)
    }

    public func deleteKey(service: Service) {
        KeychainService.shared.delete(forKey: service.rawValue)
    }
}
