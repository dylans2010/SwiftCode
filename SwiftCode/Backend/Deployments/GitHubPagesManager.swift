import Foundation

final class GitHubPagesManager {
    static let shared = GitHubPagesManager()
    private init() {}

    private let baseURL = URL(string: "https://api.github.com")!

    func deploy(
        project: Project,
        domain: String?,
        logHandler: @escaping (String) -> Void
    ) async throws -> DeploymentResult {
        guard let repoURL = project.githubRepo, !repoURL.isEmpty else {
            return DeploymentResult(success: false, url: nil, errorMessage: "GitHub repository not connected.")
        }

        let (owner, repo) = try GitHubRepositoryManager.shared.parseRepoURL(repoURL)
        let token = DeploymentKeychainManager.shared.retrieveKey(service: .github)

        do {
            logHandler("Checking GitHub Pages configuration for \(owner)/\(repo)...")
            let pagesInfo = try? await getPagesInfo(owner: owner, repo: repo, token: token)

            if pagesInfo == nil {
                logHandler("GitHub Pages not enabled. Enabling now...")
                try await enablePages(owner: owner, repo: repo, token: token, logHandler: logHandler)
            } else {
                logHandler("GitHub Pages is already enabled.")
            }

            logHandler("Ensuring Pages workflow exists...")
            try await ensurePagesWorkflow(project: project, owner: owner, repo: repo, token: token, logHandler: logHandler)

            logHandler("Waiting for GitHub Actions to trigger and complete...")
            let finalStatus = try await pollDeploymentStatus(owner: owner, repo: repo, token: token, logHandler: logHandler)

            if finalStatus == "succeeded" {
                let finalPagesInfo = try await getPagesInfo(owner: owner, repo: repo, token: token)
                let siteURL = domain != nil ? "https://\(domain!)" : finalPagesInfo.htmlUrl
                logHandler("Deployment successful! Live at \(siteURL)")
                return DeploymentResult(success: true, url: siteURL, errorMessage: nil)
            } else {
                return DeploymentResult(success: false, url: nil, errorMessage: "GitHub Pages deployment failed or timed out.")
            }
        } catch {
            logHandler("Error: \(error.localizedDescription)")
            return DeploymentResult(success: false, url: nil, errorMessage: error.localizedDescription)
        }
    }

    private func getPagesInfo(owner: String, repo: String, token: String?) async throws -> GitHubPagesInfo {
        let url = baseURL.appendingPathComponent("repos/\(owner)/\(repo)/pages")
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "GitHubPagesManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Pages not found or error fetching info."])
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(GitHubPagesInfo.self, from: data)
    }

    private func enablePages(owner: String, repo: String, token: String?, logHandler: @escaping (String) -> Void) async throws {
        let url = baseURL.appendingPathComponent("repos/\(owner)/\(repo)/pages")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let body: [String: Any] = [
            "build_type": "workflow",
            "source": [
                "branch": "main",
                "path": "/"
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...201).contains(httpResponse.statusCode) else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "GitHubPagesManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to enable Pages: \(errorMsg)"])
        }
        logHandler("GitHub Pages enabled successfully.")
    }

    private func ensurePagesWorkflow(project: Project, owner: String, repo: String, token: String?, logHandler: @escaping (String) -> Void) async throws {
        let path = ".github/workflows/pages.yml"

        // Check if workflow already exists
        let existingSHA = try? await GitHubService.shared.getFileSHA(owner: owner, repo: repo, path: path, branch: "main")
        if existingSHA != nil {
            logHandler("Pages workflow already exists.")
            return
        }

        let framework = await DeploymentTargets.shared.detectFramework(project: project)
        let buildSteps = generateBuildSteps(for: framework)

        let workflowContent = """
name: Deploy to GitHub Pages
on:
  push:
    branches: ["main"]
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: "pages"
  cancel-in-progress: true

jobs:
  deploy:
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
\(buildSteps)
      - name: Setup Pages
        uses: actions/configure-pages@v4
      - name: Upload artifact
        uses: actions/upload-pages-artifact@v3
        with:
          path: '\(framework.outputDirectory == "." ? "." : framework.outputDirectory)'
      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v4
"""
        try await GitHubService.shared.pushFile(
            owner: owner,
            repo: repo,
            path: path,
            content: workflowContent,
            message: "Add GitHub Pages deployment workflow",
            branch: "main"
        )
        logHandler("Created .github/workflows/pages.yml with \(framework.name) configuration.")
    }

    private func generateBuildSteps(for framework: FrameworkConfig) -> String {
        if let buildCommand = framework.buildCommand {
            return """
      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: 'npm'
      - name: Install dependencies
        run: npm install
      - name: Build
        run: \(buildCommand)
"""
        }
        return ""
    }

    private func pollDeploymentStatus(owner: String, repo: String, token: String?, logHandler: @escaping (String) -> Void) async throws -> String {
        let url = baseURL.appendingPathComponent("repos/\(owner)/\(repo)/pages/deployments")

        for i in 1...60 { // Poll for 10 minutes (10s intervals)
            var request = URLRequest(url: url)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            if let token = token {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }

            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                let deployments = try JSONDecoder().decode(GitHubPagesDeploymentsResponse.self, from: data)
                if let latest = deployments.deployments.first {
                    logHandler("Latest Deployment Status (\(i)): \(latest.status ?? "unknown")")
                    if latest.status == "succeed" { return "succeeded" }
                    if ["fail", "cancel"].contains(latest.status) { return "failed" }
                } else {
                    logHandler("Waiting for deployment to start...")
                }
            }

            try await Task.sleep(nanoseconds: 10_000_000_000)
        }
        return "timed_out"
    }
}

// MARK: - GitHub Pages Models

struct GitHubPagesInfo: Codable {
    let url: String
    let status: String?
    let htmlUrl: String
}

struct GitHubPagesDeploymentsResponse: Codable {
    let deployments: [GitHubPagesDeployment]
}

struct GitHubPagesDeployment: Codable {
    let id: String?
    let status: String?
}
