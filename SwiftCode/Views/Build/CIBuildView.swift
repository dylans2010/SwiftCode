import SwiftUI

// MARK: - CI Build View

struct CIBuildView: View {
    let project: Project
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var projectManager: ProjectManager

    @State private var schemeName: String = ""
    @State private var bundleID: String = "com.example.myapp"
    @State private var selectedPlatform: CIBuildConfiguration.Platform = .iOS
    @State private var deploymentTarget: String = "16.0"
    @State private var targetDeviceFamily: CIBuildConfiguration.DeviceFamily = .iPhoneAndIPad
    @State private var triggerBranch: String = "main"
    @State private var xcodeVersion: String = "latest-stable"
    @State private var includeTestFlight = false
    @State private var includeTests = false
    @State private var includeLinting = false
    @State private var includeSwiftPM = false
    @State private var includePullRequestTrigger = false
    @State private var includeCodeCoverage = false
    @State private var iOSSimulator: String = "iPhone 15 Pro"
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

    private let deploymentTargets: [String] = {
        stride(from: 16.0, through: 18.0, by: 0.1).map { String(format: "%.1f", $0) }
    }()

    private var ciConfiguration: CIBuildConfiguration {
        CIBuildConfiguration(
            platform: selectedPlatform,
            deploymentTarget: deploymentTarget,
            targetDeviceFamily: targetDeviceFamily,
            schemeName: resolvedScheme,
            bundleIdentifier: bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private var ciConfigJSON: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(ciConfiguration),
              let json = String(data: data, encoding: .utf8)
        else { return "{}" }
        return json
    }

    private var ciConfigPath: String { ".swiftcode/ci-build-config.json" }

    private func validateConfiguration() -> String? {
        if resolvedScheme.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Scheme name is required."
        }

        if selectedPlatform.rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Please select a platform."
        }

        guard let value = Double(deploymentTarget), value >= 16.0 else {
            return "Deployment target must be 16.0 or later."
        }

