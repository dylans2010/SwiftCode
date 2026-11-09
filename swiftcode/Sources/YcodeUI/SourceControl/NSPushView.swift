import SwiftUI
import YcodeIDECore

public struct NSPushView: View {
    @State private var remotes: [String] = ["origin"]
    @State private var selectedRemote = "origin"
    @State private var branches: [String] = ["main"]
    @State private var selectedBranch = "main"
    @State private var forcePush = false
    @State private var showForceWarning = false
    @State private var outgoingCount = 0
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
                        Label("Git Push", systemImage: "arrow.up.circle.fill")
                            .font(.headline)
                            .foregroundStyle(.blue)
                        Spacer()
                        Button("Full View…") {
                            showFullSheet = true
                        }
                        .buttonStyle(.plain)
                        .font(.caption2)
                        .foregroundStyle(.blue)
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
                        if outgoingCount == 0 {
                            Label("Already up to date", systemImage: "checkmark.circle")
                                .font(.caption2.bold())
                                .foregroundStyle(.green)
                        } else {
                            Label("\(outgoingCount) unpushed commit\(outgoingCount == 1 ? "" : "s")", systemImage: "arrow.up")
                                .font(.caption2.bold())
                                .foregroundStyle(.blue)
                        }
                        Spacer()
                    }

                    
                    Toggle("Force Push", isOn: Binding(
                        get: { forcePush },
                        set: { if $0 { showForceWarning = true } else { forcePush = false } }
                    ))
                    .toggleStyle(.checkbox)
                    .font(.caption2)
                    .foregroundStyle(forcePush ? .red : .primary)

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

                    Button {
                        performPush()
                    } label: {
                        HStack {
                            Spacer()
                            Label(outgoingCount == 0 ? "Push (Up to date)" : "Push \(outgoingCount) Commit\(outgoingCount == 1 ? "" : "s")", systemImage: "arrow.up.circle.fill")
                                .fontWeight(.bold)
                            Spacer()
                        }
                        .padding(.vertical, 6)
                        .background(forcePush ? Color.red : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                        .shadow(color: (forcePush ? Color.red : Color.blue).opacity(0.4), radius: 6, x: 0, y: 1)
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoading || (outgoingCount == 0 && !forcePush))
                }
                .onAppear {
                    loadData()
                }
                .alert("Confirm Force Push", isPresented: $showForceWarning) {
                    Button("Enable Force Push", role: .destructive) { forcePush = true }
                    Button("Cancel", role: .cancel) { forcePush = false }
                } message: {
                    Text("Force push may overwrite changes on remote '\(selectedRemote)/\(selectedBranch)'.")
                }
                .sheet(isPresented: $showFullSheet) {
                    ModernGitPushView(
                        repository: GitRepository(containing: activeProject.directoryURL),
                        onDismiss: { showFullSheet = false },
                        onPushSuccess: {
                            showFullSheet = false
                            successMsg = "Pushed successfully!"
                            loadData()
                        }
                    )
                }
            } else {
                NoActiveProjectView(title: "Push")
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

        if let (ahead, _) = repo.aheadBehind(currBranch) {
            self.outgoingCount = ahead
        } else {
            
            let out = (try? repo.runGit(["rev-list", "--count", "@{u}..HEAD"])) ?? "0"
            self.outgoingCount = Int(out.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        }
    }

    private func performPush() {
        isLoading = true
        successMsg = ""
        errorMsg = ""
        let isForce = forcePush
        let rem = selectedRemote
        let br = selectedBranch

        Task {
            do {
                var args = ["push", rem, br]
                if isForce { args.append("--force-with-lease") }
                try await GitMenuBarCommandExecutor.runGit(args: args)
                successMsg = "Successfully pushed to '\(rem)/\(br)'."
                outgoingCount = 0
                forcePush = false
            } catch {
                errorMsg = error.localizedDescription
            }
            isLoading = false
        }
    }
}
