import SwiftUI
import YcodeAssistant
import SwiftCodeGitHub
import SwiftCodeSDK
import YcodeIDECore
import YcodeIDEShell
import AppKit
import os.log

private let logger = Logger(subsystem: "com.swiftcode.SourceControl", category: "GitBlameViewer")

@MainActor
public struct GitBlameViewer: View {
    var gitViewModel: GitViewModel

    @State private var fileList: [URL] = []
    @State private var selectedFile: URL?
    @State private var fileSearchText = ""

    @State private var blameLines: [BlameLineEntry] = []
    @State private var isLoadingBlame = false
    @State private var blameError: String?
    @State private var selectedLineIndex: Int?

    @State private var blameSearchText = ""
    @State private var filterAuthor = ""

    @State private var hoverCommitSHA = ""
    @State private var hoverCommitDetails: String?
    @State private var isShowingPopover = false

    public struct BlameLineEntry: Identifiable, Equatable {
        public let id = UUID()
        public let lineNumber: Int
        public let sha: String
        public let author: String
        public let date: String
        public let code: String
    }

    struct IndexedBlameLineEntry: Identifiable {
        let index: Int
        let entry: BlameLineEntry
        var id: UUID { entry.id }
    }

    private var indexedBlameLines: [IndexedBlameLineEntry] {
        processedBlameLines.enumerated().map { IndexedBlameLineEntry(index: $0.offset, entry: $0.element) }
    }

    private var filteredFiles: [URL] {
        fileList.filter {
            fileSearchText.isEmpty || $0.lastPathComponent.localizedCaseInsensitiveContains(fileSearchText)
        }
    }

    public init(gitViewModel: GitViewModel) {
        self.gitViewModel = gitViewModel
    }

    public var body: some View {
        HSplitView {
            fileSelectorSidebarPanel
                .frame(width: 220)
                .frame(maxHeight: .infinity)
                .layoutPriority(1)

            blameEditorWorkspacePanel
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(2)
        }
        .onAppear {
            loadRepositoryFiles()
        }
    }

    private var fileSelectorSidebarPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("SELECT SOURCE FILE")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .liquidGlass(style: .subtle, cornerRadius: 8)

