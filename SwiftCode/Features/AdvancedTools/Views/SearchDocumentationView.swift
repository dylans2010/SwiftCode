import SwiftUI
import ZIPFoundation

struct SearchDocumentationView: View {
    @EnvironmentObject private var projectManager: ProjectManager
    @State private var repositoryURL = ""
    @State private var selectedFolderURL: URL?
    @State private var selectedArchiveURL: URL?
    @State private var isScanning = false
    @State private var prompt = ""
    @State private var chatHistory: [SearchDocChatMessage] = []
    @State private var report = RepositoryKnowledgeReport.empty
    @State private var reportError: String?

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
                    if let reportError {
                        Text(reportError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

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
        reportError = nil
        Task {
            do {
                report = try await RepositoryKnowledgeReport.from(source: source)
                chatHistory = []
            } catch {
                report = .empty
                reportError = error.localizedDescription
            }
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
    var searchableSnippets: [String]

    static let empty = Self(projectSummary: "", architectureOverview: "", importantFiles: "", dependencies: "", integrationGuide: "", searchableSnippets: [])

    static func from(source: RepositorySource) async throws -> Self {
        let rootURL = try await resolveRootURL(for: source)
        return try analyze(rootURL: rootURL)
    }

    private static func resolveRootURL(for source: RepositorySource) async throws -> URL {
        switch source {
        case .folder(let url):
            guard let url else { throw NSError(domain: "SearchDocumentation", code: 1, userInfo: [NSLocalizedDescriptionKey: "No local folder available."]) }
            return url
        case .zip(let url):
            guard let url else { throw NSError(domain: "SearchDocumentation", code: 2, userInfo: [NSLocalizedDescriptionKey: "ZIP file path is missing."]) }
            let dest = FileManager.default.temporaryDirectory.appendingPathComponent("repo-unzip-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
            try FileManager.default.unzipItem(at: url, to: dest)
            if let first = try FileManager.default.contentsOfDirectory(at: dest, includingPropertiesForKeys: nil).first {
                return first
            }
            return dest
        case .github(let value):
            guard let url = URL(string: value), !value.isEmpty else {
                throw NSError(domain: "SearchDocumentation", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid GitHub URL."])
            }
            let zipURL = URL(string: url.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/archive/refs/heads/main.zip")!
            let (data, _) = try await URLSession.shared.data(from: zipURL)
            let tmpZip = FileManager.default.temporaryDirectory.appendingPathComponent("repo-download-\(UUID().uuidString).zip")
            try data.write(to: tmpZip)
            return try await resolveRootURL(for: .zip(tmpZip))
        }
    }

    private static func analyze(rootURL: URL) throws -> Self {
        let fm = FileManager.default
        let allowed = Set(["swift", "md", "txt", "json", "yaml", "yml", "plist"])
        let enumerator = fm.enumerator(at: rootURL, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])

        var files: [URL] = []
        while let item = enumerator?.nextObject() as? URL {
            if allowed.contains(item.pathExtension.lowercased()) { files.append(item) }
        }

        let snippetLines = files.prefix(30).compactMap { url -> String? in
            guard let data = try? Data(contentsOf: url), let content = String(data: data, encoding: .utf8) else { return nil }
            let first = content.split(separator: "\n").prefix(2).joined(separator: " ")
            return "\(url.lastPathComponent): \(first)"
        }

        let readme = files.first(where: { $0.lastPathComponent.lowercased().contains("readme") })
        let readmeText = readme.flatMap { try? String(contentsOf: $0) } ?? ""

        let dependenciesText = files.filter { ["package.swift", "podfile", "cartfile"].contains($0.lastPathComponent.lowercased()) }
            .compactMap { try? String(contentsOf: $0) }
            .joined(separator: "\n")

        let swiftFiles = files.filter { $0.pathExtension.lowercased() == "swift" }
        let importSet = Set(swiftFiles.compactMap { try? String(contentsOf: $0) }
            .flatMap { text in
                text.split(separator: "\n").compactMap { line -> String? in
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    guard trimmed.hasPrefix("import ") else { return nil }
                    return String(trimmed.dropFirst("import ".count))
                }
            })

        let important = files.sorted { $0.path.count < $1.path.count }.prefix(8).map { "- " + $0.path.replacingOccurrences(of: rootURL.path + "/", with: "") }.joined(separator: "\n")

        return .init(
            projectSummary: "Repository root: \(rootURL.lastPathComponent)\nFiles scanned: \(files.count)\n\(readmeText.prefix(350))",
            architectureOverview: "Swift files: \(swiftFiles.count). Imported modules: \(importSet.sorted().joined(separator: ", ")).",
            importantFiles: important,
            dependencies: dependenciesText.isEmpty ? "No dependency manifests found." : String(dependenciesText.prefix(600)),
            integrationGuide: "1. Start from README and manifests.\n2. Inspect key source files listed above.\n3. Follow module imports to integration points.\n4. Validate by running project tests/build.",
            searchableSnippets: snippetLines
        )
    }

    func answer(for query: String) -> String {
        let terms = query.lowercased().split(separator: " ").map(String.init)
        let matches = searchableSnippets.filter { snippet in
            let lower = snippet.lowercased()
            return terms.contains(where: { lower.contains($0) })
        }.prefix(5)

        if matches.isEmpty {
            return "No direct text match found. Try asking with specific filenames, symbols, or module names."
        }

        return "Top relevant snippets:\n" + matches.joined(separator: "\n")
    }
}
