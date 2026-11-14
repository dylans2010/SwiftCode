import SwiftUI
import SwiftCodeGitHub
import YcodeIDECore
import YcodeAssistant

@MainActor
struct GitHubIntegrationView: View {
    let project: Project
    @State private var sessionStore = ProjectSessionStore.shared
    @Environment(\.dismiss) private var dismiss
    @AppStorage("github_repo_url") private var sharedRepoURL: String = ""

    @State private var token: String = ""
    @State private var isTokenVisible = false
    @State private var isCopied = false
    @State private var localIdentityStatus: String? = nil
    @State private var repoURL: String = ""
    @State private var commitMessage: String = "Update From SwiftCode"
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
    @State private var createdRepoURL: String?
    @State private var workflowRuns: [SwiftCodeGitHub.GitHubWorkflowRun] = []
    @State private var branches: [GitHubBranch] = []
    @State private var currentBranch = "main"
    @State private var isDownloadingRepo = false
    @State private var showGitCommands = false
    @State private var repoDetail: GitHubRepository?
    @State private var isValidatingRepo = false
    @State private var repoValidationError: String?

    @State private var showRepoPicker = false
    @State private var isFetchingRepos = false
    @State private var userRepos: [GitHubRepository] = []
    @State private var repoFetchError: String?
    @State private var repoSearchQuery = ""

    @State private var showBranchManagement = false
    @State private var showPullRequest = false
    @State private var showLicenses = false

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
        VStack(spacing: 0) {
            HStack {
                Label("GitHub Integration", systemImage: "folder.fill.badge.gearshape")
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.bordered)
            }
            .padding(.bottom, 16)

