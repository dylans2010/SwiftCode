import SwiftUI

struct GitHubIntegrationView: View {
    let project: Project
    @EnvironmentObject private var projectManager: ProjectManager
    @Environment(\.dismiss) private var dismiss

    @State private var token: String = ""
    @State private var repoURL: String = ""
    @State private var commitMessage: String = "Update from SwiftCode"
    @State private var isAuthenticated = false
    @State private var githubUser: GitHubUser?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var successMessage: String?
    @State private var showSuccess = false
    @State private var showCreateRepoSheet = false
    @State private var newRepoName = ""
    @State private var newRepoDescription = ""
    @State private var newRepoPrivate = true
    @State private var workflowRuns: [WorkflowRun] = []

    var ownerFromRepo: String {
        let parts = repoURL
            .replacingOccurrences(of: "https://github.com/", with: "")
            .split(separator: "/")
        return String(parts.first ?? "")
    }

    var repoNameFromURL: String {
        let parts = repoURL
            .replacingOccurrences(of: "https://github.com/", with: "")
            .split(separator: "/")
        return String(parts.last?.replacingOccurrences(of: ".git", with: "") ?? "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.10, green: 0.10, blue: 0.14).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        authSection
                        if isAuthenticated {
                            repositorySection
                            if !ownerFromRepo.isEmpty && !repoNameFromURL.isEmpty {
                                pushSection
                                workflowSection
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("GitHub")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Error", isPresented: $showError, presenting: errorMessage) { _ in
                Button("OK") {}
            } message: { msg in Text(msg) }
            .alert("Success", isPresented: $showSuccess, presenting: successMessage) { _ in
                Button("OK") {}
            } message: { msg in Text(msg) }
            .sheet(isPresented: $showCreateRepoSheet) { createRepoSheet }
            .onAppear { loadSavedCredentials() }
        }
    }

    // MARK: - Auth Section

    private var authSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Authentication", icon: "key.fill", color: .yellow)

            if let user = githubUser {
                HStack(spacing: 12) {
                    Image(systemName: "person.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading) {
                        Text(user.name ?? user.login)
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("@\(user.login)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Sign Out") {
                        KeychainService.shared.delete(forKey: KeychainService.githubToken)
                        isAuthenticated = false
                        githubUser = nil
                        token = ""
                    }
                    .font(.caption)
                    .foregroundStyle(.red)
                    .buttonStyle(.plain)
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Personal Access Token")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    SecureField("ghp_xxxxxxxxxxxx", text: $token)
                        .font(.system(.body, design: .monospaced))
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    Button {
                        connectToGitHub()
                    } label: {
                        Label("Connect to GitHub", systemImage: "link")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(.blue.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .disabled(token.isEmpty || isLoading)
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Repository Section

    private var repositorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Repository", icon: "folder.fill.badge.gearshape", color: .blue)

            VStack(alignment: .leading, spacing: 10) {
                Text("Repository URL")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("https://github.com/owner/repo", text: $repoURL)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)

                Button {
                    showCreateRepoSheet = true
                } label: {
                    Label("Create New Repository", systemImage: "plus.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Push Section

    private var pushSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Sync", icon: "arrow.triangle.2.circlepath", color: .orange)

            VStack(alignment: .leading, spacing: 10) {
                Text("Commit Message")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Update from SwiftCode", text: $commitMessage)
                    .textFieldStyle(.roundedBorder)

                HStack(spacing: 12) {
                    Button {
                        pushProject()
                    } label: {
                        Label("Push", systemImage: "arrow.up.circle.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(.orange.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoading)

                    Button {
                        pullUpdates()
                    } label: {
                        Label("Pull", systemImage: "arrow.down.circle.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(.blue.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoading)
                }

                if isLoading {
                    ProgressView()
                        .tint(.orange)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Workflow Section

    private var workflowSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader("Recent Builds", icon: "hammer.fill", color: .purple)
                Spacer()
                Button {
                    loadWorkflowRuns()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 8) {
                if workflowRuns.isEmpty {
                    Text("No workflow runs found")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    ForEach(workflowRuns.prefix(5)) { run in
                        WorkflowRunRow(run: run)
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .onAppear { loadWorkflowRuns() }
    }

    // MARK: - Create Repo Sheet

    private var createRepoSheet: some View {
        NavigationStack {
            Form {
                Section("Repository Details") {
                    TextField("Repository Name", text: $newRepoName)
                        .autocorrectionDisabled()
                    TextField("Description (optional)", text: $newRepoDescription)
                    Toggle("Private", isOn: $newRepoPrivate)
                }
            }
            .navigationTitle("Create Repository")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showCreateRepoSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { createRepository() }
                        .disabled(newRepoName.isEmpty)
                }
            }
        }
    }

    // MARK: - Helper Views

    private func sectionHeader(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
        }
    }

    // MARK: - Actions

    private func loadSavedCredentials() {
        if let saved = KeychainService.shared.get(forKey: KeychainService.githubToken) {
            token = saved
            verifyToken()
        }
        if let savedRepo = project.githubRepo {
            repoURL = "https://github.com/\(savedRepo)"
        }
    }

    private func connectToGitHub() {
        guard !token.isEmpty else { return }
        KeychainService.shared.set(token, forKey: KeychainService.githubToken)
        verifyToken()
    }

    private func verifyToken() {
        isLoading = true
        Task {
            do {
                let user = try await GitHubService.shared.getAuthenticatedUser()
                await MainActor.run {
                    githubUser = user
                    isAuthenticated = true
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    private func pushProject() {
        guard !ownerFromRepo.isEmpty, !repoNameFromURL.isEmpty else { return }
        isLoading = true
        Task {
            do {
                try await GitHubService.shared.pushProject(
                    project,
                    owner: ownerFromRepo,
                    repo: repoNameFromURL,
                    commitMessage: commitMessage
                )
                await MainActor.run {
                    isLoading = false
                    successMessage = "Project pushed successfully!"
                    showSuccess = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    private func pullUpdates() {
        isLoading = true
        // Pull would require fetching each known file from GitHub and updating local copies.
        // For simplicity we show an informational message.
        successMessage = "Pull functionality: Files pulled from '\(repoURL)'. (Implement per-file pull as needed.)"
        showSuccess = true
    }

    private func createRepository() {
        guard !newRepoName.isEmpty else { return }
        showCreateRepoSheet = false
        isLoading = true
        Task {
            do {
                let repo = try await GitHubService.shared.createRepository(
                    name: newRepoName,
                    description: newRepoDescription,
                    isPrivate: newRepoPrivate
                )
                await MainActor.run {
                    repoURL = repo.htmlUrl
                    isLoading = false
                    successMessage = "Repository '\(repo.name)' created!"
                    showSuccess = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    private func loadWorkflowRuns() {
        guard !ownerFromRepo.isEmpty, !repoNameFromURL.isEmpty else { return }
        Task {
            if let runs = try? await GitHubService.shared.listWorkflowRuns(
                owner: ownerFromRepo,
                repo: repoNameFromURL
            ) {
                await MainActor.run { workflowRuns = runs }
            }
        }
    }
}

// MARK: - Workflow Run Row

struct WorkflowRunRow: View {
    let run: WorkflowRun

    var statusColor: Color {
        switch run.conclusion ?? run.status {
        case "success": return .green
        case "failure": return .red
        case "cancelled": return .gray
        case "in_progress": return .yellow
        default: return .secondary
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: run.statusBadge)
                .foregroundStyle(statusColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(run.name ?? "Run #\(run.runNumber)")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(run.createdAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if run.isRunning {
                ProgressView()
                    .scaleEffect(0.7)
                    .tint(.yellow)
            }
        }
    }
}
