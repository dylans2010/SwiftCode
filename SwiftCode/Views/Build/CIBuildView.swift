import SwiftUI

struct CIBuildView: View {
    let project: Project
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var projectManager: ProjectManager

    @State private var projectName: String = ""
    @State private var schemeName: String = ""
    @State private var xcodeVersion: String = "16.2"
    @State private var buildConfiguration: AssistCIFunctions.BuildYMLConfig.BuildConfiguration = .release
    @State private var destinationType: AssistCIFunctions.BuildYMLConfig.DestinationType = .device
    @State private var outputDirectory: String = "upload"
    @State private var outputName: String = "AppBuild"
    @State private var triggerBranch: String = "main"
    @State private var triggerMode: AssistCIFunctions.BuildYMLConfig.TriggerMode = .pushAndManual
    @State private var exportFormat: AssistCIFunctions.BuildYMLConfig.ExportFormat = .ipa

    @State private var includeTests = false
    @State private var includeLint = false
    @State private var cleanBuild = true
    @State private var failFast = true
    @State private var includeCaching = true
    @State private var uploadLogsArtifact = true

    @State private var generatedYAMLText: String = ""
    @State private var showYAMLPreview = false
    @State private var showStartBuildConfirmation = false
    @State private var showStatusAlert = false
    @State private var statusMessage = ""
    @State private var isSuccess = false

    @State private var isBuilding = false
    @State private var lastBuildTriggerAt: Date?
    private let deduplicationWindow: TimeInterval = 8

