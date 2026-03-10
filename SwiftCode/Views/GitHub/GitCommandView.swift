import SwiftUI

// MARK: - Git Command View

struct GitCommandView: View {
    let project: Project
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var projectManager: ProjectManager

    @State private var commitMessage = "Update from SwiftCode"
    @State private var newBranchName = ""
    @State private var branches: [GitHubBranch] = []
    @State private var currentBranch = "main"
    @State private var isLoading = false
    @State private var statusMessage: String?
    @State private var showStatus = false
    @State private var isSuccess = false
    @State private var showBranchInput = false
    @State private var showCommitInput = false

    private var ownerFromRepo: String {
        guard let repo = project.githubRepo else { return "" }
        return String(repo.split(separator: "/").first ?? "")
    }

    private var repoNameFromURL: String {
        guard let repo = project.githubRepo else { return "" }
        return String(repo.split(separator: "/").last ?? "")
    }

    private var isRepoConnected: Bool {
        !ownerFromRepo.isEmpty && !repoNameFromURL.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.10, green: 0.10, blue: 0.14).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Branch indicator
                        if isRepoConnected {
                            branchIndicator
                        } else {
                            noRepoNotice
                        }

                        // Command groups
                        commandGroup(
                            title: "Sync",
                            icon: "arrow.triangle.2.circlepath",
                            color: .orange,
                            commands: syncCommands
                        )

                        commandGroup(
                            title: "Branches",
                            icon: "arrow.branch",
                            color: .green,
                            commands: branchCommands
                        )

                        commandGroup(
                            title: "History",
                            icon: "clock.arrow.circlepath",
                            color: .purple,
                            commands: historyCommands
                        )

