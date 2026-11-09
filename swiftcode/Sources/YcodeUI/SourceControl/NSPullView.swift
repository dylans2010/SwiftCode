import SwiftUI
import YcodeIDECore

public struct NSPullView: View {
    @State private var remotes: [String] = ["origin"]
    @State private var selectedRemote = "origin"
    @State private var branches: [String] = ["main"]
    @State private var selectedBranch = "main"
    @State private var useRebase = false
    @State private var incomingCount = 0
    @State private var showFullSheet = false
    @State private var successMsg = ""
    @State private var errorMsg = ""
    @State private var isLoading = false

    public init() {}

    public var body: some View {
        Group {
            if let activeProject = ProjectSessionStore.shared.activeProject {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("Git Pull (⌥⌘X)", systemImage: "arrow.down.circle.fill")
                            .font(.headline)
                            .foregroundStyle(.cyan)
                        Spacer()
                        Button("Full View…") {
                            showFullSheet = true
                        }
                        .buttonStyle(.plain)
                        .font(.caption2)
                        .foregroundStyle(.cyan)
                    }

                    
                    HStack(spacing: 8) {
                        Picker("Remote", selection: $selectedRemote) {
                            ForEach(remotes, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .controlSize(.small)

                        Picker("Branch", selection: $selectedBranch) {
                            ForEach(branches, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .controlSize(.small)
                    }

                    
                    HStack {
                        if incomingCount == 0 {
                            Label("Up to date with remote", systemImage: "checkmark.circle")
                                .font(.caption2.bold())
                                .foregroundStyle(.green)
                        } else {
                            Label("\(incomingCount) incoming commit\(incomingCount == 1 ? "" : "s")", systemImage: "arrow.down")
                                .font(.caption2.bold())
                                .foregroundStyle(.cyan)
                        }
                        Spacer()
                    }

                    Toggle("Rebase local commits", isOn: $useRebase)
                        .toggleStyle(.checkbox)
                        .font(.caption2)

                    if isLoading {
                        ProgressView()
                            .progressViewStyle(.linear)
                            .padding(.vertical, 2)
                    }

                    if !successMsg.isEmpty {
                        Text(successMsg)
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }

                    if !errorMsg.isEmpty {
                        NSGitErrorView(message: errorMsg)
                    }

                    HStack {
                        Button {
                            performPull()
                        } label: {
                            HStack {
                                Spacer()
                                Label(incomingCount == 0 ? "Pull / Re-sync" : "Pull \(incomingCount) Commit\(incomingCount == 1 ? "" : "s")", systemImage: "arrow.down.circle.fill")
                                    .fontWeight(.bold)
                                Spacer()
                            }
                            .padding(.vertical, 6)
                            .background(Color.cyan)
                            .foregroundColor(.black)
                            .cornerRadius(6)
                            .shadow(color: Color.cyan.opacity(0.4), radius: 6, x: 0, y: 1)
                        }
                        .buttonStyle(.plain)
                        .disabled(isLoading)
                    }
                }
                .onAppear {
                    loadData()
                }
                .sheet(isPresented: $showFullSheet) {
                    ModernGitPullView(
                        repository: GitRepository(containing: activeProject.directoryURL),
                        onDismiss: { showFullSheet = false },
                        onPullSuccess: {
                            showFullSheet = false
                            successMsg = "Pulled successfully!"
                            loadData()
                        }
                    )
                }
            } else {
                NoActiveProjectView(title: "Pull")
            }
        }
        .padding()
        .liquidGlass(style: .sheet, cornerRadius: 12)
        .frame(width: 300)
    }

    private func loadData() {
        guard let project = ProjectSessionStore.shared.activeProject,
              let repo = GitRepository(containing: project.directoryURL) else { return }

        let remList = (try? repo.remotes())?.map(\.name) ?? []
        self.remotes = remList.isEmpty ? ["origin"] : remList
        self.selectedRemote = self.remotes.first ?? "origin"

        let currBranch = repo.currentBranch() ?? "main"
        let branchList = (try? repo.branches())?.map(\.name) ?? []
        self.branches = branchList.isEmpty ? [currBranch] : branchList
        self.selectedBranch = currBranch

        let remote = self.selectedRemote
        Task {
            _ = await Task.detached {
                _ = try? repo.runGit(["fetch", remote])
            }.value

            if let (_, behind) = repo.aheadBehind(currBranch) {
                self.incomingCount = behind
            } else {
                let out = (try? repo.runGit(["rev-list", "--count", "HEAD..@{u}"])) ?? "0"
                self.incomingCount = Int(out.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            }
        }
    }

    private func performPull() {
        isLoading = true
        successMsg = ""
        errorMsg = ""
        let rebase = useRebase
        let rem = selectedRemote
        let br = selectedBranch

        Task {
            do {
                var args = ["pull", rem, br]
                if rebase { args.append("--rebase") }
                try await GitMenuBarCommandExecutor.runGit(args: args)
                successMsg = "Successfully pulled from '\(rem)/\(br)'."
                incomingCount = 0
            } catch {
                errorMsg = error.localizedDescription
            }
            isLoading = false
        }
    }
}
