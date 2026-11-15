import SwiftUI
import YcodeIDECore
import YcodeIDEShell
import SwiftCodeSDK

@MainActor
struct SpacesSettingsView: View {
    let project: Project

    @State private var provider: String = Preferences.shared.sourceControlSystem
    @AppStorage("spacesDefaultBranch") private var defaultBranch = "main"
    @State private var statusMessage: String?
    @State private var isInitializing = false

    private var hasGit: Bool {
        FileManager.default.fileExists(atPath: project.directoryURL.appendingPathComponent(".git").path)
    }

    private var hasSpaces: Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: project.directoryURL.appendingPathComponent(".spaces").path, isDirectory: &isDir) && isDir.boolValue
    }

    private var resolvedProvider: SourceControlProvider {
        GitViewModel.resolveProvider(for: project.directoryURL)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("Spaces Settings", systemImage: "gearshape.fill")
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)
                Spacer()
            }
            .padding()

            Form {
                Section("Source Control Provider") {
                    Picker("Default provider", selection: $provider) {
                        Text("Git (default)").tag("git")
                        Text("Spaces").tag("spaces")
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: provider) { _, newValue in
                        Preferences.shared.sourceControlSystem = newValue
                    }
                    Text("Git stays the default provider. Spaces is used when a repository has only a .spaces directory, or when you explicitly choose Spaces for a repository that has both .git and .spaces.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("This Repository") {
                    LabeledContent("Git repository", value: hasGit ? "Yes" : "No")
                    LabeledContent("Spaces repository", value: hasSpaces ? "Yes" : "No")
                    LabeledContent("Active provider", value: resolvedProvider == .spaces ? "Spaces" : "Git")
                    if !hasSpaces {
                        Button("Initialize Spaces Repository") { initializeSpaces() }
                            .disabled(isInitializing)
                    }
                }

                Section("New Spaces Repositories") {
                    TextField("Default branch", text: $defaultBranch)
                        .textFieldStyle(.roundedBorder)
                    Text("Used when a new Spaces repository is initialized from this app.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let statusMessage {
                    Section {
                        Text(statusMessage)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
        }
    }

    private func initializeSpaces() {
        isInitializing = true
        statusMessage = nil
        Task {
            do {
                _ = try await SpacesService.shared.initialize(at: project.directoryURL, defaultBranch: SpacesService.defaultBranchSetting)
                statusMessage = "Spaces repository initialized."
            } catch {
                statusMessage = "Initialization failed: \(error.localizedDescription)"
            }
            isInitializing = false
        }
    }
}
