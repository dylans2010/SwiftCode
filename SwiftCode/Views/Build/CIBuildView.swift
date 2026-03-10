import SwiftUI

// MARK: - CI Build View

struct CIBuildView: View {
    let project: Project
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var projectManager: ProjectManager

    @State private var schemeName: String = ""
    @State private var bundleID: String = "com.example.myapp"
    @State private var triggerBranch: String = "main"
    @State private var xcodeVersion: String = "latest-stable"
    @State private var includeTestFlight = false
    @State private var showYAMLPreview = false
    @State private var isSaving = false
    @State private var statusMessage: String?
    @State private var showStatus = false
    @State private var isSuccess = false
    @State private var showGitHubPush = false
    @State private var commitMessage = "Add CI workflow for IPA build"

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

    private var resolvedScheme: String {
        schemeName.trimmingCharacters(in: .whitespaces).isEmpty ? project.name : schemeName
    }

    var generatedYAML: String {
        """
        name: Build iOS IPA

        on:
          push:
            branches: [ \(triggerBranch) ]
          workflow_dispatch:

        jobs:
          build:
            runs-on: macos-14

            steps:
              - name: Checkout
                uses: actions/checkout@v4

              - name: Select Xcode
                uses: maxim-lobanov/setup-xcode@v1
                with:
                  xcode-version: '\(xcodeVersion)'

              - name: Build Archive
                run: |
                  xcodebuild archive \\
                    -scheme "\(resolvedScheme)" \\
                    -archivePath "${{ runner.temp }}/\(resolvedScheme).xcarchive" \\
                    -destination "generic/platform=iOS" \\
                    CODE_SIGNING_ALLOWED=NO

              - name: Export IPA
                run: |
                  xcodebuild -exportArchive \\
                    -archivePath "${{ runner.temp }}/\(resolvedScheme).xcarchive" \\
                    -exportPath "${{ runner.temp }}/ipa" \\
                    -exportOptionsPlist ExportOptions.plist \\
                    || true

              - name: Upload IPA Artifact
                uses: actions/upload-artifact@v4
                with:
                  name: \(resolvedScheme)-IPA
                  path: |
                    ${{ runner.temp }}/ipa/*.ipa
                    ${{ runner.temp }}/*.xcarchive
                  if-no-files-found: warn
                  retention-days: 30
        \(includeTestFlight ? testFlightStep : "")
        """
    }

    private var testFlightStep: String {
        """

              - name: Upload to TestFlight
                uses: apple-actions/upload-testflight-build@v1
                with:
                  app-path: ${{ runner.temp }}/ipa/*.ipa
                  issuer-id: ${{ secrets.APPSTORE_ISSUER_ID }}
                  api-key-id: ${{ secrets.APPSTORE_KEY_ID }}
                  api-private-key: ${{ secrets.APPSTORE_PRIVATE_KEY }}
        """
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.10, green: 0.10, blue: 0.14).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Header info
                        headerCard

                        // Configuration
                        configurationSection

                        // Options
                        optionsSection

                        // Actions
                        actionsSection

