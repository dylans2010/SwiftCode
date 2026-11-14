import Foundation
import SwiftCodeGitHub
import YcodeAssistant
import YcodeIDECore
import YcodeSubprocess

public struct LocalGitIdentity: Sendable {
    public let name: String
    public let email: String
    public let credentialHelper: String
    public let hasSSHAgent: Bool

    public var hasValidIdentity: Bool {
        !name.isEmpty || !email.isEmpty
    }
}

@MainActor
public enum GitHubTokenProvider {
    public static func token() -> String? {
        let storeToken = CodingAssistantServices.shared.store
            .readString(SecretAccount.githubToken)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let storeToken, !storeToken.isEmpty { return storeToken }
        let keychainToken = KeychainService.shared
            .get(forKey: KeychainService.githubToken)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return keychainToken.flatMap { $0.isEmpty ? nil : $0 }
    }

    public static func client() -> GitHubClient {
        let token = token()
        return GitHubClient(tokenProvider: { token })
    }

    public static func service() -> GitHubService {
        let token = token()
        return GitHubService(tokenProvider: { token })
    }

    public static var isUsingLocalIdentity: Bool {
        AppSettings.shared.useLocalGitIdentity
    }

    public static func retrieveLocalGitIdentity(workingDirectory: URL? = nil) async -> LocalGitIdentity {
        let gitPath = AppSettings.shared.gitPath.isEmpty ? "/usr/bin/git" : AppSettings.shared.gitPath
        let gitBinary = URL(fileURLWithPath: gitPath)
        let dir = workingDirectory ?? URL(fileURLWithPath: NSHomeDirectory())

        let nameRes = try? await YcodeSubprocess.ProcessRunnerTool.shared.run(
            executableURL: gitBinary,
            arguments: ["config", "user.name"],
            workingDirectory: dir
        )
        let emailRes = try? await YcodeSubprocess.ProcessRunnerTool.shared.run(
            executableURL: gitBinary,
            arguments: ["config", "user.email"],
            workingDirectory: dir
        )
        let helperRes = try? await YcodeSubprocess.ProcessRunnerTool.shared.run(
            executableURL: gitBinary,
            arguments: ["config", "credential.helper"],
            workingDirectory: dir
        )

        let name = nameRes?.stdout.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let email = emailRes?.stdout.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let helper = helperRes?.stdout.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let hasSSH = ProcessInfo.processInfo.environment["SSH_AUTH_SOCK"] != nil

        return LocalGitIdentity(
            name: name,
            email: email,
            credentialHelper: helper,
            hasSSHAgent: hasSSH
        )
    }

    public static func applyLocalIdentity(workingDirectory: URL? = nil) async -> LocalGitIdentity {
        let identity = await retrieveLocalGitIdentity(workingDirectory: workingDirectory)
        if !identity.name.isEmpty {
            AppSettings.shared.gitUserName = identity.name
        }
        if !identity.email.isEmpty {
            AppSettings.shared.gitUserEmail = identity.email
        }
        AppSettings.shared.useLocalGitIdentity = true
        return identity
    }
}