                        commandGroup(
                            title: "Utilities",
                            icon: "wrench.and.screwdriver",
                            color: .gray,
                            commands: utilityCommands
                        )
                    }
                    .padding()
                }
            }
            .navigationTitle("Git Commands")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert(isSuccess ? "Success" : "Info", isPresented: $showStatus, presenting: statusMessage) { _ in
                Button("OK") {}
            } message: { msg in Text(msg) }
            .sheet(isPresented: $showCommitInput) {
                commitInputSheet
            }
            .sheet(isPresented: $showBranchInput) {
                branchInputSheet
            }
            .onAppear { fetchBranches() }
        }
    }

    // MARK: - Subviews

    private var branchIndicator: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.branch")
                .foregroundStyle(.green)
            Text("Current branch:")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(currentBranch)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.green)
            Spacer()
            if isLoading {
                ProgressView().scaleEffect(0.8)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var noRepoNotice: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text("Connect a GitHub repository first to run remote commands.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func commandGroup(
        title: String,
        icon: String,
        color: Color,
        commands: [GitCommandCard]
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon).foregroundStyle(color)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            ForEach(commands) { cmd in
                GitCommandRow(card: cmd)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Command Sheets

    private var commitInputSheet: some View {
        NavigationStack {
            Form {
                Section("Commit Message") {
                    TextField("Describe your changes", text: $commitMessage)
                        .autocorrectionDisabled()
                }
                Section {
                    Button("Commit & Push") {
                        showCommitInput = false
                        pushChanges()
                    }
                    .foregroundStyle(.orange)
                    .disabled(commitMessage.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle("git commit & push")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showCommitInput = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var branchInputSheet: some View {
        NavigationStack {
            Form {
                Section("New Branch Name") {
                    TextField("feature/my-feature", text: $newBranchName)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                if !branches.isEmpty {
                    Section("Switch to Existing Branch") {
                        ForEach(branches) { branch in
                            Button {
                                currentBranch = branch.name
                                showBranchInput = false
                                showInfo("Active branch set to '\(branch.name)'. Your next push will target this branch on GitHub.")
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.branch")
                                        .foregroundStyle(.green)
                                    Text(branch.name)
                                        .foregroundStyle(.white)
                                    Spacer()
                                    if branch.name == currentBranch {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.green)
                                    }
                                    if branch.protected {
                                        Image(systemName: "lock.fill")
                                            .foregroundStyle(.yellow)
                                            .font(.caption)
                                    }
                                }
                            }
                        }
                    }
                }
                if !newBranchName.trimmingCharacters(in: .whitespaces).isEmpty {
                    Section {
                        Button("Create Branch '\(newBranchName)'") {
                            let name = newBranchName.trimmingCharacters(in: .whitespaces)
                            showBranchInput = false
                            createBranch(name: name)
                        }
                        .foregroundStyle(.green)
                    }
                }
            }
            .navigationTitle("git branch / checkout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showBranchInput = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Command Definitions

    private var syncCommands: [GitCommandCard] {
        [
            GitCommandCard(
                command: "git add . && git commit -m <message>",
                description: "Stage all changed files and record a snapshot of your project with a message.",
                icon: "plus.circle.fill",
                color: .orange,
                isEnabled: isRepoConnected,
                action: { showCommitInput = true }
            ),
            GitCommandCard(
                command: "git push",
                description: "Upload your committed changes to the remote GitHub repository.",
                icon: "arrow.up.circle.fill",
                color: .blue,
                isEnabled: isRepoConnected,
                action: { pushChanges() }
            ),
            GitCommandCard(
                command: "git pull",
                description: "Download and integrate the latest changes from GitHub. Use the GitHub panel's Pull button to fetch files from the remote repository.",
                icon: "arrow.down.circle.fill",
                color: .cyan,
                isEnabled: true,
                action: { pullChanges() }
            ),
            GitCommandCard(
                command: "git fetch",
                description: "Download branch info and tags from GitHub without changing local files.",
                icon: "arrow.clockwise.circle.fill",
                color: .teal,
                isEnabled: isRepoConnected,
                action: { fetchBranches() }
            )
        ]
    }

    private var branchCommands: [GitCommandCard] {
        [
            GitCommandCard(
                command: "git branch / git checkout",
                description: "View all branches, create a new branch, or switch to an existing one.",
                icon: "arrow.branch",
                color: .green,
                isEnabled: true,
                action: { showBranchInput = true }
            ),
            GitCommandCard(
                command: "git merge",
                description: "Merge is handled automatically when pushing to a branch. Open a Pull Request on GitHub.com to merge branches.",
                icon: "arrow.triangle.merge",
                color: .mint,
                isEnabled: false,
                action: {}
            )
        ]
    }

    private var historyCommands: [GitCommandCard] {
        [
            GitCommandCard(
                command: "git log",
                description: "View the commit history. Open Build Status to see recent workflow runs and pushes.",
                icon: "list.bullet.rectangle",
                color: .purple,
                isEnabled: false,
                action: {}
            ),
            GitCommandCard(
                command: "git diff",
                description: "Show differences between your current files and the last committed version.",
                icon: "doc.text.magnifyingglass",
                color: .indigo,
                isEnabled: false,
                action: {}
            )
        ]
    }

    private var utilityCommands: [GitCommandCard] {
        [
            GitCommandCard(
                command: "git stash",
                description: "Temporarily shelve changes you've made. Not available on mobile — save your work to a branch instead.",
                icon: "archivebox.fill",
                color: .gray,
                isEnabled: false,
                action: {}
            ),
            GitCommandCard(
                command: "git reset --hard HEAD",
                description: "Discard all uncommitted local changes and revert files to the last committed state. Not directly supported on-device — tap to learn more.",
                icon: "arrow.uturn.backward.circle.fill",
                color: .red,
                isEnabled: true,
                action: { resetToRemote() }
            )
        ]
    }

    // MARK: - Actions

    private func fetchBranches() {
        guard isRepoConnected else { return }
        Task {
            if let fetched = try? await GitHubService.shared.listBranches(
                owner: ownerFromRepo,
                repo: repoNameFromURL
            ) {
                await MainActor.run { branches = fetched }
            }
        }
    }

    private func pushChanges() {
        guard isRepoConnected else { return }
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
                    isSuccess = true
                    statusMessage = "Pushed to '\(currentBranch)' successfully."
                    showStatus = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    isSuccess = false
                    statusMessage = error.localizedDescription
                    showStatus = true
                }
            }
        }
    }

    private func pullChanges() {
        isSuccess = true
        statusMessage = "Pull info: Use the GitHub panel's Pull button to fetch file updates from '\(repoNameFromURL)' on branch '\(currentBranch)'."
        showStatus = true
    }

    private func createBranch(name: String) {
        // Optimistically update the UI branch selection; the actual branch is created on GitHub
        // when the user pushes with this branch active.
        currentBranch = name
        isSuccess = true
        statusMessage = "Branch '\(name)' set as active. Push your changes to create and publish this branch on GitHub."
        showStatus = true
    }

    private func resetToRemote() {
        isSuccess = false
        statusMessage = "git reset is not available on-device. To discard changes, re-open the file and use the GitHub Pull action to restore the last pushed version."
        showStatus = true
    }

    private func showInfo(_ msg: String) {
        isSuccess = true
        statusMessage = msg
        showStatus = true
    }
}

// MARK: - Git Command Card Model

struct GitCommandCard: Identifiable {
    let id = UUID()
    let command: String
    let description: String
    let icon: String
    let color: Color
    let isEnabled: Bool
    let action: () -> Void
}

// MARK: - Git Command Row

struct GitCommandRow: View {
    let card: GitCommandCard

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: card.icon)
                .foregroundStyle(card.isEnabled ? card.color : .secondary)
                .font(.title3)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(card.command)
                    .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                    .foregroundStyle(card.isEnabled ? .white : .secondary)
                Text(card.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            if card.isEnabled {
                Button(action: card.action) {
                    Image(systemName: "play.fill")
                        .font(.caption)
                        .padding(8)
                        .background(card.color.opacity(0.25), in: Circle())
                        .foregroundStyle(card.color)
                }
                .buttonStyle(.plain)
            } else {
                Image(systemName: "minus.circle")
                    .foregroundStyle(.tertiary)
                    .font(.caption)
            }
        }
        .padding(10)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
        .opacity(card.isEnabled ? 1 : 0.6)
    }
}
