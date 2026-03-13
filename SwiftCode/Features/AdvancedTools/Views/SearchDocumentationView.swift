import SwiftUI
import ZIPFoundation

struct SearchDocumentationView: View {
    @EnvironmentObject private var projectManager: ProjectManager
    @StateObject private var viewModel = RepositoryAnalysisViewModel()
    @State private var repositoryURL = ""
    @State private var prompt = ""

    var body: some View {
        AdvancedToolScreen(title: "Repository AI Search") {
            AdvancedToolCard(title: "Repository Input", subtitle: "Fast background scanning with progress feedback") {
                TextField("GitHub repository URL", text: $repositoryURL)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button("Analyze GitHub URL") { viewModel.runScan(source: .github(repositoryURL)) }
                        .buttonStyle(.borderedProminent)
                    Button("Analyze ZIP") {
                        viewModel.runScan(source: .zip(URL(fileURLWithPath: "/tmp/repository.zip")))
                    }
                    .buttonStyle(.bordered)
                    Button("Analyze Local Folder") {
                        viewModel.runScan(source: .folder(projectManager.activeProject?.directoryURL))
                    }
                    .buttonStyle(.bordered)
                }

                if viewModel.isScanning {
                    ProgressView(value: viewModel.progress)
                    Text(viewModel.statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let reportError = viewModel.reportError {
                    Text(reportError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            repositorySection(title: "Project Summary", content: viewModel.report.projectSummary)
            repositorySection(title: "Architecture Overview", content: viewModel.report.architectureOverview)
            repositorySection(title: "Important Files", content: viewModel.report.importantFiles)
            repositorySection(title: "Dependencies", content: viewModel.report.dependencies)
            repositorySection(title: "Integration Guide", content: viewModel.report.integrationGuide)

            AdvancedToolCard(title: "Ask Questions", subtitle: "Search indexed snippets from the latest analysis") {
                ForEach(viewModel.chatHistory) { message in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(message.role)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(message.text)
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                }

                HStack {
                    TextField("How do I integrate this module?", text: $prompt)
                        .textFieldStyle(.roundedBorder)
                    Button("Send") {
                        viewModel.askQuestion(prompt)
                        prompt = ""
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private func repositorySection(title: String, content: String) -> some View {
        AdvancedToolCard(title: title) {
            Text(content.isEmpty ? "No analysis yet." : content)
                .font(.subheadline)
                .textSelection(.enabled)
        }
    }
}

@MainActor
private final class RepositoryAnalysisViewModel: ObservableObject {
    @Published var isScanning = false
    @Published var progress = 0.0
    @Published var statusMessage = "Idle"
    @Published var reportError: String?
    @Published var report = RepositoryKnowledgeReport.empty
    @Published var chatHistory: [SearchDocChatMessage] = []

    private var scanTask: Task<Void, Never>?

    func runScan(source: RepositorySource) {
        scanTask?.cancel()
        isScanning = true
        progress = 0
        statusMessage = "Preparing analysis..."
        reportError = nil

        scanTask = Task {
            do {
                let result = try await RepositoryKnowledgeReport.from(source: source) { [weak self] update in
                    await MainActor.run {
                        self?.progress = update.progress
                        self?.statusMessage = update.message
                    }
                }
                await MainActor.run {
                    self.report = result
                    self.chatHistory = []
                    self.isScanning = false
                }
            } catch {
                await MainActor.run {
                    self.report = .empty
                    self.reportError = error.localizedDescription
                    self.isScanning = false
                }
            }
        }
    }

    func askQuestion(_ rawPrompt: String) {
        let query = rawPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        chatHistory.append(.init(role: "You", text: query))
        chatHistory.append(.init(role: "AI", text: report.answer(for: query)))
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

private struct RepositoryProgressUpdate {
    let progress: Double
    let message: String
}

private enum RepositoryScanError: LocalizedError {
    case invalidLocalFolder
    case missingZipPath
    case invalidGitHubURL
    case unsupportedGitHubURL
    case githubListingFailed
    case corruptedArchive
    case emptyRepository

    var errorDescription: String? {
        switch self {
        case .invalidLocalFolder: return "No local folder available."
        case .missingZipPath: return "ZIP file path is missing."
        case .invalidGitHubURL: return "Invalid GitHub URL."
        case .unsupportedGitHubURL: return "Only github.com repository URLs are supported."
        case .githubListingFailed: return "Failed to list repository contents from GitHub."
        case .corruptedArchive: return "The ZIP archive appears invalid or corrupted."
        case .emptyRepository: return "No supported documentation/source files were found."
        }
    }
}

private struct RepositoryKnowledgeReport {
    var projectSummary: String
    var architectureOverview: String
    var importantFiles: String
    var dependencies: String
    var integrationGuide: String
    var searchableSnippets: [String]

    static let empty = Self(projectSummary: "", architectureOverview: "", importantFiles: "", dependencies: "", integrationGuide: "", searchableSnippets: [])

    static func from(source: RepositorySource, progress: @escaping (RepositoryProgressUpdate) async -> Void) async throws -> Self {
        switch source {
        case .folder(let url):
            guard let root = url else { throw RepositoryScanError.invalidLocalFolder }
            await progress(.init(progress: 0.05, message: "Scanning local repository..."))
            return try await analyzeLocalRepository(rootURL: root, progress: progress)
        case .zip(let url):
            guard let zipURL = url else { throw RepositoryScanError.missingZipPath }
            await progress(.init(progress: 0.1, message: "Extracting archive..."))
            let rootURL = try extractZip(at: zipURL)
            return try await analyzeLocalRepository(rootURL: rootURL, progress: progress)
        case .github(let value):
            return try await analyzeGitHubRepository(input: value, progress: progress)
        }
    }

    private static func analyzeGitHubRepository(input: String, progress: @escaping (RepositoryProgressUpdate) async -> Void) async throws -> Self {
        await progress(.init(progress: 0.05, message: "Validating GitHub URL..."))
        guard let parsed = GitHubRepoReference(urlString: input) else { throw RepositoryScanError.invalidGitHubURL }
        guard parsed.host == "github.com" else { throw RepositoryScanError.unsupportedGitHubURL }

        await progress(.init(progress: 0.15, message: "Listing repository tree from GitHub API..."))
        let (manifestFiles, dependencyFiles, readmeFile) = try await fetchGitHubFileManifests(for: parsed)

        await progress(.init(progress: 0.35, message: "Fetching targeted files..."))
        let lightweight = try await buildLightweightReportFromGitHub(parsed: parsed, manifests: manifestFiles, dependencyPaths: dependencyFiles, readmePath: readmeFile, progress: progress)
        return lightweight
    }

    private static func extractZip(at url: URL) throws -> URL {
        let dest = FileManager.default.temporaryDirectory.appendingPathComponent("repo-unzip-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
        do {
            try FileManager.default.unzipItem(at: url, to: dest)
        } catch {
            throw RepositoryScanError.corruptedArchive
        }

        if let first = try? FileManager.default.contentsOfDirectory(at: dest, includingPropertiesForKeys: nil).first {
            return first
        }
        return dest
    }

    private static func analyzeLocalRepository(rootURL: URL, progress: @escaping (RepositoryProgressUpdate) async -> Void) async throws -> Self {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let fm = FileManager.default
                    let allowed = Set(["swift", "md", "txt", "json", "yaml", "yml", "plist"])
                    let enumerator = fm.enumerator(at: rootURL, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants])

                    var files: [URL] = []
                    var scanned = 0
                    while let item = enumerator?.nextObject() as? URL {
                        scanned += 1
                        if scanned % 250 == 0 {
                            Task { await progress(.init(progress: min(0.2 + Double(scanned) / 50000.0, 0.7), message: "Indexed \(scanned) paths...")) }
                        }
                        if allowed.contains(item.pathExtension.lowercased()) { files.append(item) }
                    }

                    guard !files.isEmpty else { throw RepositoryScanError.emptyRepository }
                    Task { await progress(.init(progress: 0.78, message: "Analyzing code structure...")) }
                    continuation.resume(returning: try buildReport(rootURL: rootURL, files: files))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func buildReport(rootURL: URL, files: [URL]) throws -> Self {
        let snippetLines = files.prefix(80).compactMap { url -> String? in
            guard let handle = try? FileHandle(forReadingFrom: url),
                  let data = try? handle.read(upToCount: 1600),
                  let content = String(data: data ?? Data(), encoding: .utf8)
            else { return nil }
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

        let important = files.sorted { $0.path.count < $1.path.count }
            .prefix(10)
            .map { "- " + $0.path.replacingOccurrences(of: rootURL.path + "/", with: "") }
            .joined(separator: "\n")

        return .init(
            projectSummary: "Repository root: \(rootURL.lastPathComponent)\nFiles scanned: \(files.count)\n\(readmeText.prefix(600))",
            architectureOverview: "Swift files: \(swiftFiles.count). Imported modules: \(importSet.sorted().joined(separator: ", ")).",
            importantFiles: important,
            dependencies: dependenciesText.isEmpty ? "No dependency manifests found." : String(dependenciesText.prefix(1000)),
            integrationGuide: "1. Start from README and manifest files.\n2. Inspect the key files listed above.\n3. Follow imported modules to locate boundaries and extension points.\n4. Validate integration with project tests/build.",
            searchableSnippets: snippetLines
        )
    }

    private static func fetchGitHubFileManifests(for ref: GitHubRepoReference) async throws -> ([String], [String], String?) {
        let treeURL = URL(string: "https://api.github.com/repos/\(ref.owner)/\(ref.repo)/git/trees/\(ref.branch)?recursive=1")!
        let (data, response) = try await URLSession.shared.data(from: treeURL)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw RepositoryScanError.githubListingFailed }

        let decoded = try JSONDecoder().decode(GitHubTreeResponse.self, from: data)
        let allowed = Set(["swift", "md", "txt", "json", "yaml", "yml", "plist"])
        let manifests = decoded.tree
            .filter { $0.type == "blob" }
            .map(\.path)
            .filter { path in
                let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
                return allowed.contains(ext)
            }
            .prefix(250)
            .map { String($0) }

        let dependency = decoded.tree
            .filter { ["package.swift", "podfile", "cartfile"].contains($0.path.lowercased()) }
            .map(\.path)
        let readme = decoded.tree.first(where: { $0.path.lowercased().contains("readme") })?.path

        return (Array(manifests), dependency, readme)
    }

    private static func buildLightweightReportFromGitHub(parsed: GitHubRepoReference, manifests: [String], dependencyPaths: [String], readmePath: String?, progress: @escaping (RepositoryProgressUpdate) async -> Void) async throws -> Self {
        let swiftFiles = manifests.filter { $0.lowercased().hasSuffix(".swift") }
        var snippetLines: [String] = []
        var imports = Set<String>()
        var readmeText = ""
        var dependencyText = ""

        let sampleFiles = manifests.prefix(60)
        for (index, path) in sampleFiles.enumerated() {
            if index % 8 == 0 {
                await progress(.init(progress: 0.35 + (Double(index) / Double(max(sampleFiles.count, 1))) * 0.45, message: "Downloading indexed files (\(index + 1)/\(sampleFiles.count))..."))
            }

            if let content = try await fetchGitHubFileContent(parsed: parsed, path: path) {
                let head = content.split(separator: "\n").prefix(2).joined(separator: " ")
                snippetLines.append("\(URL(fileURLWithPath: path).lastPathComponent): \(head)")

                if path.lowercased().hasSuffix(".swift") {
                    content.split(separator: "\n").forEach { line in
                        let trimmed = line.trimmingCharacters(in: .whitespaces)
                        if trimmed.hasPrefix("import ") {
                            imports.insert(String(trimmed.dropFirst(7)))
                        }
                    }
                }
            }
        }

        if let readmePath, let readme = try await fetchGitHubFileContent(parsed: parsed, path: readmePath) {
            readmeText = String(readme.prefix(600))
        }

        if !dependencyPaths.isEmpty {
            for path in dependencyPaths.prefix(4) {
                if let body = try await fetchGitHubFileContent(parsed: parsed, path: path) {
                    dependencyText += "\n\n# \(path)\n\(body.prefix(500))"
                }
            }
        }

        await progress(.init(progress: 0.9, message: "Compiling report..."))
        let important = manifests.prefix(10).map { "- \($0)" }.joined(separator: "\n")

        return .init(
            projectSummary: "Repository: \(parsed.owner)/\(parsed.repo)\nIndexed files: \(manifests.count)\n\(readmeText)",
            architectureOverview: "Swift files discovered: \(swiftFiles.count). Imported modules found in sampled files: \(imports.sorted().joined(separator: ", ")).",
            importantFiles: important,
            dependencies: dependencyText.isEmpty ? "No dependency manifests found." : dependencyText,
            integrationGuide: "1. Review README and dependency manifests.\n2. Start integration from important files list.\n3. Follow imports to identify boundaries.\n4. Validate with project build/test steps.",
            searchableSnippets: snippetLines
        )
    }

    private static func fetchGitHubFileContent(parsed: GitHubRepoReference, path: String) async throws -> String? {
        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        let contentsURL = URL(string: "https://raw.githubusercontent.com/\(parsed.owner)/\(parsed.repo)/\(parsed.branch)/\(encodedPath)")!
        let (data, response) = try await URLSession.shared.data(from: contentsURL)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return String(data: data, encoding: .utf8)
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

private struct GitHubRepoReference {
    let host: String
    let owner: String
    let repo: String
    let branch: String

    init?(urlString: String) {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)),
              let host = url.host else { return nil }
        let parts = url.path.split(separator: "/").map(String.init)
        guard parts.count >= 2 else { return nil }
        self.host = host
        owner = parts[0]
        repo = parts[1].replacingOccurrences(of: ".git", with: "")

        if let branchIndex = parts.firstIndex(of: "tree"), parts.indices.contains(branchIndex + 1) {
            branch = parts[branchIndex + 1]
        } else {
            branch = "main"
        }
    }
}

private struct GitHubTreeResponse: Decodable {
    let tree: [GitHubTreeNode]
}

private struct GitHubTreeNode: Decodable {
    let path: String
    let type: String
}