            ScrollView {
                VStack(spacing: 20) {
                    GroupBox {
                        authSection
                    }
                    .groupBoxStyle(ModernGroupBoxStyle())

                    if isAuthenticated {
                        GroupBox {
                            repositorySection
                        }
                        .groupBoxStyle(ModernGroupBoxStyle())

                        if !ownerFromRepo.isEmpty && !repoNameFromURL.isEmpty {
                            GroupBox {
                                githubModulesSection
                            }
                            .groupBoxStyle(ModernGroupBoxStyle())

                            GroupBox {
                                branchesSection
                            }
                            .groupBoxStyle(ModernGroupBoxStyle())

                            GroupBox {
                                pushSection
                            }
                            .groupBoxStyle(ModernGroupBoxStyle())

                            GroupBox {
                                advancedActionsSection
                            }
                            .groupBoxStyle(ModernGroupBoxStyle())

                            GroupBox {
                                workflowSection
                            }
                            .groupBoxStyle(ModernGroupBoxStyle())
                        }
                    }
                }
            }
        }
        .sourceControlEmbedded()
        .alert("Error", isPresented: $showError, presenting: errorMessage) { _ in
            Button("OK") {}
        } message: { msg in Text(msg) }
        .alert("Success", isPresented: $showSuccess, presenting: successMessage) { _ in
            Button("OK") {}
        } message: { msg in Text(msg) }
        .sheet(isPresented: $showCreateRepoSheet) { createRepoSheet }
        .sheet(isPresented: $showRepoPicker) { repoPickerSheet }
        .sheet(isPresented: $showGitCommands) {
            if let repository = GitRepository(containing: project.directoryURL) {
                GitCommandView(
                    repository: repository,
                    client: GitHubTokenProvider.client(),
                    remote: (ownerFromRepo, repoNameFromURL)
                )
            } else {
                Text("No local git repository was found in this project.")
                    .padding()
            }
        }
        .sheet(isPresented: $showBranchManagement) {
            BranchManagementView(
                owner: ownerFromRepo,
                repo: repoNameFromURL,
                currentBranch: $currentBranch
            )
        }
        .sheet(isPresented: $showPullRequest) {
            PullRequestView(
                owner: ownerFromRepo,
                repo: repoNameFromURL,
                currentBranch: currentBranch
            )
        }
        .sheet(isPresented: $showLicenses) {
            LicencesAddView(project: project)
        }
        .onAppear { loadSavedCredentials() }
    }

    private var authSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Authentication Status", systemImage: "key.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                Spacer()
            }

            if let user = githubUser {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.15))
                            .frame(width: 48, height: 48)
                        Image(systemName: "person.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.accentColor)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(user.name ?? user.login)
                            .font(.headline)
                        Text("@\(user.login)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        KeychainService.shared.delete(forKey: KeychainService.githubToken)
                        isAuthenticated = false
                        githubUser = nil
                        token = ""
                    } label: {
                        Text("Sign Out")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.secondary.opacity(0.1), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Personal Access Token")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        if AppSettings.shared.useLocalGitIdentity {
                            Text("Local Identity Active")
                                .font(.caption.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.15))
                                .foregroundStyle(Color.accentColor)
                                .clipShape(Capsule())
                        }
                    }

                    HStack(spacing: 8) {
                        if isTokenVisible {
                            TextField("ghp_xxxxxxxxxxxx", text: $token)
                                .font(.system(.body, design: .monospaced))
                                .textFieldStyle(.roundedBorder)
                                .autocorrectionDisabled()
                        } else {
                            SecureField("ghp_xxxxxxxxxxxx", text: $token)
                                .font(.system(.body, design: .monospaced))
                                .textFieldStyle(.roundedBorder)
                                .autocorrectionDisabled()
                        }

                        if !token.isEmpty {
                            Button {
                                isTokenVisible.toggle()
                            } label: {
                                Label(isTokenVisible ? "Hide" : "View", systemImage: isTokenVisible ? "eye.slash" : "eye")
                            }
                            .buttonStyle(.bordered)
                            .help(isTokenVisible ? "Mask token" : "View token in cleartext")

                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(token, forType: .string)
                                isCopied = true
                                Task {
                                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                                    isCopied = false
                                }
                            } label: {
                                Label(isCopied ? "Copied!" : "Copy", systemImage: isCopied ? "checkmark" : "doc.on.doc")
                                    .foregroundStyle(isCopied ? Color.accentColor : .primary)
                            }
                            .buttonStyle(.bordered)
                            .help("Copy token to clipboard")
                        }
                    }

                    HStack(spacing: 12) {
                        Button {
                            connectToGitHub()
                        } label: {
                            Label("Connect To GitHub", systemImage: "link")
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.accentSwiftUIColor)
                        .controlSize(.large)
                        .disabled(token.isEmpty || isLoading)

                        Button {
                            Task {
                                let identity = await GitHubTokenProvider.applyLocalIdentity()
                                localIdentityStatus = "Using local Git identity: \(identity.name) <\(identity.email)>"
                            }
                        } label: {
                            Label("Use Local Identity", systemImage: "person.crop.circle.badge.checkmark")
                                .font(.subheadline.bold())
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .help("Retrieves local git configuration and uses that identity rather than requiring a Personal Access Token")
                    }

                    if let status = localIdentityStatus {
                        Text(status)
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
        }
    }

    private var githubModulesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("GitHub Modules & Workflows", systemImage: "square.grid.2x2.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.accentColor)
                Spacer()
            }

            VStack(spacing: 0) {
                moduleRow(
                    title: "Branch Management",
                    subtitle: "Switch, create, or delete branches",
                    icon: "arrow.triangle.branch",
                    color: Color.accentColor
                ) {
                    showBranchManagement = true
                }

                Divider().opacity(0.15)

                moduleRow(
                    title: "Pull Requests",
                    subtitle: "Create PRs with reviewers and labels",
                    icon: "arrow.triangle.pull",
                    color: Color.accentColor
                ) {
                    showPullRequest = true
                }

                Divider().opacity(0.15)

                moduleRow(
                    title: "Licenses",
                    subtitle: "Browse, filter, and add OSS licenses",
                    icon: "doc.text.magnifyingglass",
                    color: Color.accentColor
                ) {
                    showLicenses = true
                }
            }
        }
    }

    private func moduleRow(title: String, subtitle: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    private var repositorySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Repository Setup", systemImage: "folder.fill.badge.gearshape")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.accentColor)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Repository URL")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    TextField("GitHub URL", text: $repoURL)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: repoURL) {
                            saveRepoURL()
                            repoDetail = nil
                            repoValidationError = nil
                            if !ownerFromRepo.isEmpty && !repoNameFromURL.isEmpty {
                                loadBranches()
                            }
                        }

                    Button {
                        fetchUserRepos()
                    } label: {
                        if isFetchingRepos {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isFetchingRepos)

                    Button {
                        validateRepoURL()
                    } label: {
                        if isValidatingRepo {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(ownerFromRepo.isEmpty || repoNameFromURL.isEmpty || isValidatingRepo)
                }

                if let error = repoValidationError {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let detail = repoDetail {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: detail.isPrivate ? "lock.fill" : "globe")
                                .foregroundStyle(detail.isPrivate ? Color.accentColor : .secondary)
                                .font(.caption)
                            Text(detail.fullName)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }

                        if let desc = detail.description, !desc.isEmpty {
                            Text(desc)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 16) {
                            Label("\(detail.stargazersCount)", systemImage: "star.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Label("\(detail.forksCount)", systemImage: "tuningfork")
                                .font(.caption)
                                .foregroundStyle(Color.accentColor)
                            Label("\(detail.openIssuesCount ?? 0)", systemImage: "exclamationmark.circle")
                                .font(.caption)
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .padding(10)
                    .liquidGlass(style: .subtle, cornerRadius: 10)
                }

                if let repositoryURL = URL(string: repoURL), !ownerFromRepo.isEmpty, !repoNameFromURL.isEmpty {
                    Link(destination: repositoryURL) {
                        Label("Open Repository On GitHub", systemImage: "arrow.up.right.square")
                            .font(.subheadline)
                            .foregroundStyle(Color.accentColor)
                    }
                }

                Button {
                    showCreateRepoSheet = true
                } label: {
                    Label("Create New Repository", systemImage: "plus.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .opacity(ownerFromRepo.isEmpty ? 1 : 0)
                .disabled(!ownerFromRepo.isEmpty)

                Button {
                    saveRepoToDevice()
                } label: {
                    if isDownloadingRepo {
                        HStack {
                            ProgressView().scaleEffect(0.8)
                            Text("Downloading…")
                                .font(.subheadline)
                        }
                        .foregroundStyle(Color.accentColor)
                    } else {
                        Label("Save Repository To Device", systemImage: "arrow.down.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isDownloadingRepo || ownerFromRepo.isEmpty || repoNameFromURL.isEmpty)
            }
        }
    }

    private var branchesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Repository Branches", systemImage: "arrow.branch")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    loadBranches()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.secondary)
                    Text("Active Branch: ")
                        .foregroundStyle(.secondary)
                    Text(currentBranch)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }

                if branches.isEmpty {
                    Text("No Branches Loaded")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(branches.prefix(8), id: \.name) { branch in
                        BranchRow(branch: branch, isActive: branch.name == currentBranch) {
                            currentBranch = branch.name
                            successMessage = "Active branch set to '\(branch.name)'."
                            showSuccess = true
                        }
                    }
                }
            }
        }
    }

    private var pushSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Push & Synchronize", systemImage: "arrow.triangle.2.circlepath")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.accentColor)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Commit Message")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField("Update From SwiftCode", text: $commitMessage)
                    .textFieldStyle(.roundedBorder)

                HStack(spacing: 12) {
                    Button {
                        pushProject()
                    } label: {
                        Label("Push Project", systemImage: "arrow.up.circle.fill")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.accentColor)
                    .controlSize(.large)
                    .disabled(isLoading)

                }
            }
        }
    }

    private var advancedActionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Developer Tools & Utilities", systemImage: "wrench.and.screwdriver.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.accentColor)
                Spacer()
            }

            HStack(spacing: 12) {
                Button {
                    showGitCommands = true
                } label: {
                    toolButtonContent(
                        icon: "square.grid.2x2.fill",
                        title: "Git Commands",
                        subtitle: "Run git ops with guided buttons",
                        color: Color.accentColor
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func toolButtonContent(icon: String, title: String, subtitle: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(title)
                .font(.caption.weight(.semibold))
            Text(subtitle)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .liquidGlass(style: .subtle, cornerRadius: 12)
    }

    private var workflowSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Build Actions", systemImage: "hammer.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.accentColor)
                Spacer()
                Button {
                    loadWorkflowRuns()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 12) {
                if workflowRuns.isEmpty {
                    Text("No Workflow Runs Found")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                } else {
                    ForEach(workflowRuns.prefix(5)) { run in
                        WorkflowRunRow(run: run)
                    }
                }
            }
        }
    }

    private var createRepoSheet: some View {
        Form {
            Section("Repository Details") {
                TextField("Repository Name", text: $newRepoName)
                    .autocorrectionDisabled()
                TextField("Description (Optional)", text: $newRepoDescription)
                Toggle("Private", isOn: $newRepoPrivate)
            }

            Button {
                createRepository()
            } label: {
                Label("Create Repository", systemImage: "plus.circle.fill")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.accentColor)
            .disabled(newRepoName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)

            if let url = createdRepoURL {
                Section("Repository Created") {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Your New Repository Is Ready!", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                        Text(url)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(Color.accentColor)
                            .textSelection(.enabled)
                        if let repoURL = URL(string: url) {
                            Link(destination: repoURL) {
                                Label("Open In Browser", systemImage: "safari")
                                    .font(.caption)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(24)
        .frame(width: 450)
    }

    private var filteredRepos: [GitHubRepository] {
        if repoSearchQuery.isEmpty { return userRepos }
        return userRepos.filter {
            $0.fullName.localizedCaseInsensitiveContains(repoSearchQuery) ||
            ($0.description ?? "").localizedCaseInsensitiveContains(repoSearchQuery)
        }
    }

    private var repoPickerSheet: some View {
        VStack(spacing: 12) {
            HStack {
                TextField("Search Repositories", text: $repoSearchQuery)
                    .textFieldStyle(.roundedBorder)
                Button {
                    fetchUserRepos()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isFetchingRepos)
            }

            ScrollView {
                VStack(spacing: 8) {
                    if isFetchingRepos {
                        ProgressView("Loading Repositories…")
                    } else if let fetchError = repoFetchError {
                        ContentUnavailableView(
                            "Could Not Load Repositories",
                            systemImage: "exclamationmark.triangle.fill",
                            description: Text(fetchError)
                        )
                    } else if userRepos.isEmpty {
                        ContentUnavailableView(
                            "No Repositories Found",
                            systemImage: "folder.badge.questionmark",
                            description: Text("No repositories are accessible with your current token.")
                        )
                    } else {
                        ForEach(filteredRepos) { repo in
                            Button {
                                repoURL = repo.htmlUrl
                                showRepoPicker = false
                                repoSearchQuery = ""
                                repoDetail = nil
                                repoValidationError = nil
                                saveRepoURL()
                                if !ownerFromRepo.isEmpty && !repoNameFromURL.isEmpty {
                                    loadBranches()
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: repo.isPrivate ? "lock.fill" : "globe")
                                        .foregroundStyle(repo.isPrivate ? Color.accentColor : .secondary)
                                        .frame(width: 20)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(repo.fullName)
                                            .font(.subheadline.weight(.semibold))
                                        if let desc = repo.description, !desc.isEmpty {
                                            Text(desc)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(8)
                                .background(Color.secondary.opacity(0.04))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(24)
        .frame(width: 400, height: 450)
    }

    private func loadSavedCredentials() {
        if let saved = KeychainService.shared.get(forKey: KeychainService.githubToken) {
            token = saved
            verifyToken()
        }
        if let savedRepo = project.githubRepo {
            if savedRepo.lowercased().hasPrefix("http") {
                repoURL = savedRepo
            } else {
                repoURL = "https://github.com/\(savedRepo)"
            }
        } else if !sharedRepoURL.isEmpty {
            repoURL = sharedRepoURL
        }
    }

    private func saveRepoURL() {
        guard !ownerFromRepo.isEmpty, !repoNameFromURL.isEmpty else { return }
        ProjectSessionStore.shared.updateProjectSettings(
            description: project.description,
            githubRepo: "\(ownerFromRepo)/\(repoNameFromURL)",
            for: project
        )
        sharedRepoURL = "https://github.com/\(ownerFromRepo)/\(repoNameFromURL)"
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
                let user = try await GitHubTokenProvider.service().getAuthenticatedUser()
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

    private func loadBranches() {
        guard !ownerFromRepo.isEmpty, !repoNameFromURL.isEmpty else { return }
        Task {
            if let fetched = try? await GitHubTokenProvider.service().listBranches(
                owner: ownerFromRepo,
                repo: repoNameFromURL
            ) {
                await MainActor.run { branches = fetched }
            }
        }
    }

    
    private func collectProjectFiles() -> [(path: String, data: Data)] {
        let fm = FileManager.default
        let root = project.directoryURL
        guard let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey]) else { return [] }
        var files: [(path: String, data: Data)] = []
        for case let url as URL in enumerator {
            let rel = url.path.replacingOccurrences(of: root.path + "/", with: "")
            guard !rel.hasPrefix(".git/"), rel != ".git" else { continue }
            guard (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { continue }
            guard let data = try? Data(contentsOf: url) else { continue }
            files.append((path: rel, data: data))
        }
        return files
    }

    private func pushProject() {
        guard !ownerFromRepo.isEmpty, !repoNameFromURL.isEmpty else { return }
        isLoading = true
        Task {
            do {
                let files = collectProjectFiles()
                try await GitHubTokenProvider.service().pushProject(
                    owner: ownerFromRepo,
                    repo: repoNameFromURL,
                    branch: currentBranch,
                    commitMessage: commitMessage,
                    files: files
                )
                await MainActor.run {
                    isLoading = false
                    successMessage = "Project Pushed Successfully!"
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

    private func createRepository() {
        guard !newRepoName.isEmpty else { return }
        isLoading = true
        Task {
            do {
                let repo = try await GitHubTokenProvider.service().createRepository(
                    name: newRepoName,
                    description: newRepoDescription,
                    isPrivate: newRepoPrivate
                )
                await MainActor.run {
                    repoURL = repo.htmlUrl
                    createdRepoURL = repo.htmlUrl
                    isLoading = false
                    saveRepoURL()
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

    private func fetchUserRepos() {
        isFetchingRepos = true
        repoFetchError = nil
        Task {
            do {
                let repos = try await GitHubTokenProvider.service().listUserRepositories()
                await MainActor.run {
                    userRepos = repos
                    isFetchingRepos = false
                    showRepoPicker = true
                }
            } catch {
                await MainActor.run {
                    isFetchingRepos = false
                    repoFetchError = error.localizedDescription
                    showRepoPicker = true
                }
            }
        }
    }

    private func saveRepoToDevice() {
        guard !ownerFromRepo.isEmpty, !repoNameFromURL.isEmpty else { return }
        isDownloadingRepo = true
        Task {
            do {
                let zipURL = try await GitHubTokenProvider.service().downloadRepositoryZip(
                    owner: ownerFromRepo,
                    repo: repoNameFromURL,
                    branch: currentBranch
                )
                let importedProject = try await ProjectZipImporter.shared.importZip(at: zipURL)
                try? FileManager.default.removeItem(at: zipURL)
                await MainActor.run {
                    isDownloadingRepo = false
                    successMessage = "Repository saved as project '\(importedProject.name)' on your device."
                    showSuccess = true
                }
            } catch {
                await MainActor.run {
                    isDownloadingRepo = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    private func loadWorkflowRuns() {
        guard !ownerFromRepo.isEmpty, !repoNameFromURL.isEmpty else { return }
        Task {
            if let runs = try? await GitHubTokenProvider.service().listWorkflowRuns(
                owner: ownerFromRepo,
                repo: repoNameFromURL
            ) {
                await MainActor.run { workflowRuns = runs }
            }
        }
    }

    private func validateRepoURL() {
        guard !ownerFromRepo.isEmpty, !repoNameFromURL.isEmpty else { return }
        isValidatingRepo = true
        repoValidationError = nil
        repoDetail = nil
        Task {
            do {
                let detail = try await GitHubTokenProvider.service().validateAndFetchRepo(
                    owner: ownerFromRepo,
                    repo: repoNameFromURL
                )
                await MainActor.run {
                    repoDetail = detail
                    isValidatingRepo = false
                    currentBranch = detail.defaultBranch ?? "main"
                }
            } catch let error as GitHubError {
                await MainActor.run {
                    isValidatingRepo = false
                    switch error {
                    case .notFound:
                        repoValidationError = "Repository not found. Check the URL and ensure you have access."
                    case .forbidden:
                        repoValidationError = "Access denied. The repository may be private."
                    case .missingToken:
                        repoValidationError = "No GitHub token set."
                    default:
                        repoValidationError = error.localizedDescription
                    }
                }
            } catch {
                await MainActor.run {
                    isValidatingRepo = false
                    repoValidationError = error.localizedDescription
                }
            }
        }
    }
}

struct BranchRow: View {
    let branch: GitHubBranch
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "arrow.branch")
                    .foregroundStyle(isActive ? Color.accentColor : .secondary)
                Text(branch.name)
                    .foregroundStyle(isActive ? Color.accentColor : .primary)
                    .font(.subheadline)
                Spacer()
                if isActive {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(8)
            .background(isActive ? Color.secondary.opacity(0.1) : Color.secondary.opacity(0.04))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

struct WorkflowRunRow: View {
    let run: SwiftCodeGitHub.GitHubWorkflowRun

    var statusColor: Color {
        switch run.conclusion ?? run.status {
        case "success": return Color.accentColor
        case "failure": return .secondary
        case "cancelled": return .gray
        case "in_progress": return Color.accentColor
        default: return .secondary
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: run.statusBadge)
                .font(.title3)
                .foregroundStyle(statusColor)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(run.name ?? "Workflow Run")
                        .font(.subheadline.bold())
                    Text("#\(run.runNumber)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    if let branch = run.headBranch {
                        Label(branch, systemImage: "arrow.branch")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(run.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let url = URL(string: run.htmlUrl) {
                Link(destination: url) {
                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.04))
        .cornerRadius(8)
    }
}
