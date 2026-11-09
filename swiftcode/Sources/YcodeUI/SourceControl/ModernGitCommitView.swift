import SwiftUI
import YcodeIDECore

public struct ModernGitCommitView: View {
    public let repository: GitRepository?
    public var onDismiss: (() -> Void)?
    public var onCommitSuccess: (() -> Void)?

    @State private var commitType = "feat"
    @State private var scope = ""
    @State private var title = ""
    @State private var bodyText = ""
    @State private var isSigning = false
    @State private var isAmending = false
    @State private var noVerify = false
    @State private var authorName = ""
    @State private var authorEmail = ""
    @State private var files: [FileRowItem] = []
    @State private var selectedFileForDiff: FileRowItem?
    @State private var diffContent: String = ""
    @State private var isCommitting = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    public struct FileRowItem: Identifiable, Equatable, Hashable {
        public var id: String { path }
        public var path: String
        public var status: GitRepository.FileStatus
        public var isStaged: Bool
    }

    private let conventionalTypes: [(key: String, title: String, color: Color, desc: String)] = [
        ("feat", "feat", .blue, "New feature"),
        ("fix", "fix", .red, "Bug fix"),
        ("docs", "docs", .purple, "Documentation only"),
        ("style", "style", .pink, "Formatting, whitespace"),
        ("refactor", "refactor", .orange, "Code restructuring"),
        ("perf", "perf", .green, "Performance improvement"),
        ("test", "test", .yellow, "Adding or fixing tests"),
        ("chore", "chore", .secondary, "Build tasks, tooling"),
        ("ci", "ci", .teal, "CI/CD configurations")
    ]

    public init(
        repository: GitRepository? = nil,
        onDismiss: (() -> Void)? = nil,
        onCommitSuccess: (() -> Void)? = nil
    ) {
        self.repository = repository
        self.onDismiss = onDismiss
        self.onCommitSuccess = onCommitSuccess
    }

