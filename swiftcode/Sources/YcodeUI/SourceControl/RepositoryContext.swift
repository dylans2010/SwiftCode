import Foundation
import SwiftUI
import Observation
import YcodeIDECore
import SwiftCodeGitHub
import YcodeAssistant

@Observable
@MainActor
public final class RepositoryContext: Sendable {
    public static let shared = RepositoryContext()

    public enum DisplayMode: String, CaseIterable, Identifiable, Codable {
        case connectedRepository = "Associated Repository"
        case entireAccount = "Entire Account"

        public var id: String { self.rawValue }
    }

    var displayMode: DisplayMode = .connectedRepository
    var cachedMetadata: GitHubRepository? = nil
    var loadedReleasesCount: Int = 0
    var loadedBranchesCount: Int = 0
    var loadedPullRequestsCount: Int = 0
    var loadedLanguages: [String] = []
    var syncEventsCount: Int = 0
    var showingSetRepoSheet: Bool = false
    var isLoadingMetadata: Bool = false

    private init() {}

    public var isAuthenticated: Bool {
        guard let token = KeychainService.shared.get(forKey: KeychainService.githubToken) else { return false }
        return !token.isEmpty
    }

    public var activeProject: YcodeIDECore.Project? {
        ProjectSessionStore.shared.activeProject
    }

    public var connectedRepository: String? {
        guard let repoStr = activeProject?.githubRepo, !repoStr.isEmpty else { return nil }
        if let parsed = try? GitHubRepositoryManager.shared.parseRepoURL(repoStr) {
            return "\(parsed.owner)/\(parsed.repo)"
        }
        return repoStr
    }

    public var ownerAndRepo: (String, String)? {
        guard let repoStr = connectedRepository, !repoStr.isEmpty else { return nil }
        let parts = repoStr.split(separator: "/")
        guard parts.count == 2 else { return nil }
        return (String(parts[0]), String(parts[1]))
    }

    public func triggerSync() {
        syncEventsCount += 1
    }

    public func connectRepository(_ repoName: String) {
        guard let project = ProjectSessionStore.shared.activeProject else { return }
        ProjectSessionStore.shared.updateProjectSettings(
            description: project.description ?? "",
            githubRepo: repoName,
            for: project
        )
        triggerSync()
        Task {
            await fetchMetadata()
        }
    }

    public func disconnectRepository() {
        guard let project = ProjectSessionStore.shared.activeProject else { return }
        ProjectSessionStore.shared.updateProjectSettings(
            description: project.description ?? "",
            githubRepo: nil,
            for: project
        )
        cachedMetadata = nil
        loadedReleasesCount = 0
        loadedBranchesCount = 0
        loadedPullRequestsCount = 0
        loadedLanguages = []
        triggerSync()
    }

    public func fetchMetadata() async {
        guard let token = KeychainService.shared.get(forKey: KeychainService.githubToken), !token.isEmpty else { return }
        guard let (owner, repo) = ownerAndRepo else { return }

        isLoadingMetadata = true
        do {
            let details = try await GitHubService.shared.getRepository(owner: owner, repo: repo)
            self.cachedMetadata = details

            if let branches = try? await GitHubService.shared.listBranches(owner: owner, repo: repo) {
                self.loadedBranchesCount = branches.count
            }
            if let releases = try? await GitHubService.shared.listReleases(owner: owner, repo: repo) {
                self.loadedReleasesCount = releases.count
            }
            if let primary = details.language {
                self.loadedLanguages = [primary]
            }

            if let prs = try? await GitHubService.shared.listPullRequests(owner: owner, repo: repo) {
                self.loadedPullRequestsCount = prs.count
            }

            triggerSync()
        } catch {
            print("Failed to fetch repository metadata: \(error)")
        }
        isLoadingMetadata = false
    }
}