    private var buildConfig: AssistCIFunctions.BuildYMLConfig {
        AssistCIFunctions.BuildYMLConfig(
            projectName: projectName.trimmingCharacters(in: .whitespacesAndNewlines),
            scheme: schemeName.trimmingCharacters(in: .whitespacesAndNewlines),
            xcodeVersion: xcodeVersion,
            buildConfiguration: buildConfiguration,
            destinationType: destinationType,
            outputDirectory: outputDirectory.trimmingCharacters(in: .whitespacesAndNewlines),
            outputName: outputName.trimmingCharacters(in: .whitespacesAndNewlines),
            triggerBranch: triggerBranch.trimmingCharacters(in: .whitespacesAndNewlines),
            triggerMode: triggerMode,
            includeTests: includeTests,
            includeLint: includeLint,
            cleanBuild: cleanBuild,
            failFast: failFast,
            includeCaching: includeCaching,
            uploadLogsArtifact: uploadLogsArtifact,
            exportFormat: exportFormat
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [.blue.opacity(0.3), .purple.opacity(0.35), .black], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        headerCard
                        configurationCard
                        outputCard
                        optionsCard
                        actionCard
                    }
                    .padding()
                }
            }
            .navigationTitle("CI Builder")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .sheet(isPresented: $showYAMLPreview) { yamlPreviewSheet }
            .alert("Start Compiling?", isPresented: $showStartBuildConfirmation) {
                Button("Start") { startBuild() }
                Button("Cancel", role: .cancel) {}
            } message: { Text("This will generate and save .github/workflows/build.yml in the project.") }
            .alert(isSuccess ? "Success" : "Error", isPresented: $showStatusAlert) {
                Button("OK") {}
            } message: {
                Text(statusMessage)
            }
            .onAppear {
                projectName = project.name
                let ciConfig = project.ciBuildConfiguration
                schemeName = ciConfig?.schemeName.isEmpty == false ? ciConfig?.schemeName ?? project.name : project.name
                outputName = project.name
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Advanced CI Configuration")
                .font(.title3.bold())
                .foregroundStyle(.white)
            Text("Customize triggers, caching, tests, linting, artifacts, and build behavior.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var configurationCard: some View {
        VStack(spacing: 12) {
            labeledField("Project Name", text: $projectName)
            labeledField("Scheme", text: $schemeName)
            labeledField("Branch", text: $triggerBranch)

            Picker("Trigger", selection: $triggerMode) {
                ForEach(AssistCIFunctions.BuildYMLConfig.TriggerMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }

            Picker("Xcode", selection: $xcodeVersion) {
                Text("16.2").tag("16.2")
                Text("16.1").tag("16.1")
                Text("16.0").tag("16.0")
                Text("15.4").tag("15.4")
            }
            .pickerStyle(.segmented)

            Picker("Build Configuration", selection: $buildConfiguration) {
                ForEach(AssistCIFunctions.BuildYMLConfig.BuildConfiguration.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            Picker("Target", selection: $destinationType) {
                Text("Device").tag(AssistCIFunctions.BuildYMLConfig.DestinationType.device)
                Text("Simulator").tag(AssistCIFunctions.BuildYMLConfig.DestinationType.simulator)
            }
            .pickerStyle(.segmented)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var outputCard: some View {
        VStack(spacing: 12) {
            labeledField("Output Directory", text: $outputDirectory)
            labeledField("Output Name", text: $outputName)

            Picker("Artifact Export", selection: $exportFormat) {
                ForEach(AssistCIFunctions.BuildYMLConfig.ExportFormat.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var optionsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Run tests", isOn: $includeTests)
            Toggle("Run lint step", isOn: $includeLint)
            Toggle("Clean before archive", isOn: $cleanBuild)
            Toggle("Fail fast (set -e)", isOn: $failFast)
            Toggle("Cache DerivedData", isOn: $includeCaching)
            Toggle("Upload build logs artifact", isOn: $uploadLogsArtifact)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var actionCard: some View {
        VStack(spacing: 10) {
            Button {
                generatedYAMLText = AssistCIFunctions.generateBuildYML(config: buildConfig)
                showYAMLPreview = true
            } label: {
                Label("Preview build.yml", systemImage: "doc.text.magnifyingglass")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button { showStartBuildConfirmation = true } label: {
                HStack {
                    if isBuilding { ProgressView().tint(.white) }
                    Text(isBuilding ? "Building..." : "Start Build")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            .disabled(isBuilding)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func labeledField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.white.opacity(0.8))
            TextField(label, text: text)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
    }

    private var yamlPreviewSheet: some View {
        NavigationStack {
            ScrollView {
                Text(generatedYAMLText)
                    .font(.system(size: 11, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.black)
            .navigationTitle("build.yml")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { showYAMLPreview = false } } }
        }
    }

    private func startBuild() {
        guard !isBuilding else { return }
        if let lastBuildTriggerAt, Date().timeIntervalSince(lastBuildTriggerAt) < deduplicationWindow {
            isSuccess = false
            statusMessage = "Build ignored to prevent duplicate triggers. Please wait a few seconds."
            showStatusAlert = true
            return
        }

        let trimmedProject = buildConfig.projectName
        let trimmedScheme = buildConfig.scheme
        guard !trimmedProject.isEmpty, !trimmedScheme.isEmpty else {
            isSuccess = false
            statusMessage = "Project name and scheme are required."
            showStatusAlert = true
            return
        }

        isBuilding = true
        lastBuildTriggerAt = Date()

        Task {
            do {
                let projectWorkflowDir = project.directoryURL.appendingPathComponent(".github/workflows", isDirectory: true)
                try FileManager.default.createDirectory(at: projectWorkflowDir, withIntermediateDirectories: true)
                let yamlText = AssistCIFunctions.generateBuildYML(config: buildConfig)
                try yamlText.write(to: projectWorkflowDir.appendingPathComponent("build.yml"), atomically: true, encoding: .utf8)

                await MainActor.run {
                    projectManager.refreshFileTree(for: project)
                    isSuccess = true
                    statusMessage = "Generated build.yml in project workflows folder."
                    isBuilding = false
                    showStatusAlert = true
                }
            } catch {
                await MainActor.run {
                    isSuccess = false
                    statusMessage = error.localizedDescription
                    isBuilding = false
                    showStatusAlert = true
                }
            }
        }
    }
}