                        // Secrets note
                        secretsInfoCard
                    }
                    .padding()
                }
            }
            .navigationTitle("Build with CI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showYAMLPreview) {
                yamlPreviewSheet
            }
            .sheet(isPresented: $showGitHubPush) {
                pushWorkflowSheet
            }
            .alert(isSuccess ? "Success" : "Error", isPresented: $showStatus, presenting: statusMessage) { _ in
                Button("OK") {}
            } message: { msg in Text(msg) }
            .onAppear {
                schemeName = project.name
            }
        }
    }

    // MARK: - Subviews

    private var headerCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 50, height: 50)
                Image(systemName: "cpu.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Automated IPA Builder")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Generates a GitHub Actions workflow that compiles your app and produces a downloadable .ipa artifact on every push.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var configurationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Configuration", icon: "gearshape.fill", color: .blue)

            VStack(spacing: 10) {
                labeledField("Xcode Scheme", placeholder: project.name, text: $schemeName)
                labeledField("Bundle ID", placeholder: "com.company.app", text: $bundleID)
                labeledField("Trigger Branch", placeholder: "main", text: $triggerBranch)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Xcode Version")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("Xcode Version", selection: $xcodeVersion) {
                        Text("Latest Stable").tag("latest-stable")
                        Text("Xcode 16").tag("16")
                        Text("Xcode 15.4").tag("15.4")
                        Text("Xcode 15.2").tag("15.2")
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Options", icon: "slider.horizontal.3", color: .purple)

            Toggle(isOn: $includeTestFlight) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Upload to TestFlight")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                    Text("Requires App Store Connect API secrets in GitHub")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(.purple)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var actionsSection: some View {
        VStack(spacing: 10) {
            // Preview YAML
            Button {
                showYAMLPreview = true
            } label: {
                Label("Preview Workflow YAML", systemImage: "eye.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

            // Save to project
            Button {
                saveWorkflowToProject()
            } label: {
                Label(
                    isSaving ? "Saving…" : "Save Workflow to Project",
                    systemImage: "square.and.arrow.down.fill"
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(.blue.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(isSaving)

            // Push to GitHub
            Button {
                showGitHubPush = true
            } label: {
                Label("Push Workflow to GitHub", systemImage: "arrow.up.circle.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.orange.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(!isRepoConnected)
            .opacity(isRepoConnected ? 1 : 0.5)
        }
    }

    private var secretsInfoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Required GitHub Secrets", icon: "lock.fill", color: .yellow)

            VStack(alignment: .leading, spacing: 6) {
                secretRow("CERTIFICATES_P12", "Base64-encoded signing certificate")
                secretRow("CERTIFICATES_P12_PASSWORD", "Certificate password")
                secretRow("APPSTORE_ISSUER_ID", "App Store Connect issuer ID")
                secretRow("APPSTORE_KEY_ID", "App Store Connect key ID")
                secretRow("APPSTORE_PRIVATE_KEY", "App Store Connect private key (.p8)")
            }

            Text("Add these secrets in your GitHub repository under Settings → Secrets and variables → Actions.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - YAML Preview Sheet

    private var yamlPreviewSheet: some View {
        NavigationStack {
            ScrollView {
                Text(generatedYAML)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color(red: 0.85, green: 0.85, blue: 0.85))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(red: 0.11, green: 0.11, blue: 0.14))
            .navigationTitle("build.yml")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { showYAMLPreview = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        UIPasteboard.general.string = generatedYAML
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Push Workflow Sheet

    private var pushWorkflowSheet: some View {
        NavigationStack {
            Form {
                Section("Commit Message") {
                    TextField("Add CI workflow", text: $commitMessage)
                        .autocorrectionDisabled()
                }
                Section {
                    Button("Push to GitHub") {
                        showGitHubPush = false
                        pushWorkflowToGitHub()
                    }
                    .foregroundStyle(.orange)
                    .disabled(commitMessage.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle("Push Workflow")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showGitHubPush = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Helper Views

    private func sectionLabel(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(color)
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
        }
    }

    private func labeledField(_ label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
    }

    private func secretRow(_ name: String, _ description: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "key.fill")
                .font(.caption2)
                .foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .fontDesign(.monospaced)
                Text(description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Actions

    private func saveWorkflowToProject() {
        isSaving = true
        Task {
            do {
                let workflowsPath = ".github/workflows"
                let projectDir = await project.directoryURL
                let workflowsDir = projectDir.appendingPathComponent(workflowsPath)
                try FileManager.default.createDirectory(
                    at: workflowsDir,
                    withIntermediateDirectories: true
                )
                let yamlURL = workflowsDir.appendingPathComponent("build.yml")
                try generatedYAML.write(to: yamlURL, atomically: true, encoding: .utf8)

                await MainActor.run {
                    projectManager.refreshFileTree(for: project)
                    isSaving = false
                    isSuccess = true
                    statusMessage = "Workflow saved to .github/workflows/build.yml in your project."
                    showStatus = true
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    isSuccess = false
                    statusMessage = error.localizedDescription
                    showStatus = true
                }
            }
        }
    }

    private func pushWorkflowToGitHub() {
        guard isRepoConnected else { return }
        Task {
            do {
                let filePath = ".github/workflows/build.yml"
                let existingSHA = try? await GitHubService.shared.getFileSHA(
                    owner: ownerFromRepo,
                    repo: repoNameFromURL,
                    path: filePath
                )
                try await GitHubService.shared.pushFile(
                    owner: ownerFromRepo,
                    repo: repoNameFromURL,
                    path: filePath,
                    content: generatedYAML,
                    message: commitMessage,
                    sha: existingSHA
                )
                await MainActor.run {
                    isSuccess = true
                    statusMessage = "Workflow pushed to GitHub! A new CI run will start on the next push to '\(triggerBranch)'."
                    showStatus = true
                }
            } catch {
                await MainActor.run {
                    isSuccess = false
                    statusMessage = error.localizedDescription
                    showStatus = true
                }
            }
        }
    }
}
