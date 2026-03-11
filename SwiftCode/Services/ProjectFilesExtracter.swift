import Foundation
import ZIPFoundation

/// Extracts generated project files from GitHub Actions artifacts and integrates them locally.
public final class ProjectFilesExtracter {
    public static let shared = ProjectFilesExtracter()
    private init() {}

    private let fm = FileManager.default

    /// Polls for the completion of a workflow run and downloads/integrates its artifacts.
    /// - Parameters:
    ///   - project: The local project to update.
    ///   - owner: GitHub repository owner.
    ///   - repo: GitHub repository name.
    ///   - branch: The branch the workflow was triggered on.
    ///   - progress: A closure called with progress updates (0.0 to 1.0) and status messages.
    ///   - logCallback: Optional closure to receive real-time logs.
    public func extractArtifacts(
        for project: Project,
        owner: String,
        repo: String,
        branch: String,
        progress: @escaping (Double, String) -> Void,
        logCallback: ((String) -> Void)? = nil
    ) async throws {
        progress(0.1, "Waiting for workflow to start...")

        // 1. Find the recent workflow run
        var run: WorkflowRun?
        for _ in 0..<12 { // Wait up to 1 minute for run to appear
            let runs = try await GitHubService.shared.listWorkflowRuns(owner: owner, repo: repo)
            run = runs.first { $0.headBranch == branch && $0.status != "completed" }
            if run != nil { break }
            try await Task.sleep(for: .seconds(5))
        }

        guard let activeRun = run else {
            // Check if it already completed quickly
            let runs = try await GitHubService.shared.listWorkflowRuns(owner: owner, repo: repo)
            if let completedRun = runs.first(where: { $0.headBranch == branch }) {
                run = completedRun
            } else {
                throw NSError(domain: "ProjectFilesExtracter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Workflow run not found."])
            }
        }

        // 2. Poll for completion and fetch logs
        progress(0.2, "Workflow running...")
        var currentRun = activeRun
        var lastLogJobID: Int?

        while currentRun.isRunning {
            try await Task.sleep(for: .seconds(5))

            // Update run status
            currentRun = try await GitHubService.shared.getWorkflowRun(owner: owner, repo: repo, runID: currentRun.id)
            progress(0.4, "Workflow status: \(currentRun.status.capitalized)...")

            // Try to fetch logs
            do {
                let jobs = try await GitHubService.shared.listWorkflowJobs(owner: owner, repo: repo, runID: currentRun.id)
                if let firstJob = jobs.first {
                    let logs = try await GitHubService.shared.getJobLogs(owner: owner, repo: repo, jobID: firstJob.id)
                    logCallback?(logs)
                }
            } catch {
                // Ignore log fetching errors to keep the process running
                print("Failed to fetch logs: \(error.localizedDescription)")
            }
        }

        guard currentRun.conclusion == "success" else {
            throw NSError(domain: "ProjectFilesExtracter", code: 2, userInfo: [NSLocalizedDescriptionKey: "Workflow failed with conclusion: \(currentRun.conclusion ?? "unknown")"])
        }

        // 3. Find and download artifact
        progress(0.6, "Downloading artifacts...")
        let artifacts = try await GitHubService.shared.listWorkflowArtifacts(owner: owner, repo: repo, runID: currentRun.id)
        guard let projectArtifact = artifacts.first(where: { $0.name == "xcode-project" }) else {
            throw NSError(domain: "ProjectFilesExtracter", code: 3, userInfo: [NSLocalizedDescriptionKey: "Artifact 'xcode-project' not found."])
        }

        let zipData = try await GitHubService.shared.downloadArtifact(owner: owner, repo: repo, artifactID: projectArtifact.id)

        // 4. Integrate into local project
        progress(0.8, "Integrating files...")
        try await integrate(zipData: zipData, into: project)

        progress(1.0, "Integration complete!")
    }

    private func integrate(zipData: Data, into project: Project) async throws {
        let tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tempDir) }

        let zipURL = tempDir.appendingPathComponent("artifacts.zip")
        try zipData.write(to: zipURL)

        let extractionDir = tempDir.appendingPathComponent("extracted")
        try fm.createDirectory(at: extractionDir, withIntermediateDirectories: true)

        // Use ZIPFoundation's unzipItem, which is compatible with iOS
        try fm.unzipItem(at: zipURL, to: extractionDir)

        let projectDir = await project.directoryURL
        let items = try fm.contentsOfDirectory(at: extractionDir, includingPropertiesForKeys: nil)

        for item in items {
            let destURL = projectDir.appendingPathComponent(item.lastPathComponent)
            if fm.fileExists(atPath: destURL.path) {
                try fm.removeItem(at: destURL)
            }
            try fm.moveItem(at: item, to: destURL)
        }

        // Integrity check: verify that essential files are present
        let projectName = project.name
        let xcodeProj = projectDir.appendingPathComponent("\(projectName).xcodeproj")
        guard fm.fileExists(atPath: xcodeProj.path) else {
            throw NSError(domain: "ProjectFilesExtracter", code: 4, userInfo: [NSLocalizedDescriptionKey: "Integrity check failed: \(projectName).xcodeproj missing after extraction."])
        }

        // Refresh the file tree
        await MainActor.run {
            ProjectManager.shared.refreshFileTree(for: project)
        }
    }
}
