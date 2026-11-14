import SwiftUI
import YcodeIDECore

public struct NSCommitView: View {
    @State private var commitType = "feat"
    @State private var scope = ""
    @State private var commitTitle = ""
    @State private var bodyText = ""
    @State private var amend = false
    @State private var isSigning = false
    @State private var authorInfo = ""
    @State private var stagedFilesCount = 0
    @State private var showDiffSheet = false
    @State private var successMsg = ""
    @State private var errorMsg = ""
    @State private var isLoading = false

    private let commitTypes = [
        "feat": "Feature",
        "fix": "Bug Fix",
        "docs": "Docs",
        "refactor": "Refactor",
        "perf": "Performance",
        "test": "Tests",
        "chore": "Chore"
    ]

    public init() {}

    public var body: some View {
        Group {
            if let activeProject = ProjectSessionStore.shared.activeProject {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("Git Commit (⌥⌘C)", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .foregroundStyle(Color.accentColor)
                        Spacer()
                        if !authorInfo.isEmpty {
                            Text(authorInfo)
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                    }

                    
                    HStack(spacing: 4) {
                        Text("Type")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                            .frame(width: 32, alignment: .leading)
                        Picker("", selection: $commitType) {
                            ForEach(commitTypes.keys.sorted(), id: \.self) { key in
                                Text("\(key): \(commitTypes[key] ?? "")").tag(key)
                            }
                        }
                        .pickerStyle(.menu)
                        .controlSize(.small)
                    }

                    
                    HStack(spacing: 6) {
                        TextField("scope", text: $scope)
                            .textFieldStyle(.roundedBorder)
                            .controlSize(.small)
                            .frame(width: 70)
                        TextField("Summary...", text: $commitTitle)
                            .textFieldStyle(.roundedBorder)
                            .controlSize(.small)
                    }

                    
                    HStack(spacing: 12) {
                        Toggle("Amend", isOn: $amend)
                            .toggleStyle(.checkbox)
                            .font(.caption2)

                        Toggle("Sign (-S)", isOn: $isSigning)
                            .toggleStyle(.checkbox)
                            .font(.caption2)

                        Spacer()

                        Button("Full Sheet…") {
                            showDiffSheet = true
                        }
                        .buttonStyle(.plain)
                        .font(.caption2)
                        .foregroundStyle(Color.accentColor)
                    }

                    if isLoading {
                        ProgressView()
                            .progressViewStyle(.linear)
                            .padding(.vertical, 2)
                    }

                    if !successMsg.isEmpty {
                        Text(successMsg)
                            .font(.caption2)
                            .foregroundStyle(Color.accentColor)
                    }

                    if !errorMsg.isEmpty {
                        NSGitErrorView(message: errorMsg)
                    }

                    
                    Button {
                        performCommit()
                    } label: {
                        HStack {
                            Spacer()
                            Label(amend ? "Amend & Commit" : "Commit Changes", systemImage: "checkmark.circle.fill")
                                .fontWeight(.bold)
                            Spacer()
                        }
                        .padding(.vertical, 6)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .disabled(commitTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                }
                .onAppear {
                    loadDetails()
                }
                .sheet(isPresented: $showDiffSheet) {
                    ModernGitCommitView(
                        repository: GitRepository(containing: activeProject.directoryURL),
                        onDismiss: { showDiffSheet = false },
                        onCommitSuccess: {
                            showDiffSheet = false
                            successMsg = "Committed successfully!"
                            commitTitle = ""
                        }
                    )
                }
            } else {
                NoActiveProjectView(title: "Commit")
            }
        }
        .padding()
        .liquidGlass(style: .sheet, cornerRadius: 12)
        .frame(width: 300)
    }

    private func loadDetails() {
        guard let project = ProjectSessionStore.shared.activeProject,
              let repo = GitRepository(containing: project.directoryURL) else { return }
        let auth = repo.author()
        if !auth.name.isEmpty {
            authorInfo = "\(auth.name)"
        }
        if let status = try? repo.status() {
            stagedFilesCount = status.count
        }
    }

    private func performCommit() {
        let title = commitTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        let fullMsg: String
        if scope.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            fullMsg = "\(commitType): \(title)"
        } else {
            fullMsg = "\(commitType)(\(scope.trimmingCharacters(in: .whitespacesAndNewlines))): \(title)"
        }

        isLoading = true
        successMsg = ""
        errorMsg = ""

        Task {
            do {
                try await GitMenuBarCommandExecutor.runGit(args: ["add", "-A"])
                var args = ["commit", "-m", fullMsg]
                if amend { args.append("--amend") }
                if isSigning { args.append("-S") }
                try await GitMenuBarCommandExecutor.runGit(args: args)
                successMsg = "Successfully committed: '\(title)'"
                commitTitle = ""
                amend = false
            } catch {
                errorMsg = error.localizedDescription
            }
            isLoading = false
        }
    }
}