        if targetDeviceFamily.rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Please select a target device family."
        }

        return nil
    }

    var generatedYAML: String {
        let templatePath = Bundle.main.path(forResource: "build", ofType: "yml")
        let fallbackPath = "SwiftCode/Backend/CI Building/build.yml"

        var template: String = ""
        if let path = templatePath, let content = try? String(contentsOfFile: path, encoding: .utf8) {
            template = content
        } else if let content = try? String(contentsOfFile: fallbackPath, encoding: .utf8) {
            template = content
        } else {
            return "Error: Could not load CI build template."
        }

        var yaml = template

        // Replace base placeholders
        yaml = yaml.replacingOccurrences(of: "{{SCHEME}}", with: resolvedScheme)
        yaml = yaml.replacingOccurrences(of: "{{XCODE_VERSION}}", with: xcodeVersion)
        yaml = yaml.replacingOccurrences(of: "{{PLATFORM}}", with: selectedPlatform.rawValue)
        yaml = yaml.replacingOccurrences(of: "{{DEPLOYMENT_TARGET}}", with: deploymentTarget)
        yaml = yaml.replacingOccurrences(of: "{{TARGETED_DEVICE_FAMILY}}", with: targetDeviceFamily.targetFamilyValue)

        // Handle Trigger placeholders
        let pushTrigger = """
          push:
            branches: [ \(triggerBranch) ]
        """
        yaml = yaml.replacingOccurrences(of: "{{ON_PUSH}}", with: pushTrigger)

        let prTrigger = includePullRequestTrigger ? """
          pull_request:
            branches: [ \(triggerBranch) ]
        """ : ""
        yaml = yaml.replacingOccurrences(of: "{{ON_PR}}", with: prTrigger)

        // Handle optional steps
        var stepsYaml = ""

        if includeSwiftPM {
            stepsYaml += """

      - name: Resolve Swift Packages
        run: |
          WORKSPACE=$(find . -name "*.xcworkspace" -not -path "*/DerivedData/*" | head -1)
          XCODEPROJ=$(find . -name "*.xcodeproj" -not -path "*/DerivedData/*" | head -1)
          if [ -n "$WORKSPACE" ]; then
            PROJECT_ARG="-workspace $WORKSPACE"
          elif [ -n "$XCODEPROJ" ]; then
            PROJECT_ARG="-project $XCODEPROJ"
          else
            echo "Error: No .xcworkspace or .xcodeproj found in repository." >&2
            exit 1
          fi
          xcodebuild $PROJECT_ARG \\
            -scheme "\(resolvedScheme)" \\
            -resolvePackageDependencies
"""
        }

        if includeLinting {
            stepsYaml += """

      - name: Install SwiftLint
        run: brew install swiftlint

      - name: Run SwiftLint
        run: swiftlint lint --reporter github-actions-logging || true
"""
        }

        if includeTests {
            var testRun = """

      - name: Run Tests
        run: |
          xcodebuild test \\
            -scheme "\(resolvedScheme)" \\
            -destination "platform=iOS Simulator,name=\(iOSSimulator)" \\
            -resultBundlePath TestResults.xcresult \\
"""
            if includeCodeCoverage {
                testRun += "            -enableCodeCoverage YES \\\n"
            }
            testRun += "            CODE_SIGNING_ALLOWED=NO || true\n"

            testRun += """

      - name: Upload Test Results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: test-results
          path: TestResults.xcresult
          if-no-files-found: warn
"""
            stepsYaml += testRun
        }

        yaml = yaml.replacingOccurrences(of: "{{STEPS}}", with: stepsYaml)

        if includeTestFlight {
            yaml += testFlightStep
        }

        return yaml
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
                Color(red: 0.05, green: 0.05, blue: 0.07).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header info
                        headerCard

                        GroupBox {
                            configurationSection
                        }
                        .groupBoxStyle(ModernGroupBoxStyle())

                        GroupBox {
                            optionsSection
                        }
                        .groupBoxStyle(ModernGroupBoxStyle())

                        actionsSection

                        GroupBox {
                            secretsInfoCard
                        }
                        .groupBoxStyle(ModernGroupBoxStyle())
                    }
                    .padding()
                }
            }
            .navigationTitle("Build With CI")
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
                let config = project.ciBuildConfiguration ?? CIBuildConfiguration()
                schemeName = config.schemeName
                bundleID = config.bundleIdentifier
                selectedPlatform = config.platform
                deploymentTarget = config.deploymentTarget
                targetDeviceFamily = config.targetDeviceFamily
            }
        }
    }

    // MARK: - Subviews

    private var headerCard: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 56, height: 56)
                Image(systemName: "cpu.fill")
                    .font(.title)
                    .foregroundStyle(.orange)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Automated IPA Builder")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                Text("Generates a GitHub Actions workflow that compiles your app and produces a downloadable .ipa file on every push.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var configurationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionLabel("CI Build Configuration", icon: "gearshape.fill", color: .blue)

            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Platform")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Picker("Platform", selection: $selectedPlatform) {
                        Text("iOS").tag(CIBuildConfiguration.Platform.iOS)
                        Text("iOS + iPadOS").tag(CIBuildConfiguration.Platform.iOSAndIPadOS)
                    }
                    .pickerStyle(.segmented)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Deployment Target")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Picker("Deployment Target", selection: $deploymentTarget) {
                        ForEach(deploymentTargets, id: \.self) { version in
                            Text(version).tag(version)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Target Device Family")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Picker("Target Device Family", selection: $targetDeviceFamily) {
                        Text("iPhone").tag(CIBuildConfiguration.DeviceFamily.iPhone)
                        Text("iPad").tag(CIBuildConfiguration.DeviceFamily.iPad)
                        Text("iPhone + iPad").tag(CIBuildConfiguration.DeviceFamily.iPhoneAndIPad)
                    }
                    .pickerStyle(.segmented)
                }

                labeledField("Scheme Name", placeholder: "Test", text: $schemeName)
                labeledField("Bundle Identifier", placeholder: "com.company.app", text: $bundleID)
                labeledField("Trigger Branch", placeholder: "main", text: $triggerBranch)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Xcode Version")
                        .font(.caption.weight(.semibold))
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
    }

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionLabel("Options", icon: "slider.horizontal.3", color: .purple)

            Toggle(isOn: $includeTests) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Run Unit Tests")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                    Text("Run xcodebuild test before archiving")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(.green)

            if includeTests {
                VStack(alignment: .leading, spacing: 8) {
                    Text("iOS Simulator")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Picker("Simulator", selection: $iOSSimulator) {
                        Text("iPhone 15 Pro").tag("iPhone 15 Pro")
                        Text("iPhone 15").tag("iPhone 15")
                        Text("iPhone 14").tag("iPhone 14")
                        Text("iPad Pro (12.9-inch)").tag("iPad Pro (12.9-inch) (6th generation)")
                    }
                    .pickerStyle(.segmented)
                }

                Toggle(isOn: $includeCodeCoverage) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Code Coverage")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)
                        Text("Enable code coverage collection during tests")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(.blue)
            }

            Toggle(isOn: $includeLinting) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SwiftLint")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                    Text("Install and run SwiftLint for code style checks")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(.orange)

            Toggle(isOn: $includeSwiftPM) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Resolve Swift Packages")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                    Text("Run xcodebuild -resolvePackageDependencies before building")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(.teal)

            Toggle(isOn: $includePullRequestTrigger) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pull Request Trigger")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                    Text("Also run CI on pull requests targeting the trigger branch")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(.blue)

            Toggle(isOn: $includeTestFlight) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Upload To TestFlight")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                    Text("Requires App Store Connect API secrets in GitHub")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(.purple)
        }
    }

    private var actionsSection: some View {
        VStack(spacing: 10) {
            // Preview YAML
            Button {
                if let validationError = validateConfiguration() {
                    isSuccess = false
                    statusMessage = validationError
                    showStatus = true
                    return
                }
                persistCIConfiguration()
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
                if let validationError = validateConfiguration() {
                    isSuccess = false
                    statusMessage = validationError
                    showStatus = true
                    return
                }
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
                if let validationError = validateConfiguration() {
                    isSuccess = false
                    statusMessage = validationError
                    showStatus = true
                    return
                }
                persistCIConfiguration()
                showGitHubPush = true
            } label: {
                Label("Push Workflow to GitHub", systemImage: "arrow.up.circle.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.orange.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
    }

    private var secretsInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Required GitHub Secrets", icon: "lock.fill", color: .yellow)

            VStack(alignment: .leading, spacing: 8) {
                secretRow("CERTIFICATES_P12", "Base64 encoded signing certificate")
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
                if !isRepoConnected {
                    Section {
                        Label("No repository connected to this project. Open GitHub settings for this project and connect a repository first.", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                    } header: {
                        Text("Repository Required")
                    }
                }
                Section("Commit Message") {
                    TextField("Add CI Workflow", text: $commitMessage)
                        .autocorrectionDisabled()
                }
                Section {
                    Button("Push To GitHub") {
                        showGitHubPush = false
                        pushWorkflowToGitHub()
                    }
                    .foregroundStyle(isRepoConnected ? .orange : .secondary)
                    .disabled(!isRepoConnected || commitMessage.trimmingCharacters(in: .whitespaces).isEmpty)
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

    private func persistCIConfiguration() {
        projectManager.updateCIBuildConfiguration(ciConfiguration, for: project)
    }

    private func saveWorkflowToProject() {
        isSaving = true
        Task {
            do {
                let workflowsPath = ".github/workflows"
                let projectDir = project.directoryURL
                let workflowsDir = projectDir.appendingPathComponent(workflowsPath)
                try FileManager.default.createDirectory(
                    at: workflowsDir,
                    withIntermediateDirectories: true
                )
                let yamlURL = workflowsDir.appendingPathComponent("build.yml")
                try generatedYAML.write(to: yamlURL, atomically: true, encoding: .utf8)

                let ciConfigDir = projectDir.appendingPathComponent(".swiftcode")
                try FileManager.default.createDirectory(at: ciConfigDir, withIntermediateDirectories: true)
                try ciConfigJSON.write(
                    to: projectDir.appendingPathComponent(ciConfigPath),
                    atomically: true,
                    encoding: .utf8
                )

                await MainActor.run {
                    persistCIConfiguration()
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

                let configSHA = try? await GitHubService.shared.getFileSHA(
                    owner: ownerFromRepo,
                    repo: repoNameFromURL,
                    path: ciConfigPath
                )
                try await GitHubService.shared.pushFile(
                    owner: ownerFromRepo,
                    repo: repoNameFromURL,
                    path: ciConfigPath,
                    content: ciConfigJSON,
                    message: commitMessage,
                    sha: configSHA
                )

                await MainActor.run {
                    persistCIConfiguration()
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