    public var body: some View {
        VStack(spacing: 0) {
            
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Source Control: Commit")
                        .font(.headline.bold())
                    if !authorName.isEmpty {
                        Text("Author: \(authorName) <\(authorEmail)>")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button {
                    onDismiss?()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor).opacity(0.8))

            Divider()

            
            HSplitView {
                
                VStack(spacing: 0) {
                    HStack {
                        Text("Staged Files (\(stagedCount)/\(files.count))")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Stage All") {
                            for i in files.indices { files[i].isStaged = true }
                        }
                        .buttonStyle(.plain)
                        .font(.caption2)
                        .foregroundStyle(.blue)

                        Text("•").foregroundStyle(.tertiary)

                        Button("Unstage All") {
                            for i in files.indices { files[i].isStaged = false }
                        }
                        .buttonStyle(.plain)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(NSColor.windowBackgroundColor))

                    Divider()

                    List(selection: $selectedFileForDiff) {
                        ForEach($files) { $item in
                            HStack(spacing: 6) {
                                Toggle("", isOn: $item.isStaged)
                                    .toggleStyle(.checkbox)
                                    .labelsHidden()

                                Text(statusBadge(item.status))
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(statusColor(item.status).opacity(0.15))
                                    .foregroundStyle(statusColor(item.status))
                                    .cornerRadius(4)

                                Image(systemName: CodeSearchEngine.iconForFileName(item.path))
                                    .foregroundStyle(.secondary)
                                    .font(.caption)

                                Text(URL(fileURLWithPath: item.path).lastPathComponent)
                                    .font(.system(.caption, design: .monospaced))
                                    .lineLimit(1)

                                Spacer()

                                Text((item.path as NSString).deletingLastPathComponent)
                                    .font(.system(size: 9))
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                                    .truncationMode(.head)
                            }
                            .tag(item)
                            .padding(.vertical, 2)
                        }
                    }
                    .frame(height: 180)

                    Divider()

                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Diff Preview: \(selectedFileForDiff?.path ?? "None selected")")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 6)

                        ScrollView {
                            if diffContent.isEmpty {
                                Text(selectedFileForDiff == nil ? "Select a file to inspect diff" : "No differences detected.")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(8)
                            } else {
                                VStack(alignment: .leading, spacing: 2) {
                                    ForEach(Array(diffContent.components(separatedBy: .newlines).enumerated()), id: \.offset) { _, line in
                                        Text(line)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(diffLineColor(line))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                                .padding(8)
                            }
                        }
                        .background(Color(NSColor.textBackgroundColor).opacity(0.5))
                        .cornerRadius(6)
                        .padding(8)
                    }
                }
                .frame(minWidth: 320)

                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Conventional Commit Type")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(conventionalTypes, id: \.key) { cType in
                                Button {
                                    commitType = cType.key
                                } label: {
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(cType.color)
                                            .frame(width: 6, height: 6)
                                        Text(cType.title)
                                            .font(.caption.bold())
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(commitType == cType.key ? cType.color.opacity(0.2) : Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(commitType == cType.key ? cType.color : Color.secondary.opacity(0.2), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                                .help(cType.desc)
                            }
                        }
                    }

                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Scope (optional)")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            TextField("e.g. search", text: $scope)
                                .textFieldStyle(.roundedBorder)
                        }
                        .frame(width: 120)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Summary Title")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            TextField("Concise summary of changes", text: $title)
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Detailed Description (optional)")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        TextEditor(text: $bodyText)
                            .font(.system(.caption, design: .monospaced))
                            .frame(height: 120)
                            .padding(4)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                    }

                    
                    HStack(spacing: 16) {
                        Toggle("Sign Commit (-S)", isOn: $isSigning)
                            .toggleStyle(.checkbox)
                            .font(.caption)

                        Toggle("Amend Last Commit", isOn: $isAmending)
                            .toggleStyle(.checkbox)
                            .font(.caption)

                        Toggle("Bypass Hooks (--no-verify)", isOn: $noVerify)
                            .toggleStyle(.checkbox)
                            .font(.caption)
                    }

                    if let err = errorMessage {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    if let succ = successMessage {
                        Text(succ)
                            .font(.caption)
                            .foregroundStyle(.green)
                    }

                    Spacer()

                    
                    HStack {
                        Button("Cancel") {
                            onDismiss?()
                        }
                        .keyboardShortcut(.cancelAction)

                        Spacer()

                        Button {
                            performCommit()
                        } label: {
                            HStack(spacing: 8) {
                                if isCommitting {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                }
                                Text(isAmending ? "Amend & Commit" : "Commit Staged (\(stagedCount))")
                                    .fontWeight(.bold)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                LinearGradient(
                                    colors: [Color.green, Color.teal],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .shadow(color: Color.green.opacity(0.6), radius: 8, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || stagedCount == 0 || isCommitting)
                        .keyboardShortcut(.defaultAction)
                    }
                }
                .padding()
                .frame(minWidth: 380)
            }
        }
        .frame(minWidth: 780, minHeight: 520)
        .onAppear {
            loadRepositoryInfo()
        }
        .onChange(of: selectedFileForDiff) { _, newValue in
            loadDiff(for: newValue)
        }
    }

    private var stagedCount: Int {
        files.filter(\.isStaged).count
    }

    private func assembledMessage() -> String {
        let prefix = scope.isEmpty ? commitType : "\(commitType)(\(scope))"
        let header = "\(prefix): \(title.trimmingCharacters(in: .whitespacesAndNewlines))"
        let trimmedBody = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedBody.isEmpty {
            return header
        } else {
            return "\(header)\n\n\(trimmedBody)"
        }
    }

    private func loadRepositoryInfo() {
        guard let repo = repository ?? ProjectSessionStore.shared.activeProject.flatMap({ GitRepository(containing: $0.directoryURL) }) else { return }

        let auth = repo.author()
        authorName = auth.name
        authorEmail = auth.email

        if let status = try? repo.status() {
            files = status.keys.sorted().map { path in
                FileRowItem(path: path, status: status[path]!, isStaged: true)
            }
            if let first = files.first {
                selectedFileForDiff = first
                loadDiff(for: first)
            }
        }
    }

    private func loadDiff(for item: FileRowItem?) {
        guard let item = item,
              let repo = repository ?? ProjectSessionStore.shared.activeProject.flatMap({ GitRepository(containing: $0.directoryURL) }) else {
            diffContent = ""
            return
        }
        diffContent = repo.diff(of: item.path, scope: .all)
    }

    private func performCommit() {
        guard let repo = repository ?? ProjectSessionStore.shared.activeProject.flatMap({ GitRepository(containing: $0.directoryURL) }) else {
            errorMessage = "No active Git repository detected."
            return
        }

        let stagedFiles = files.filter(\.isStaged).map(\.path)
        guard !stagedFiles.isEmpty else {
            errorMessage = "No files selected for commit."
            return
        }

        let msg = assembledMessage()
        isCommitting = true
        errorMessage = nil
        successMessage = nil

        let sign = isSigning
        let amend = isAmending
        let skipVerify = noVerify

        Task {
            do {
                _ = try await Task.detached {
                    try repo.stage(stagedFiles)
                    var args = ["commit", "-m", msg]
                    if sign { args.append("-S") }
                    if amend { args.append("--amend") }
                    if skipVerify { args.append("--no-verify") }
                    _ = try repo.runGit(args)
                    return true
                }.value

                successMessage = "Committed successfully!"
                try? await Task.sleep(nanoseconds: 600_000_000)
                onCommitSuccess?()
                onDismiss?()
            } catch {
                errorMessage = error.localizedDescription
            }
            isCommitting = false
        }
    }

    private func statusBadge(_ s: GitRepository.FileStatus) -> String {
        switch s {
        case .added: return "A"
        case .modified: return "M"
        case .deleted: return "D"
        case .conflicted: return "C"
        case .untracked: return "U"
        case .renamed: return "R"
        }
    }

    private func statusColor(_ s: GitRepository.FileStatus) -> Color {
        switch s {
        case .added: return .green
        case .modified: return .blue
        case .deleted: return .red
        case .conflicted: return .purple
        case .untracked: return .orange
        case .renamed: return .blue
        }
    }

    private func diffLineColor(_ line: String) -> Color {
        if line.hasPrefix("+") { return .green }
        if line.hasPrefix("-") { return .red }
        if line.hasPrefix("@") { return .cyan }
        return .primary
    }
}
