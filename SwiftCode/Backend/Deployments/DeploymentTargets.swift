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

struct FrameworkConfig {
    let name: String
    let buildCommand: String?
    let outputDirectory: String
}

final class DeploymentTargets {
    static let shared = DeploymentTargets()
    private init() {}

    /// Prepares the repository for deployment by staging, committing, and pushing changes using GitHub API.
    func prepareRepositoryForDeployment(project: Project, logHandler: @escaping (String) -> Void) async throws -> Bool {
        logHandler("Initializing repository preparation workflow...")

        guard let repoURL = project.githubRepo, !repoURL.isEmpty else {
            logHandler("CRITICAL ERROR: No GitHub repository is linked to this project.")
            logHandler("Please go to Project Settings and connect a GitHub repository before deploying.")
            throw NSError(domain: "Deployment", code: 401, userInfo: [NSLocalizedDescriptionKey: "No GitHub repository connected. Please link a repository in Project Settings before starting deployment."])
        }

        logHandler("Validating repository: \(repoURL)")
        let (owner, repo) = try GitHubRepositoryManager.shared.parseRepoURL(repoURL)

        do {
            logHandler("Connecting to GitHub Data API for \(owner)/\(repo)...")
            logHandler("Scanning project directory for changes...")

            logHandler("Pushing complete project codebase to GitHub...")
            try await GitHubService.shared.pushProject(
                project,
                owner: owner,
                repo: repo,
                commitMessage: "Prepare for deployment: Sync codebase",
                branch: "main"
            )
            logHandler("✓ Codebase successfully synchronized with remote repository.")
            return true
        } catch {
            logHandler("FAILED to push changes to GitHub: \(error.localizedDescription)")
            logHandler("Suggestion: Check your GitHub Personal Access Token permissions (needs 'repo' scope).")
            throw error
        }
    }

    /// Detects the framework used in the project.
    func detectFramework(project: Project) async -> FrameworkConfig {
        let projectPath = await project.directoryURL.path
        let fileManager = FileManager.default

        // Detect Next.js
        if fileManager.fileExists(atPath: "\(projectPath)/next.config.js") ||
           fileManager.fileExists(atPath: "\(projectPath)/next.config.mjs") {
            return FrameworkConfig(name: "Next.js", buildCommand: "npm run build", outputDirectory: ".next")
        }

        // Detect Vite (React, Vue, etc.)
        if fileManager.fileExists(atPath: "\(projectPath)/vite.config.js") ||
           fileManager.fileExists(atPath: "\(projectPath)/vite.config.ts") {
            return FrameworkConfig(name: "Vite", buildCommand: "npm run build", outputDirectory: "dist")
        }

        // Detect Nuxt
        if fileManager.fileExists(atPath: "\(projectPath)/nuxt.config.js") ||
           fileManager.fileExists(atPath: "\(projectPath)/nuxt.config.ts") {
            return FrameworkConfig(name: "Nuxt", buildCommand: "npm run build", outputDirectory: ".output/public")
        }

        // Detect Astro
        if fileManager.fileExists(atPath: "\(projectPath)/astro.config.mjs") {
            return FrameworkConfig(name: "Astro", buildCommand: "npm run build", outputDirectory: "dist")
        }

        // Detect generic package.json
        if fileManager.fileExists(atPath: "\(projectPath)/package.json") {
            return FrameworkConfig(name: "Node.js", buildCommand: "npm run build", outputDirectory: "dist")
        }

        // Default to static
        return FrameworkConfig(name: "Static", buildCommand: nil, outputDirectory: ".")
    }

    /// Routes the deployment to the appropriate platform manager.
    func deploy(
        project: Project,
        platform: DeploymentPlatform,
        token: String?,
        domain: String?,
        logHandler: @escaping (String) -> Void
    ) async throws -> DeploymentResult {

        logHandler("Detecting framework...")
        let framework = await detectFramework(project: project)
        logHandler("Detected Framework: \(framework.name)")

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
