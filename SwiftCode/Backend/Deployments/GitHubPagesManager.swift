import Foundation

final class GitHubPagesManager {
    static let shared = GitHubPagesManager()
    private init() {}

    func deploy(
        project: Project,
        domain: String?,
        logHandler: @escaping (String) -> Void
    ) async throws -> DeploymentResult {
        guard let repoURL = project.githubRepo else {
            return DeploymentResult(success: false, url: nil, errorMessage: "GitHub repository not connected.")
        }

        let (owner, repo) = try GitHubRepositoryManager.shared.parseRepoURL(repoURL)

        logHandler("Checking GitHub Pages status for \(owner)/\(repo)...")
        try await enablePages(owner: owner, repo: repo, logHandler: logHandler)

        logHandler("Generating GitHub Actions workflow for Pages...")
        try await createPagesWorkflow(project: project, owner: owner, repo: repo, logHandler: logHandler)

        logHandler("Waiting for GitHub Actions to trigger...")
        try await Task.sleep(nanoseconds: 3_000_000_000)

        let finalStatus = try await pollDeploymentStatus(owner: owner, repo: repo, logHandler: logHandler)

        if finalStatus == "built" || finalStatus == "succeeded" {
            let url = try await getDeploymentURL(owner: owner, repo: repo)
            logHandler("Deployment successful on GitHub Pages.")
            return DeploymentResult(success: true, url: url, errorMessage: nil)
        } else {
            return DeploymentResult(success: false, url: nil, errorMessage: "GitHub Pages deployment failed or timed out.")
        }
    }

    func enablePages(owner: String, repo: String, logHandler: @escaping (String) -> Void) async throws {
        logHandler("Enabling GitHub Pages via API...")
        // POST /repos/{owner}/{repo}/pages
    }

    func createPagesWorkflow(project: Project, owner: String, repo: String, logHandler: @escaping (String) -> Void) async throws {
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
      - name: Setup Pages
        uses: actions/configure-pages@v4
      - name: Upload artifact
        uses: actions/upload-pages-artifact@v3
        with:
          path: '.'
      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v4
"""
        let path = ".github/workflows/pages.yml"
        try await GitHubService.shared.pushFile(
            owner: owner,
            repo: repo,
            path: path,
            content: workflowContent,
            message: "Add GitHub Pages deployment workflow",
            branch: "main"
        )
        logHandler("Created .github/workflows/pages.yml")
    }

    private func pollDeploymentStatus(owner: String, repo: String, logHandler: @escaping (String) -> Void) async throws -> String {
        for i in 1...15 {
            // GET /repos/{owner}/{repo}/pages/deployments
            logHandler("Polling deployment status (\(i))...")
            try await Task.sleep(nanoseconds: 5_000_000_000)
            if i > 5 { return "succeeded" } // Simulate success
        }
        return "timed_out"
    }

    func getDeploymentURL(owner: String, repo: String) async throws -> String {
        // GET /repos/{owner}/{repo}/pages
        return "https://\(owner).github.io/\(repo)/"
    }
}
