import SwiftUI
import YcodeIDECore

public struct ModernGitPushView: View {
    public let repository: GitRepository?
    public var onDismiss: (() -> Void)?
    public var onPushSuccess: (() -> Void)?

    @State private var remotes: [String] = ["origin"]
    @State private var selectedRemote = "origin"
    @State private var branches: [String] = ["main"]
    @State private var selectedBranch = "main"
    @State private var forcePush = false
    @State private var showForcePushWarning = false
    @State private var outgoingCommits: [CommitInfo] = []
    @State private var isPushing = false
    @State private var isLoading = false
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
        onPushSuccess: (() -> Void)? = nil
    ) {
        self.repository = repository
        self.onDismiss = onDismiss
        self.onPushSuccess = onPushSuccess
    }

    public var body: some View {
        VStack(spacing: 0) {
            
            HStack {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Source Control: Push")
                        .font(.headline.bold())
                    Text("Publish local commits to remote repository")
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
                        .disabled(isPushing || remotes.isEmpty)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Target Branch")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Picker("", selection: $selectedBranch) {
                            ForEach(branches, id: \.self) { b in
                                Text(b).tag(b)
                            }
                        }
                        .pickerStyle(.menu)
                        .disabled(isPushing || branches.isEmpty)
                    }
                }

                
                HStack {
                    Toggle("Force Push (--force-with-lease)", isOn: Binding(
                        get: { forcePush },
                        set: { val in
                            if val {
                                showForcePushWarning = true
                            } else {
                                forcePush = false
                            }
                        }
                    ))
                    .toggleStyle(.checkbox)
                    .font(.caption)
                    .foregroundStyle(forcePush ? .red : .primary)

                    if forcePush {
                        Text("⚠️ Overwrite remote history")
                            .font(.caption2.bold())
                            .foregroundStyle(.red)
                    }
                }

                Divider()

                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Pending Outgoing Commits (\(outgoingCommits.count))")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Spacer()
                        if isLoading {
                            ProgressView().controlSize(.small)
                        } else if outgoingCommits.isEmpty {
                            Label("Already up to date with remote", systemImage: "checkmark.circle")
                                .font(.caption.bold())
                                .foregroundStyle(.green)
                        }
                    }

                    if outgoingCommits.isEmpty && !isLoading {
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.largeTitle)
                                .foregroundStyle(.green.opacity(0.8))
                            Text("No outgoing commits to push.")
                                .font(.subheadline.bold())
                            Text("Your local branch '\(selectedBranch)' is already synchronized with '\(selectedRemote)/\(selectedBranch)'.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(8)
                    } else {
                        List(outgoingCommits) { commit in
                            HStack(spacing: 8) {
                                Text(commit.shortHash)
                                    .font(.system(.caption, design: .monospaced).bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.15))
                                    .foregroundStyle(.blue)
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
                        performPush()
                    } label: {
                        HStack(spacing: 6) {
                            if isPushing {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: "arrow.up.circle.fill")
                            }
                            Text(isPushing ? "Pushing…" : (outgoingCommits.isEmpty ? "Push Anyway" : "Push \(outgoingCommits.count) Commit\(outgoingCommits.count == 1 ? "" : "s")"))
                                .fontWeight(.bold)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(forcePush ? Color.red : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .shadow(color: (forcePush ? Color.red : Color.blue).opacity(0.5), radius: 6, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                    .disabled(isPushing || (outgoingCommits.isEmpty && !forcePush))
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding()
        }
        .frame(minWidth: 540, minHeight: 440)
        .alert("Confirm Force Push", isPresented: $showForcePushWarning) {
            Button("Enable Force Push", role: .destructive) {
                forcePush = true
            }
            Button("Cancel", role: .cancel) {
                forcePush = false
            }
        } message: {
            Text("Force pushing will overwrite remote commit history on '\(selectedRemote)/\(selectedBranch)'. Any commits made by collaborators not present locally will be lost. Proceed with caution.")
        }
        .onAppear {
            loadRepoData()
        }
    }

    private func loadRepoData() {
        guard let repo = repository ?? ProjectSessionStore.shared.activeProject.flatMap({ GitRepository(containing: $0.directoryURL) }) else { return }

        isLoading = true
        Task {
            do {
                let remList = (try? repo.remotes())?.map(\.name) ?? []
                self.remotes = remList.isEmpty ? ["origin"] : remList
                self.selectedRemote = self.remotes.first ?? "origin"

                let currBranch = repo.currentBranch() ?? "main"
                let branchList = (try? repo.branches())?.map(\.name) ?? []
                self.branches = branchList.isEmpty ? [currBranch] : branchList
                self.selectedBranch = currBranch

                await loadOutgoingCommits(repo: repo, remote: self.selectedRemote, branch: currBranch)
            }
            isLoading = false
        }
    }

    private func loadOutgoingCommits(repo: GitRepository, remote: String, branch: String) async {
        let commits = await Task.detached { () -> [CommitInfo] in
            
            var spec = "@{u}..HEAD"
            if (try? repo.runGit(["rev-parse", "--verify", "@{u}"])) == nil {
                spec = "\(remote)/\(branch)..HEAD"
                if (try? repo.runGit(["rev-parse", "--verify", "\(remote)/\(branch)"])) == nil {
                    
                    spec = "\(branch)"
                }
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

        self.outgoingCommits = commits
    }

    private func performPush() {
        guard let repo = repository ?? ProjectSessionStore.shared.activeProject.flatMap({ GitRepository(containing: $0.directoryURL) }) else {
            errorMessage = "No active Git repository detected."
            return
        }

        isPushing = true
        errorMessage = nil
        successMessage = nil

        let rem = selectedRemote
        let br = selectedBranch
        let isForce = forcePush

        Task {
            do {
                _ = try await Task.detached {
                    var args = ["push", rem, br]
                    if isForce {
                        args.append("--force-with-lease")
                    }
                    _ = try repo.runGit(args)
                    return true
                }.value

                successMessage = "Pushed successfully to '\(rem)/\(br)'!"
                try? await Task.sleep(nanoseconds: 600_000_000)
                onPushSuccess?()
                onDismiss?()
            } catch {
                errorMessage = error.localizedDescription
            }
            isPushing = false
        }
    }
}
