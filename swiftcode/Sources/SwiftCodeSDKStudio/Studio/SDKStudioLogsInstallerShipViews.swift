import Foundation
import SwiftUI
import SwiftCodeExtensions
import SwiftCodeSDK

@MainActor
struct SDKFirstLaunchInstallerView: View {
    var installer: any SDKStudioInstaller

    @Environment(\.dismiss) private var dismiss
    @State private var phase: Phase = .prompt
    @State private var logLines: [String] = []

    private enum Phase: Equatable {
        case prompt
        case installing
        case succeeded(SDKStudioInstallResult)
        case failed(SDKStudioInstallResult)
    }

    init(installer: any SDKStudioInstaller) {
        self.installer = installer
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch phase {
            case .prompt:
                Text("Install the SwiftCode SDK?").font(.title2.bold())
                Text("Install location")
                    .font(.headline)
                Text(type(of: installer).defaultPrefix.path)
                    .font(.callout.monospaced())
                Text("The SDK is required to build extensions. Node.js is required.")
                    .foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    Button("Install SDK") { startInstall() }
                        .buttonStyle(.borderedProminent)
                    Button("Remind Me Later") {
                        SDKStudioFirstLaunchChoice.recordRemindLater()
                        dismiss()
                    }
                    Button("Decline") {
                        SDKStudioFirstLaunchChoice.recordDeclined()
                        dismiss()
                    }
                }
            case .installing:
                Text("Installing SwiftCode SDK…").font(.title2.bold())
                Text("Running npm install. Every line below is live output from the installer.")
                    .foregroundStyle(.secondary)
                ScrollView {
                    Text(logLines.joined(separator: "\n"))
                        .font(.caption.monospaced())
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: 200)
            case .succeeded(let result):
                Text("SDK Installed").font(.title2.bold())
                Text(result.detail)
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
            case .failed(let result):
                Text("Installation Failed").font(.title2.bold())
                Text(result.detail).foregroundStyle(.red)
                ScrollView {
                    Text(result.logLines.joined(separator: "\n"))
                        .font(.caption.monospaced())
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: 120)
                HStack(spacing: 12) {
                    Button("Retry") { startInstall() }
                        .buttonStyle(.borderedProminent)
                    Button("Close") { dismiss() }
                }
            }
        }
        .padding()
        .frame(minWidth: 560, minHeight: 420)
    }

    private func startInstall() {
        phase = .installing
        logLines = []
        let collector = SDKInstallerLogCollector()
        Task {
            let result = await installer.install { line in
                Task { await collector.append(line) }
            }
            logLines = await collector.all()
            if result.succeeded {
                SDKStudioFirstLaunchChoice.recordInstalled()
                phase = .succeeded(result)
            } else {
                phase = .failed(result)
            }
        }
    }
}

private actor SDKInstallerLogCollector {
    private var lines: [String] = []
    func append(_ line: String) { lines.append(line) }
    func all() -> [String] { lines }
}

@MainActor
struct SDKShipExportView: View {
    @Bindable var editorState: SDKCodeEditorState

    @State private var projectPathText: String = ""
    @State private var summary: SwiftCodeSDK.ProjectMetadata?
    @State private var summaryError: String?
    @State private var destinationText: String = ""
    @State private var phase: Phase = .idle
    @State private var manualCommand: String?
    @State private var showingManualCommand = false

    private enum Phase: Equatable {
        case idle
        case running
        case succeeded(URL)
        case failed(String)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Ship / Export").font(.title2.bold())
                Text("Package an extension for distribution. The export writes a .tgz of the project directory (excluding node_modules and .git).")
                    .foregroundStyle(.secondary)
                HStack {
                    TextField("/path/to/project", text: $projectPathText)
                        .textFieldStyle(.roundedBorder)
                    Button("Load Project") { loadProject() }
                }
                if let summaryError {
                    Text(summaryError).foregroundStyle(.red)
                }
                if let summary {
                    SDKStudioGroupBox("Project Summary") {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(summary.id) · v\(summary.version) · \(summary.type.displayName)")
                                .font(.headline)
                            Text(summary.name)
                            Text(summary.rootPath).font(.caption.monospaced()).foregroundStyle(.secondary)
                            ForEach(summary.targets, id: \.name) { target in
                                Text("Target: \(target.name) (\(target.type))").font(.caption)
                            }
                        }
                    }
                }
                HStack {
                    TextField("/path/to/export.tgz", text: $destinationText)
                        .textFieldStyle(.roundedBorder)
                    Button("Export") { export() }
                        .buttonStyle(.borderedProminent)
                        .disabled(summary == nil || destinationText.isEmpty || phase == .running)
                }
                switch phase {
                case .idle:
                    EmptyView()
                case .running:
                    ProgressView("Exporting…")
                case .succeeded(let url):
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Exported successfully.").font(.headline).foregroundStyle(.green)
                        Text(url.path).font(.callout.monospaced())
                    }
                case .failed(let message):
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Export failed.").font(.headline).foregroundStyle(.red)
                        Text(message)
                        Button("Show Manual Command") {
                            manualCommand = manualCommandText()
                            showingManualCommand = true
                        }
                    }
                }
            }
            .padding()
        }
        .onAppear {
            projectPathText = editorState.projectRootURL?.path ?? ""
            if !projectPathText.isEmpty { loadProject() }
        }
        .sheet(isPresented: $showingManualCommand) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Manual Export Command").font(.headline)
                Text(manualCommand ?? "").font(.callout.monospaced())
                Button("Close") { showingManualCommand = false }
            }
            .padding()
            .frame(minWidth: 520)
        }
    }

    private func loadProject() {
        let path = projectPathText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { return }
        do {
            summary = try ProjectInspector().inspect(at: path)
            summaryError = nil
            if destinationText.isEmpty {
                destinationText = (path as NSString).appendingPathComponent(
                    "\(URL(fileURLWithPath: path).lastPathComponent).tgz")
            }
        } catch {
            summary = nil
            summaryError = error.localizedDescription
        }
    }

    private func manualCommandText() -> String {
        "tar --exclude=node_modules --exclude=.git -czf \"\(destinationText)\" -C \"\(projectPathText)\" ."
    }

    private func export() {
        guard let summary else { return }
        phase = .running
        let source = URL(fileURLWithPath: summary.rootPath)
        let destination = URL(fileURLWithPath: destinationText)
        Task {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            process.arguments = ["--exclude=node_modules", "--exclude=.git", "-czf",
                                 destination.path, "-C", source.path, "."]
            let pipe = Pipe()
            process.standardError = pipe
            do {
                try process.run()
                process.waitUntilExit()
                if process.terminationStatus == 0 {
                    phase = .succeeded(destination)
                } else {
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let detail = String(data: data, encoding: .utf8) ?? "tar exited with status \(process.terminationStatus)."
                    phase = .failed(detail)
                }
            } catch {
                phase = .failed(error.localizedDescription)
            }
        }
    }
}
