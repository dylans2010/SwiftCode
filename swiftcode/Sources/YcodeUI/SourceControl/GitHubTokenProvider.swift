import Foundation
import SwiftCodeGitHub
import YcodeAssistant
import YcodeIDECore







@MainActor
enum GitHubTokenProvider {
    static func token() -> String? {
        let storeToken = CodingAssistantServices.shared.store
            .readString(SecretAccount.githubToken)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let storeToken, !storeToken.isEmpty { return storeToken }
        let keychainToken = KeychainService.shared
            .get(forKey: KeychainService.githubToken)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return keychainToken.flatMap { $0.isEmpty ? nil : $0 }
    }

    static func client() -> GitHubClient {
        let token = token()
        return GitHubClient(tokenProvider: { token })
    }

    
    
    
    
    static func service() -> GitHubService {
        let token = token()
        return GitHubService(tokenProvider: { token })
    }
}