            Divider()

            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search files...", text: $fileSearchText)
                    .textFieldStyle(.plain)
            }
            .padding(6)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .padding(8)

            Divider()

            if filteredFiles.isEmpty {
                Text("No files matches")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
                Spacer()
            } else {
                List(filteredFiles, id: \.self) { url in
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundStyle(.secondary)
                        Text(url.lastPathComponent)
                            .font(.subheadline)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.vertical, 2)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedFile = url
                        loadBlameInfo(for: url)
                    }
                    .listRowBackground(selectedFile == url ? Color.accentColor.opacity(0.1) : Color.clear)
                }
                .listStyle(.plain)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var blameEditorWorkspacePanel: some View {
        VStack(spacing: 0) {
            if let file = selectedFile {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(file.lastPathComponent)
                            .font(.headline)
                        Text(file.path)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        HStack {
                            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                            TextField("Find blame...", text: $blameSearchText)
                                .textFieldStyle(.plain)
                                .controlSize(.small)
                        }
                        .padding(4)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(4)
                        .frame(width: 140)

                        TextField("Author", text: $filterAuthor)
                            .textFieldStyle(.roundedBorder)
                            .controlSize(.small)
                            .frame(width: 80)
                    }
                }
                .padding()
                .background(Color(NSColor.windowBackgroundColor))

                Divider()

                if isLoadingBlame {
                    VStack {
                        ProgressView().controlSize(.small)
                        Text("Reading native git blame markers...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let blameError {
                    ContentUnavailableView(
                        "Blame Unavailable",
                        systemImage: "exclamationmark.triangle",
                        description: Text(blameError)
                    )
                } else if blameLines.isEmpty {
                    ContentUnavailableView(
                        "No Blame History Loaded",
                        systemImage: "doc.text",
                        description: Text("Choose a file from the sidebar to execute native git blame annotations.")
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(indexedBlameLines) { item in
                                let index = item.index
                                let entry = item.entry
                                let isSelected = selectedLineIndex == index

                                HStack(spacing: 0) {
                                    Button {
                                        triggerCommitPopover(sha: entry.sha)
                                    } label: {
                                        Text(String(entry.sha.prefix(7)))
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundStyle(Color.accentColor)
                                            .frame(width: 55, alignment: .leading)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.leading, 8)

                                    Text(entry.author)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .frame(width: 100, alignment: .leading)
                                        .padding(.leading, 8)

                                    Text(entry.date)
                                        .font(.system(size: 9))
                                        .foregroundStyle(.tertiary)
                                        .frame(width: 70, alignment: .leading)
                                        .padding(.leading, 8)

                                    Divider()
                                        .frame(height: 18)
                                        .padding(.horizontal, 8)

                                    Text("\(entry.lineNumber)")
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 25, alignment: .trailing)
                                        .padding(.trailing, 8)

                                    Text(entry.code)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.vertical, 2)
                                .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedLineIndex = index
                                }
                                .contextMenu {
                                    Button("Copy Blame Info") {
                                        let pb = NSPasteboard.general
                                        pb.clearContents()
                                        pb.setString("Commit: \(entry.sha) • Author: \(entry.author) • Date: \(entry.date)", forType: .string)
                                    }
                                    Button("Jump to Commit Inspector") {
                                    }
                                }
                            }
                        }
                    }
                    .background(Color.black.opacity(0.85))
                }
            } else {
                ContentUnavailableView(
                    "No File Selected",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Select any source code file in the repository tree to analyze line-by-line annotations.")
                )
            }
        }
        .popover(isPresented: $isShowingPopover) {
            VStack(alignment: .leading, spacing: 10) {
                Text("COMMIT REFERENCE DETAILS")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)

                if let details = hoverCommitDetails {
                    Text(details)
                        .font(.system(size: 11, design: .monospaced))
                } else {
                    ProgressView().controlSize(.small)
                }

                HStack {
                    Spacer()
                    Button("Done") { isShowingPopover = false }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
            .padding()
            .frame(width: 320)
        }
    }

    private var processedBlameLines: [BlameLineEntry] {
        var list = blameLines

        if !blameSearchText.isEmpty {
            list = list.filter {
                $0.code.localizedCaseInsensitiveContains(blameSearchText) ||
                $0.sha.localizedCaseInsensitiveContains(blameSearchText)
            }
        }

        if !filterAuthor.isEmpty {
            list = list.filter { $0.author.localizedCaseInsensitiveContains(filterAuthor) }
        }

        return list
    }

    private func loadRepositoryFiles() {
        guard let url = gitViewModel.repositoryURL else { return }
        do {
            let keys: [URLResourceKey] = [.isRegularFileKey]
            let enumerator = FileManager.default.enumerator(
                at: url,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            )

            var urls: [URL] = []
            var count = 0
            while let fileURL = enumerator?.nextObject() as? URL {
                if count > 200 { break }

                let pathStr = fileURL.path
                if pathStr.contains("/.build") || pathStr.contains("/.git") || pathStr.contains("/.spaces") || pathStr.contains("/DerivedData") || pathStr.contains("/node_modules") {
                    enumerator?.skipDescendants()
                    continue
                }

                let resourceValues = try fileURL.resourceValues(forKeys: Set(keys))
                if resourceValues.isRegularFile ?? false {
                    urls.append(fileURL)
                    count += 1
                }
            }
            self.fileList = urls
            self.selectedFile = urls.first
            if let first = urls.first {
                loadBlameInfo(for: first)
            }
        } catch {
            logger.error("Repository load files error: \(error.localizedDescription)")
        }
    }

    private static func formatBlameDate(_ timestamp: Int64) -> String {
        guard timestamp > 0 else { return "unknown" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: Date(timeIntervalSince1970: TimeInterval(timestamp)), relativeTo: Date())
    }

    private static func parsePorcelainBlame(_ output: String) -> [BlameLineEntry] {
        var entries: [BlameLineEntry] = []
        var sha = ""
        var author = "unknown"
        var timestamp: Int64 = 0
        var lineNumber = 0
        for line in output.components(separatedBy: .newlines) {
            if line.hasPrefix("\t") {
                lineNumber += 1
                entries.append(BlameLineEntry(
                    lineNumber: lineNumber,
                    sha: sha.isEmpty ? "unknown" : sha,
                    author: author,
                    date: formatBlameDate(timestamp),
                    code: String(line.dropFirst())
                ))
                sha = ""
                author = "unknown"
                timestamp = 0
            } else if line.hasPrefix("author ") {
                author = String(line.dropFirst("author ".count))
            } else if line.hasPrefix("author-time ") {
                timestamp = Int64(line.dropFirst("author-time ".count)) ?? 0
            } else if sha.isEmpty {
                let head = line.components(separatedBy: " ")
                if head.count >= 4, head[0].count == 40, head[0].allSatisfy({ $0.isHexDigit }) {
                    sha = head[0]
                }
            }
        }
        return entries
    }

    private func loadBlameInfo(for fileURL: URL) {
        guard let proj = gitViewModel.repositoryURL else { return }
        isLoadingBlame = true
        blameLines = []
        blameError = nil

        Task {
            do {
                if gitViewModel.usesSpaces {
                    let lines = try await SpacesService.shared.blame(fileURL: fileURL, repositoryURL: proj)
                    self.blameLines = lines.enumerated().map { index, blame in
                        BlameLineEntry(
                            lineNumber: index + 1,
                            sha: blame.commit.hex,
                            author: blame.author.isEmpty ? "unknown" : blame.author,
                            date: Self.formatBlameDate(blame.timestamp),
                            code: blame.line
                        )
                    }
                } else {
                    let relPath = fileURL.path.replacingOccurrences(of: proj.path + "/", with: "")
                    let gitBinary = URL(fileURLWithPath: AppSettings.shared.gitPath.isEmpty ? "/usr/bin/git" : AppSettings.shared.gitPath)

                    let result = try await ProcessRunnerTool.shared.run(
                        executableURL: gitBinary,
                        arguments: ["blame", "--line-porcelain", relPath],
                        workingDirectory: proj
                    )

                    guard result.exitCode == 0 else {
                        throw AppError.gitError(result.stderr)
                    }
                    self.blameLines = Self.parsePorcelainBlame(result.stdout)
                }
            } catch {
                logger.error("Blame native failed: \(error.localizedDescription)")
                self.blameLines = []
                self.blameError = error.localizedDescription
            }
            isLoadingBlame = false
        }
    }

    private func triggerCommitPopover(sha: String) {
        hoverCommitSHA = sha
        isShowingPopover = true
        hoverCommitDetails = nil
        guard let repoURL = gitViewModel.repositoryURL else {
            hoverCommitDetails = "Commit details unavailable: no repository."
            return
        }
        Task {
            do {
                if gitViewModel.usesSpaces {
                    let result = try await SpacesService.shared.showCommit(sha: sha, repositoryURL: repoURL)
                    let info = result.info
                    self.hoverCommitDetails = "SHA: \(info.oid.hex)\nAuthor: \(info.author.name) <\(info.author.email)>\nDate: \(Self.formatBlameDate(info.timestamp))\nAdded: \(result.diffStat.added) Removed: \(result.diffStat.removed) Files: \(result.diffStat.files)\n\n\(info.message)"
                } else {
                    let gitBinary = URL(fileURLWithPath: AppSettings.shared.gitPath.isEmpty ? "/usr/bin/git" : AppSettings.shared.gitPath)
                    let result = try await ProcessRunnerTool.shared.run(
                        executableURL: gitBinary,
                        arguments: ["show", "-s", "--format=%H%n%an <%ae>%n%ad%n%B", "--date=iso", sha],
                        workingDirectory: repoURL
                    )
                    guard result.exitCode == 0 else {
                        throw AppError.gitError(result.stderr)
                    }
                    self.hoverCommitDetails = result.stdout
                }
            } catch {
                self.hoverCommitDetails = "Commit details unavailable: \(error.localizedDescription)"
            }
        }
    }
}
