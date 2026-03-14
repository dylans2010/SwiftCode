import Foundation

enum DeploymentPlatform: String, Codable, CaseIterable, Identifiable {
    case netlify = "Netlify"
    case vercel = "Vercel"
    case githubPages = "GitHub Pages"

    var id: String { self.rawValue }
}

struct DeploymentResult {
    let success: Bool
    let url: String?
    let errorMessage: String?
}

final class DeploymentTargets {
    static let shared = DeploymentTargets()
    private init() {}

    /// Prepares the repository for deployment by staging, committing, and pushing changes.
    func prepareRepositoryForDeployment(project: Project, logHandler: @escaping (String) -> Void) async throws -> Bool {
        logHandler("Preparing repository for deployment...")

        guard let repoURL = project.githubRepo, !repoURL.isEmpty else {
            logHandler("Error: Deployment requires a connected GitHub repository.")
            throw NSError(domain: "Deployment", code: 401, userInfo: [NSLocalizedDescriptionKey: "Deployment requires a connected GitHub repository."])
        }

        let projectPath = await project.directoryURL.path

        // 1. Stage all changes
        logHandler("Staging changes...")
        let addResult = try await BinaryManager.shared.runGitCommand(arguments: ["add", "."], in: projectPath)
        if !addResult.isSuccess {
            logHandler("Failed to stage changes: \(addResult.mergedOutput)")
            return false
        }

        // 2. Check for changes to commit
        let statusResult = try await BinaryManager.shared.runGitCommand(arguments: ["status", "--porcelain"], in: projectPath)
        if !statusResult.stdout.isEmpty {
            logHandler("Committing changes...")
            let commitResult = try await BinaryManager.shared.runGitCommand(arguments: ["commit", "-m", "Prepare for deployment"], in: projectPath)
            if !commitResult.isSuccess {
                logHandler("Failed to commit changes: \(commitResult.mergedOutput)")
                return false
            }
        } else {
            logHandler("No changes to commit.")
        }

        // 3. Push to remote
        logHandler("Pushing to remote GitHub repository...")
        // We assume 'main' for now, or we could detect it.
        let pushResult = try await BinaryManager.shared.runGitCommand(arguments: ["push", "origin", "HEAD"], in: projectPath)
        if !pushResult.isSuccess {
            logHandler("Failed to push changes: \(pushResult.mergedOutput)")
            return false
        }

        logHandler("Repository successfully pushed to GitHub.")
        return true
    }

    /// Routes the deployment to the appropriate platform manager.
    func deploy(
        project: Project,
        platform: DeploymentPlatform,
        token: String?,
        domain: String?,
        logHandler: @escaping (String) -> Void
    ) async throws -> DeploymentResult {

        let success = try await prepareRepositoryForDeployment(project: project, logHandler: logHandler)
        guard success else {
            return DeploymentResult(success: false, url: nil, errorMessage: "Failed to prepare repository.")
        }

        switch platform {
        case .netlify:
            logHandler("Starting Netlify deployment...")
            return try await NetlifyManager.shared.deploy(project: project, token: token, domain: domain, logHandler: logHandler)
        case .vercel:
            logHandler("Starting Vercel deployment...")
            return try await VercelManager.shared.deploy(project: project, token: token, domain: domain, logHandler: logHandler)
        case .githubPages:
            logHandler("Starting GitHub Pages deployment...")
            return try await GitHubPagesManager.shared.deploy(project: project, domain: domain, logHandler: logHandler)
        }
    }
}
