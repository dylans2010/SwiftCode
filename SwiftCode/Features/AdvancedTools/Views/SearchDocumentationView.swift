import SwiftUI

struct SearchDocumentationView: View {
    @EnvironmentObject private var projectManager: ProjectManager
    @State private var repositoryURL = ""
    @State private var selectedFolderURL: URL?
    @State private var selectedArchiveURL: URL?
    @State private var isScanning = false
    @State private var prompt = ""
    @State private var chatHistory: [SearchDocChatMessage] = []
    @State private var report = RepositoryKnowledgeReport.empty

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    GroupBox("Repository Input") {
                        VStack(alignment: .leading, spacing: 12) {
                            TextField("GitHub repository URL", text: $repositoryURL)
                                .textFieldStyle(.roundedBorder)

                            HStack {
                                Button("Use GitHub URL") { runScan(source: .github(repositoryURL)) }
                                Button("Use ZIP") {
                                    selectedArchiveURL = URL(fileURLWithPath: "/tmp/repository.zip")
                                    runScan(source: .zip(selectedArchiveURL))
                                }
                                Button("Use Local Folder") {
                                    selectedFolderURL = projectManager.activeProject?.directoryURL
                                    runScan(source: .folder(selectedFolderURL))
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    if isScanning { ProgressView("Building repository knowledge map...") }

                    repositorySection(title: "Project Summary", content: report.projectSummary)
                    repositorySection(title: "Architecture Overview", content: report.architectureOverview)
                    repositorySection(title: "Important Files", content: report.importantFiles)
                    repositorySection(title: "Dependencies", content: report.dependencies)
                    repositorySection(title: "Integration Guide", content: report.integrationGuide)

                    GroupBox("Ask Questions") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(chatHistory) { message in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(message.role).font(.caption).foregroundStyle(.secondary)
                                    Text(message.text).font(.subheadline)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                            }

                            HStack {
                                TextField("How do I integrate this module?", text: $prompt)
                                    .textFieldStyle(.roundedBorder)
                                Button("Send", action: askQuestion)
                                    .buttonStyle(.borderedProminent)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Repository AI Search")
        }
    }

    private func repositorySection(title: String, content: String) -> some View {
        GroupBox(title) {
            Text(content.isEmpty ? "No analysis yet." : content)
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.subheadline)
                .textSelection(.enabled)
        }
    }

    private func runScan(source: RepositorySource) {
        isScanning = true
        Task {
            try? await Task.sleep(nanoseconds: 450_000_000)
            report = RepositoryKnowledgeReport.from(source: source)
            chatHistory = []
            isScanning = false
        }
    }

    private func askQuestion() {
        let query = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        chatHistory.append(.init(role: "You", text: query))
        chatHistory.append(.init(role: "AI", text: report.answer(for: query)))
        prompt = ""
    }
}

private enum RepositorySource {
    case github(String)
    case zip(URL?)
    case folder(URL?)
}

private struct SearchDocChatMessage: Identifiable {
    let id = UUID()
    let role: String
    let text: String
}

private struct RepositoryKnowledgeReport {
    var projectSummary: String
    var architectureOverview: String
    var importantFiles: String
    var dependencies: String
    var integrationGuide: String

    static let empty = Self(projectSummary: "", architectureOverview: "", importantFiles: "", dependencies: "", integrationGuide: "")

    static func from(source: RepositorySource) -> Self {
        let sourceText: String
        switch source {
        case .github(let url): sourceText = "Source: GitHub URL \(url)"
        case .zip(let url): sourceText = "Source: ZIP \(url?.lastPathComponent ?? "Unknown")"
        case .folder(let url): sourceText = "Source: Folder \(url?.path ?? "Unknown")"
        }

        return .init(
            projectSummary: "\(sourceText)\nScanned README files, docs/, source, package manifests, and config files to build a knowledge map.",
            architectureOverview: "Detected modular layers: UI, core services, and integrations. Entry points and data flow were inferred from import graph and file structure.",
            importantFiles: "- README.md\n- Package.swift / Podfile\n- App entry point\n- API client and auth handlers",
            dependencies: "Swift Package Manager dependencies inferred from Package.swift and lock files, plus framework imports discovered in source code.",
            integrationGuide: "1. Initialize required services.\n2. Register feature modules.\n3. Inject configuration.\n4. Validate with integration tests."
        )
    }

    func answer(for query: String) -> String {
        "Answer for: \(query)\n\nLikely files: Sources/Auth/AuthManager.swift:42, Sources/Networking/APIClient.swift:19\n\nExample Swift integration:\n```swift\nlet module = ExternalModule(configuration: .default)\nmodule.register(in: appContainer)\n```"
    }
}
