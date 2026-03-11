import SwiftUI

struct PrepareCompileWaitingView: View {
    let project: Project
    @Environment(\.dismiss) private var dismiss
    @State private var isPreparing = true
    @State private var statusMessage = "Preparing For Completion"
    @State private var subtext = "SwiftCode is currently preparing your app so you can build it, please wait…"
    @State private var progress: Double = 0.0
    @State private var errorMessage: String?
    @State private var logs: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.10, green: 0.10, blue: 0.14).ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer()

                    if isPreparing {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(1.5)
                            .tint(.blue)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.green)
                    }

                    VStack(spacing: 8) {
                        Text(statusMessage)
                            .font(.title2.bold())
                            .foregroundStyle(.primary)

                        Text(subtext)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)

                        if isPreparing {
                            ProgressView(value: progress, total: 1.0)
                                .progressViewStyle(.linear)
                                .padding(.horizontal, 48)
                                .padding(.top, 16)
                        }

                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .padding(.top, 8)
                        }

                        if !logs.isEmpty {
                            ScrollView {
                                Text(logs)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(8)
                            }
                            .background(Color.black.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .frame(height: 150)
                            .padding(.top, 16)
                            .padding(.horizontal, 24)
                        }
                    }

                    Spacer()
                }
            }
            .navigationTitle("Prepare Compiling")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .disabled(isPreparing)
                }
            }
        }
        .task {
            await prepare()
        }
    }

    // MARK: - Preparation

    private func prepare() async {
        isPreparing = true
        errorMessage = nil
        logs = ""

        do {
            // 0. Skip generation if artifacts already exist
            let projectDir = await project.directoryURL
            let projectName = project.name
            if ProjectBuilderManager.shared.hasBuildArtifacts(in: projectDir, projectName: projectName) {
                statusMessage = "Up to Date"
                subtext = "Project already has build artifacts. Skipping generation."
                progress = 1.0
                isPreparing = false
                try? await Task.sleep(for: .seconds(1.0))
                dismiss()
                return
            }

            // 1. Ensure project is linked to GitHub
            guard let repoURL = project.githubRepo else {
                throw NSError(domain: "PrepareCompile", code: 1, userInfo: [NSLocalizedDescriptionKey: "Project must be linked to a GitHub repository for remote generation."])
            }

            let (owner, repo) = try GitHubRepositoryManager.shared.parseRepoURL(repoURL)
            let branch = "build-project"

            // 2. Trigger remote generation
            statusMessage = "Uploading Project"
            subtext = "Pushing your files to GitHub Actions..."
            progress = 0.05
            try await ProjectBuilderManager.shared.triggerRemoteGeneration(for: project)

            // 3. Extract artifacts and monitor progress
            try await ProjectFilesExtracter.shared.extractArtifacts(
                for: project,
                owner: owner,
                repo: repo,
                branch: branch,
                progress: { prog, status in
                    Task { @MainActor in
                        self.progress = prog
                        self.subtext = status
                    }
                },
                logCallback: { newLogs in
                    Task { @MainActor in
                        self.logs = newLogs
                    }
                }
            )

            statusMessage = "Ready!"
            subtext = "Project files integrated successfully."
            isPreparing = false

            try? await Task.sleep(for: .seconds(1.0))
            dismiss()

        } catch {
            isPreparing = false
            statusMessage = "Failed"
            errorMessage = error.localizedDescription
            subtext = "An error occurred during remote generation."
        }
    }
}
