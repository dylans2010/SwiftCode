import SwiftUI
import YcodeIDECore

public struct ModernGitPullView: View {
    public let repository: GitRepository?
    public var onDismiss: (() -> Void)?
    public var onPullSuccess: (() -> Void)?

    @State private var remotes: [String] = ["origin"]
    @State private var selectedRemote = "origin"
    @State private var branches: [String] = ["main"]
    @State private var selectedBranch = "main"
    @State private var useRebase = false
    @State private var incomingCommits: [CommitInfo] = []
    @State private var isPulling = false
    @State private var isFetching = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    public struct CommitInfo: Identifiable, Equatable, Sendable {
        public var id: String { hash }
        public var hash: String
        public var shortHash: String { String(hash.prefix(7)) }
        public var subject: String
        public var author: String
        public var dateString: String
    }

    public init(
        repository: GitRepository? = nil,
        onDismiss: (() -> Void)? = nil,
        onPullSuccess: (() -> Void)? = nil
    ) {
        self.repository = repository
        self.onDismiss = onDismiss
        self.onPullSuccess = onPullSuccess
    }

    public var body: some View {
        VStack(spacing: 0) {
            
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.cyan)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Source Control: Pull")
                        .font(.headline.bold())
                    Text("Fetch and integrate changes from remote repository")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
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

            VStack(alignment: .leading, spacing: 14) {
                
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Remote")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Picker("", selection: $selectedRemote) {
                            ForEach(remotes, id: \.self) { r in
                                Text(r).tag(r)
                            }
                        }
                        .pickerStyle(.menu)
                        .disabled(isPulling || remotes.isEmpty)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Branch")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Picker("", selection: $selectedBranch) {
                            ForEach(branches, id: \.self) { b in
                                Text(b).tag(b)
                            }
                        }
                        .pickerStyle(.menu)
                        .disabled(isPulling || branches.isEmpty)
                    }

                    VStack {
                        Spacer()
                        Button {
                            refreshRemote()
                        } label: {
                            Label("Fetch Latest", systemImage: "arrow.clockwise")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(isFetching || isPulling)
                    }
                }

                
                Toggle("Rebase local commits instead of merge (--rebase)", isOn: $useRebase)
                    .toggleStyle(.checkbox)
                    .font(.caption)
                    .disabled(isPulling)

                Divider()

                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Incoming Commits (\(incomingCommits.count))")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Spacer()
                        if isFetching {
                            ProgressView().controlSize(.small)
                        } else if incomingCommits.isEmpty {
                            Label("Repository is up to date", systemImage: "checkmark.circle")
                                .font(.caption.bold())
                                .foregroundStyle(.green)
                        }
                    }

                    if incomingCommits.isEmpty && !isFetching {
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.largeTitle)
                                .foregroundStyle(.green.opacity(0.8))
                            Text("Your local branch is completely up to date.")
                                .font(.subheadline.bold())
                            Text("No incoming commits waiting from '\(selectedRemote)/\(selectedBranch)'.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(8)
                    } else {
                        List(incomingCommits) { commit in
                            HStack(spacing: 8) {
                                Text(commit.shortHash)
                                    .font(.system(.caption, design: .monospaced).bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.cyan.opacity(0.15))
                                    .foregroundStyle(.cyan)
                                    .cornerRadius(4)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(commit.subject)
                                        .font(.subheadline)
                                        .lineLimit(1)
                                    HStack(spacing: 6) {
                                        Text(commit.author)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        Text("•")
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                        Text(commit.dateString)
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                        .frame(height: 160)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                        .cornerRadius(6)
                    }
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
                        performPull()
                    } label: {
                        HStack(spacing: 6) {
                            if isPulling {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: "arrow.down.circle.fill")
                            }
                            Text(isPulling ? "Pulling…" : (incomingCommits.isEmpty ? "Pull / Re-sync" : "Pull \(incomingCommits.count) Commit\(incomingCommits.count == 1 ? "" : "s")"))
                                .fontWeight(.bold)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.cyan)
                        .foregroundColor(.black)
                        .cornerRadius(8)
                        .shadow(color: Color.cyan.opacity(0.4), radius: 6, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                    .disabled(isPulling)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding()
        }
        .frame(minWidth: 540, minHeight: 440)
        .onAppear {
            loadRepoData()
        }
    }

    private func loadRepoData() {
        guard let repo = repository ?? ProjectSessionStore.shared.activeProject.flatMap({ GitRepository(containing: $0.directoryURL) }) else { return }

        let remList = (try? repo.remotes())?.map(\.name) ?? []
        self.remotes = remList.isEmpty ? ["origin"] : remList
        self.selectedRemote = self.remotes.first ?? "origin"

        let currBranch = repo.currentBranch() ?? "main"
        let branchList = (try? repo.branches())?.map(\.name) ?? []
        self.branches = branchList.isEmpty ? [currBranch] : branchList
        self.selectedBranch = currBranch

        refreshRemote()
    }

    private func refreshRemote() {
        guard let repo = repository ?? ProjectSessionStore.shared.activeProject.flatMap({ GitRepository(containing: $0.directoryURL) }) else { return }
        isFetching = true
        errorMessage = nil

        let rem = selectedRemote
        let br = selectedBranch

        Task {
            _ = try? await Task.detached {
                _ = try? repo.runGit(["fetch", rem])
            }.value

            let commits = await Task.detached { () -> [CommitInfo] in
                var spec = "HEAD..@{u}"
                if (try? repo.runGit(["rev-parse", "--verify", "@{u}"])) == nil {
                    spec = "HEAD..\(rem)/\(br)"
                }
                guard let output = try? repo.runGit(["log", spec, "--pretty=format:%H%x1f%s%x1f%an%x1f%cr", "-n", "30"]) else {
                    return []
                }
                return output.components(separatedBy: "\n").compactMap { line -> CommitInfo? in
                    let parts = line.components(separatedBy: "\u{1f}")
                    guard parts.count >= 4 else { return nil }
                    return CommitInfo(hash: parts[0], subject: parts[1], author: parts[2], dateString: parts[3])
                }
            }.value

            self.incomingCommits = commits
            self.isFetching = false
        }
    }

    private func performPull() {
        guard let repo = repository ?? ProjectSessionStore.shared.activeProject.flatMap({ GitRepository(containing: $0.directoryURL) }) else {
            errorMessage = "No active Git repository detected."
            return
        }

        isPulling = true
        errorMessage = nil
        successMessage = nil

        let rem = selectedRemote
        let br = selectedBranch
        let rebaseFlag = useRebase

        Task {
            do {
                _ = try await Task.detached {
                    var args = ["pull", rem, br]
                    if rebaseFlag {
                        args.append("--rebase")
                    }
                    _ = try repo.runGit(args)
                    return true
                }.value

                successMessage = "Successfully pulled and updated from '\(rem)/\(br)'!"
                try? await Task.sleep(nanoseconds: 600_000_000)
                onPullSuccess?()
                onDismiss?()
            } catch {
                errorMessage = error.localizedDescription
            }
            isPulling = false
        }
    }
}
