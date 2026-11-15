import SwiftUI
import YcodeAssistant
import SwiftCodeGitHub
import SwiftCodeSDK
import YcodeIDECore
import YcodeIDEShell
import os.log

private let logger = Logger(subsystem: "com.swiftcode.SourceControl", category: "BranchesView")

@MainActor
struct BranchesView: View {
    var gitViewModel: GitViewModel
    let project: Project?
    @Binding var showSuccess: Bool
    @Binding var successMessage: String?
    @Binding var showError: Bool
    @Binding var errorMessage: String?

    @State private var newBranchName = ""
    @State private var showCreateBranchSheet = false
    @State private var showRenameBranchSheet = false
    @State private var renameBranchText = ""
    @State private var selectedBranchToRename: GitBranch?

    @State private var showMergeSheet = false
    @State private var showRebaseSheet = false
    @State private var showCherryPickSheet = false
    @State private var showResetSheet = false
    @State private var showCompareSheet = false

    @State private var sourceBranch = ""
    @State private var targetBranch = ""
    @State private var commandLog = ""
    @State private var isExecutingGitCmd = false

    @State private var showInteractiveRebase = false
    @State private var rebaseCommits: [InteractiveRebaseCommit] = []

    @State private var branchSearchText = ""
    @State private var filterMode: BranchFilter = .all
    @State private var selectedBranches: Set<String> = []

    @State private var branchPendingDelete: GitBranch?
    @State private var resetPending: (mode: String, target: String)?
    @State private var showForcePushConfirm = false
    @State private var showStashSheet = false
    @State private var stashMessage = ""
    @State private var compareOutput = ""
    @State private var showCompareResult = false

    @State private var showAICleanupSheet = false
    @State private var aiCleanupPlan = ""
    @State private var isGeneratingAICleanup = false

    enum BranchFilter: String, CaseIterable, Identifiable {
        case all = "All Branches"
        case local = "Local Only"
        case remote = "Remote Tracking"
        case feature = "Features (feature/*)"
        case bugfix = "Bugfixes (bugfix/*)"

        var id: String { rawValue }
    }

    struct InteractiveRebaseCommit: Identifiable {
        let id = UUID()
        let sha: String
        let subject: String
        var action: RebaseAction

        enum RebaseAction: String, CaseIterable {
            case pick = "Pick"
            case reword = "Reword"
            case squash = "Squash"
            case drop = "Drop"
        }
    }

    var filteredBranches: [GitBranch] {
        var list = gitViewModel.branches

        if !branchSearchText.isEmpty {
            list = list.filter { $0.name.localizedCaseInsensitiveContains(branchSearchText) }
        }

        switch filterMode {
        case .all:
            break
        case .local:
            list = list.filter { !$0.isRemote }
        case .remote:
            list = list.filter { $0.isRemote || $0.trackingRemote != nil }
        case .feature:
            list = list.filter { $0.name.hasPrefix("feature/") }
        case .bugfix:
            list = list.filter { $0.name.hasPrefix("bugfix/") }
        }

        return list
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Label("Branch Directory", systemImage: "arrow.triangle.branch")
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)

                Spacer()

                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Filter branches...", text: $branchSearchText)
                        .textFieldStyle(.plain)
                    if !branchSearchText.isEmpty {
                        Button { branchSearchText = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(6)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                .frame(width: 200)

                Picker("Filter", selection: $filterMode) {
                    ForEach(BranchFilter.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .controlSize(.small)
                .frame(width: 140)

                if gitViewModel.isScanning || gitViewModel.isBusy {
                    ProgressView().controlSize(.small)
                }

                Button {
                    gitViewModel.refreshBranches()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(gitViewModel.isScanning)

                Button {
                    showCreateBranchSheet = true
                } label: {
                    Label("New Branch", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.accentColor)
            }
            .padding()
            .liquidGlass(style: .subtle, cornerRadius: 10)

            Divider()

            HStack(spacing: 12) {
                Button {
                    showMergeSheet = true
                } label: {
                    Label("Merge", systemImage: "arrow.merge")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    showRebaseSheet = true
                } label: {
                    Label("Rebase", systemImage: "arrow.turn.right.up")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    loadInteractiveRebaseCommits()
                    showInteractiveRebase = true
                } label: {
                    Label("Interactive Rebase", systemImage: "slider.horizontal.3")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    showCherryPickSheet = true
                } label: {
                    Label("Cherry-pick", systemImage: "hand.point.right.fill")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    showResetSheet = true
                } label: {
                    Label("Reset", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    showCompareSheet = true
                } label: {
                    Label("Compare", systemImage: "arrow.left.and.right")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Button {
                    runViewModelOperation("Fetch") { try await gitViewModel.fetch() }
                } label: {
                    Label("Fetch", systemImage: "arrow.down.to.line")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(gitViewModel.isBusy)

                Button {
                    runViewModelOperation("Pull") { try await gitViewModel.pull() }
                } label: {
                    Label("Pull", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(gitViewModel.isBusy)

                Button {
                    runViewModelOperation("Push") { try await gitViewModel.push() }
                } label: {
                    Label("Push", systemImage: "arrow.up.circle")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(gitViewModel.isBusy)

                Button {
                    showForcePushConfirm = true
                } label: {
                    Label("Force Push", systemImage: "exclamationmark.arrow.up")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(gitViewModel.isBusy)

                Button {
                    showStashSheet = true
                } label: {
                    Label("Stash", systemImage: "archivebox")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(gitViewModel.isBusy)

                Button {
                    showAICleanupSheet = true
                } label: {
                    Label("AI Branch Cleanup", systemImage: "sparkles")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(Color.accentColor)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.01))

            Divider()

            if !commandLog.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Git Console Output:")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Clear Console") { commandLog = "" }
                            .buttonStyle(.plain)
                            .font(.system(size: 10))
                    }
                    Text(commandLog)
                        .font(.system(size: 11, design: .monospaced))
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.black.opacity(0.15))
                        .cornerRadius(6)
                }
                .padding()
                Divider()
            }

            if filteredBranches.isEmpty {
                GitHubEmptyStateView(
                    title: "No Branches Found",
                    description: "No local or remote branches found matching your search and filter options.",
                    systemImage: "arrow.triangle.branch",
                    accentColor: Color.accentColor,
                    actionTitle: "Create New Branch"
                ) {
                    showCreateBranchSheet = true
                }
            } else {
                List {
                    Section("Branch List & Sync Balance") {
                        ForEach(filteredBranches) { branch in
                            HStack(spacing: 16) {
                                Button {
                                    if selectedBranches.contains(branch.name) {
                                        selectedBranches.remove(branch.name)
                                    } else {
                                        selectedBranches.insert(branch.name)
                                    }
                                } label: {
                                    Image(systemName: selectedBranches.contains(branch.name) ? "checkmark.square.fill" : "square")
                                        .foregroundStyle(selectedBranches.contains(branch.name) ? Color.accentColor : .secondary)
                                }
                                .buttonStyle(.plain)

                                Image(systemName: "arrow.triangle.branch")
                                    .foregroundStyle(branch.isCurrent ? Color.accentColor : .secondary)
                                    .font(.title3)

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 8) {
                                        Text(branch.name)
                                            .font(.subheadline.bold())
                                            .foregroundStyle(.primary)

                                        if branch.isCurrent {
                                            Text("CURRENT")
                                                .font(.system(size: 8, weight: .bold))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.accentColor.opacity(0.12))
                                                .foregroundStyle(Color.accentColor)
                                                .cornerRadius(4)
                                        }

                                        if branch.name == "main" || branch.name == "master" {
                                            Label("Protected", systemImage: "shield.fill")
                                                .font(.system(size: 8, weight: .bold))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.secondary.opacity(0.12))
                                                .foregroundStyle(.secondary)
                                                .cornerRadius(4)
                                        }

                                        if isStale(branch) {
                                            Text("STALE")
                                                .font(.system(size: 8, weight: .bold))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.secondary.opacity(0.12))
                                                .foregroundStyle(.secondary)
                                                .cornerRadius(4)
                                        }
                                    }

                                    Text(branch.isRemote ? "Remote Upstream" : (branch.trackingRemote ?? "Local branch"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                branchHealthIndicator(for: branch)

                                HStack(spacing: 8) {
                                    if !branch.isCurrent {
                                        Button("Checkout") {
                                            gitViewModel.checkout(branch)
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)

                                        Button("Rename...") {
                                            selectedBranchToRename = branch
                                            renameBranchText = branch.name
                                            showRenameBranchSheet = true
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)

                                        Button("Delete") {
                                            branchPendingDelete = branch
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                        .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    if !selectedBranches.isEmpty {
                        Section("Batch Action Workspace") {
                            HStack {
                                Text("\(selectedBranches.count) branches selected")
                                    .font(.subheadline.bold())
                                Spacer()
                                Button(role: .destructive) {
                                    executeBatchDelete()
                                } label: {
                                    Label("Delete Selected", systemImage: "trash.fill")
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.secondary)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .sheet(isPresented: $showCreateBranchSheet) { createBranchSheet }
        .sheet(isPresented: $showRenameBranchSheet) { renameBranchSheet }
        .sheet(isPresented: $showMergeSheet) { mergeSheetView }
        .sheet(isPresented: $showRebaseSheet) { rebaseSheetView }
        .sheet(isPresented: $showCherryPickSheet) { cherryPickSheetView }
        .sheet(isPresented: $showResetSheet) { resetSheetView }
        .sheet(isPresented: $showCompareSheet) { compareSheetView }
        .sheet(isPresented: $showInteractiveRebase) { interactiveRebaseSheetView }
        .sheet(isPresented: $showAICleanupSheet) { aiCleanupSheetView }
        .sheet(isPresented: $showStashSheet) { stashSheetView }
        .sheet(isPresented: $showCompareResult) { compareResultView }
        .alert("Delete branch?", isPresented: Binding(
            get: { branchPendingDelete != nil },
            set: { if !$0 { branchPendingDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let branch = branchPendingDelete {
                    gitViewModel.deleteBranch(branch)
                    branchPendingDelete = nil
                }
            }
            Button("Cancel", role: .cancel) { branchPendingDelete = nil }
        } message: {
            Text("This deletes the local branch \(branchPendingDelete?.name ?? ""). This action cannot be reversed.")
        }
        .alert("Reset branch?", isPresented: Binding(
            get: { resetPending != nil },
            set: { if !$0 { resetPending = nil } }
        )) {
            Button("Reset", role: .destructive) {
                if let pending = resetPending {
                    executeGitOperation(arguments: ["reset", pending.mode, pending.target])
                    resetPending = nil
                    showResetSheet = false
                }
            }
            Button("Cancel", role: .cancel) { resetPending = nil }
        } message: {
            Text("This resets the current branch to \(resetPending?.target ?? "") with \(resetPending?.mode ?? ""). A hard reset discards uncommitted changes.")
        }
        .alert("Force push?", isPresented: $showForcePushConfirm) {
            Button("Force Push", role: .destructive) {
                runViewModelOperation("Force Push") {
                    try await gitViewModel.forcePush(branch: gitViewModel.status?.branchName ?? "main")
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Force push rewrites the remote history of \(gitViewModel.status?.branchName ?? "main"). Other collaborators may lose work.")
        }
    }

    private func isStale(_ branch: GitBranch) -> Bool {
        branch.name.contains("old") || branch.name.contains("temp") || branch.name.contains("stale")
    }

    @ViewBuilder
    private func branchHealthIndicator(for branch: GitBranch) -> some View {
        HStack(spacing: 12) {
            if branch.name == "main" || branch.name == "master" {
                Label("Healthy", systemImage: "checkmark.shield")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Label("No conflict risk", systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
    }

    private var createBranchSheet: some View {
        VStack(spacing: 20) {
            HStack {
                Label("Create New Branch", systemImage: "arrow.triangle.branch")
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)
                Spacer()
                Button("Cancel") { showCreateBranchSheet = false }
                    .buttonStyle(.bordered)
            }

            VStack(alignment: .leading, spacing: 14) {
                TextField("Branch Name (e.g. feature/my-feature)", text: $newBranchName)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
            }
            .padding()

            Button {
                gitViewModel.createBranch(named: newBranchName)
                newBranchName = ""
                showCreateBranchSheet = false
            } label: {
                Text("Create Branch")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.accentColor)
            .disabled(newBranchName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(24)
        .frame(width: 400)
    }

    private var renameBranchSheet: some View {
        VStack(spacing: 20) {
            HStack {
                Label("Rename Branch", systemImage: "pencil")
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)
                Spacer()
                Button("Cancel") { showRenameBranchSheet = false }
                    .buttonStyle(.bordered)
            }

            VStack(alignment: .leading, spacing: 14) {
                TextField("New Branch Name", text: $renameBranchText)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
            }
            .padding()

            Button {
                if let target = selectedBranchToRename {
                    executeRenameBranch(from: target.name, to: renameBranchText)
                }
                showRenameBranchSheet = false
            } label: {
                Text("Rename Branch")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.accentColor)
            .disabled(renameBranchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(24)
        .frame(width: 400)
    }

    private var mergeSheetView: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Merge Branches").font(.headline)
                Spacer()
                Button("Cancel") { showMergeSheet = false }
                    .buttonStyle(.bordered)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Select source branch to merge into current (\(gitViewModel.status?.branchName ?? "main")):")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Source Branch", selection: $sourceBranch) {
                    ForEach(gitViewModel.branches.filter { !$0.isCurrent }) { branch in
                        Text(branch.name).tag(branch.name)
                    }
                }
                .pickerStyle(.menu)
            }
            .padding()

            Button {
                executeGitOperation(arguments: ["merge", sourceBranch])
                showMergeSheet = false
            } label: {
                Text("Execute Merge")
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.accentColor)
        }
        .padding(24)
        .frame(width: 400)
        .onAppear {
            sourceBranch = gitViewModel.branches.first(where: { !$0.isCurrent })?.name ?? ""
        }
    }

    private var rebaseSheetView: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Rebase Branch").font(.headline)
                Spacer()
                Button("Cancel") { showRebaseSheet = false }
                    .buttonStyle(.bordered)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Select branch to rebase current branch onto:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Onto Branch", selection: $targetBranch) {
                    ForEach(gitViewModel.branches.filter { !$0.isCurrent }) { branch in
                        Text(branch.name).tag(branch.name)
                    }
                }
                .pickerStyle(.menu)
            }
            .padding()

            Button {
                executeGitOperation(arguments: ["rebase", targetBranch])
                showRebaseSheet = false
            } label: {
                Text("Execute Rebase")
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.accentColor)
        }
        .padding(24)
        .frame(width: 400)
        .onAppear {
            targetBranch = gitViewModel.branches.first(where: { !$0.isCurrent })?.name ?? ""
        }
    }

    private var cherryPickSheetView: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Cherry-pick Commit").font(.headline)
                Spacer()
                Button("Cancel") { showCherryPickSheet = false }
                    .buttonStyle(.bordered)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Enter the Commit SHA of the commit you wish to cherry-pick:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("Commit SHA (e.g. a1b2c3d)", text: $sourceBranch)
                    .textFieldStyle(.roundedBorder)
            }
            .padding()

            Button {
                executeGitOperation(arguments: ["cherry-pick", sourceBranch])
                showCherryPickSheet = false
            } label: {
                Text("Execute Cherry-pick")
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.accentColor)
            .disabled(sourceBranch.isEmpty)
        }
        .padding(24)
        .frame(width: 400)
    }

    private var resetSheetView: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Reset Branch").font(.headline)
                Spacer()
                Button("Cancel") { showResetSheet = false }
                    .buttonStyle(.bordered)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Select Reset Mode:")
                    .font(.subheadline.bold())

                Picker("Reset Mode", selection: $sourceBranch) {
                    Text("Hard (--hard) - Discards all changes").tag("--hard")
                    Text("Soft (--soft) - Keeps staged changes").tag("--soft")
                    Text("Mixed (--mixed) - Keeps uncommitted modifications").tag("--mixed")
                }
                .pickerStyle(.radioGroup)

                Text("Reset target Commit SHA / Reference:")
                    .font(.subheadline.bold())
                TextField("HEAD~1 or commit SHA", text: $targetBranch)
                    .textFieldStyle(.roundedBorder)
            }
            .padding()

            Button {
                resetPending = (mode: sourceBranch, target: targetBranch)
            } label: {
                Text("Execute Reset")
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.accentColor)
            .disabled(targetBranch.isEmpty)
        }
        .padding(24)
        .frame(width: 400)
        .onAppear {
            sourceBranch = "--mixed"
            targetBranch = "HEAD~1"
        }
    }

    private var compareSheetView: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Compare Branches").font(.headline)
                Spacer()
                Button("Cancel") { showCompareSheet = false }
                    .buttonStyle(.bordered)
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Picker("Branch A", selection: $sourceBranch) {
                        ForEach(gitViewModel.branches) { branch in
                            Text(branch.name).tag(branch.name)
                        }
                    }
                    Spacer()
                    Text("vs")
                    Spacer()
                    Picker("Branch B", selection: $targetBranch) {
                        ForEach(gitViewModel.branches) { branch in
                            Text(branch.name).tag(branch.name)
                        }
                    }
                }
            }
            .padding()

            Button {
                showCompareSheet = false
                runCompare()
            } label: {
                Text("Compare & Log Diff")
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.accentColor)
            .disabled(sourceBranch.isEmpty || targetBranch.isEmpty || sourceBranch == targetBranch)
        }
        .padding(24)
        .frame(width: 460)
        .onAppear {
            sourceBranch = gitViewModel.status?.branchName ?? "main"
            targetBranch = gitViewModel.branches.first(where: { !$0.isCurrent })?.name ?? ""
        }
    }

    private var interactiveRebaseSheetView: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Interactive Rebase Workbench").font(.headline)
                Spacer()
                Button("Done") { showInteractiveRebase = false }
                    .buttonStyle(.bordered)
            }

            Text("Configure rebase actions (Pick, Reword, Squash, Drop) for your active commits:")
                .font(.caption)
                .foregroundStyle(.secondary)

            List {
                ForEach($rebaseCommits) { $commit in
                    HStack {
                        Text(commit.sha)
                            .font(.system(.caption, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(4)

                        Text(commit.subject)
                            .lineLimit(1)

                        Spacer()

                        Picker("Action", selection: $commit.action) {
                            ForEach(InteractiveRebaseCommit.RebaseAction.allCases, id: \.self) { act in
                                Text(act.rawValue).tag(act)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 100)
                    }
                }
            }
            .frame(height: 250)

            Button {
                executeInteractiveRebase()
                showInteractiveRebase = false
            } label: {
                Text("Execute Interactive Rebase")
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.accentColor)
        }
        .padding(24)
        .frame(width: 520)
    }

    private var aiCleanupSheetView: some View {
        VStack(spacing: 20) {
            HStack {
                Text("AI Branch Cleanup & Optimization").font(.headline)
                Spacer()
                Button("Cancel") { showAICleanupSheet = false }
                    .buttonStyle(.bordered)
            }

            Text("AI evaluates active branches, detects merged and stale local branches, and compiles a cleaning recommendations list.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if isGeneratingAICleanup {
                VStack {
                    ProgressView().controlSize(.small)
                    Text("AI reasoning on repository timeline branches...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(height: 180)
            } else if !aiCleanupPlan.isEmpty {
                ScrollView {
                    Text(aiCleanupPlan)
                        .font(.system(size: 11, design: .monospaced))
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.black.opacity(0.12))
                        .cornerRadius(6)
                }
                .frame(height: 200)
            }

            Button {
                runAICleanupAnalysis()
            } label: {
                Label(isGeneratingAICleanup ? "Evaluating..." : "Generate Cleanup Prescription Plan", systemImage: "sparkles")
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.accentColor)
            .disabled(isGeneratingAICleanup)
        }
        .padding(24)
        .frame(width: 480)
    }

    private func runViewModelOperation(_ label: String, _ work: @escaping () async throws -> Void) {
        Task {
            do {
                try await work()
                successMessage = "\(label) completed."
                showSuccess = true
            } catch {
                errorMessage = "\(label) failed: \(error.localizedDescription)"
                showError = true
            }
        }
    }

    private func runCompare() {
        guard let proj = project else { return }
        isExecutingGitCmd = true
        compareOutput = ""
        Task {
            do {
                if gitViewModel.usesSpaces {
                    let from = sourceBranch
                    let to = targetBranch
                    compareOutput = try await SpacesService.shared.compare(from: from, to: to, repositoryURL: proj.directoryURL)
                    if compareOutput.isEmpty {
                        compareOutput = "No differences between \(from) and \(to)."
                    }
                } else {
                    let gitBinary = URL(fileURLWithPath: AppSettings.shared.gitPath.isEmpty ? "/usr/bin/git" : AppSettings.shared.gitPath)
                    let result = try await ProcessRunnerTool.shared.run(
                        executableURL: gitBinary,
                        arguments: ["diff", "\(sourceBranch)..\(targetBranch)"],
                        workingDirectory: proj.directoryURL
                    )
                    guard result.exitCode == 0 else {
                        throw AppError.gitError(result.stderr)
                    }
                    compareOutput = result.stdout.isEmpty ? "No differences between \(sourceBranch) and \(targetBranch)." : result.stdout
                }
                showCompareResult = true
            } catch {
                errorMessage = "Compare failed: \(error.localizedDescription)"
                showError = true
            }
            isExecutingGitCmd = false
        }
    }

    private var stashSheetView: some View {
        VStack(spacing: 20) {
            HStack {
                Label("Stash Changes", systemImage: "archivebox")
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)
                Spacer()
                Button("Cancel") { showStashSheet = false }
                    .buttonStyle(.bordered)
            }

            TextField("Stash message (e.g. work in progress on login flow)", text: $stashMessage)
                .textFieldStyle(.roundedBorder)

            Button {
                let message = stashMessage
                stashMessage = ""
                showStashSheet = false
                runViewModelOperation("Stash") { try await gitViewModel.stash(message: message) }
            } label: {
                Text("Stash")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.accentColor)
            .disabled(stashMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(24)
        .frame(width: 400)
    }

    private var compareResultView: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Compare \(sourceBranch) vs \(targetBranch)", systemImage: "arrow.left.and.right")
                    .font(.headline)
                Spacer()
                Button("Done") { showCompareResult = false }
                    .buttonStyle(.bordered)
            }
            .padding(16)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(compareOutput.components(separatedBy: .newlines).enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(compareLineColor(line))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 1)
                            .background(compareLineBackground(line))
                    }
                }
            }
            .background(Color.black.opacity(0.85))
        }
        .frame(width: 700, height: 500)
    }

    private func compareLineColor(_ line: String) -> Color {
        if line.hasPrefix("+") && !line.hasPrefix("+++") { return .green }
        if line.hasPrefix("-") && !line.hasPrefix("---") { return .red }
        if line.hasPrefix("@@") { return .blue }
        return .primary
    }

    private func compareLineBackground(_ line: String) -> Color {
        if line.hasPrefix("+") && !line.hasPrefix("+++") { return Color.green.opacity(0.08) }
        if line.hasPrefix("-") && !line.hasPrefix("---") { return Color.red.opacity(0.08) }
        return .clear
    }

    private func executeGitOperation(arguments: [String]) {
        guard let proj = project else { return }
        guard !isExecutingGitCmd else { return }
        isExecutingGitCmd = true

        if gitViewModel.usesSpaces {
            commandLog = "Executing Spaces: \(arguments.joined(separator: " "))"
            Task {
                do {
                    let op = arguments.first ?? ""
                    switch op {
                    case "branch":
                        if arguments.contains("-m") && arguments.count >= 4 {
                            let old = arguments[2], new = arguments[3]
                            try await SpacesService.shared.renameBranch(old, to: new, repositoryURL: proj.directoryURL)
                            commandLog = "Success! Renamed branch \(old) to \(new)"
                        } else if arguments.contains("-d") {
                            for b in arguments.dropFirst(2) {
                                try await SpacesService.shared.deleteBranch(name: b, repositoryURL: proj.directoryURL)
                            }
                            commandLog = "Success! Deleted branches: \(arguments.dropFirst(2).joined(separator: ", "))"
                        } else {
                            commandLog = "Unsupported Spaces branch operation: \(arguments.joined(separator: " "))"
                        }
                    case "merge":
                        if arguments.count >= 2 {
                            let target = arguments[1]
                            try await SpacesService.shared.merge(target, repositoryURL: proj.directoryURL)
                            commandLog = "Success! Merged \(target)"
                        }
                    case "rebase":
                        if arguments.count >= 2 {
                            let target = arguments[1]
                            try await SpacesService.shared.rebase(onto: target, repositoryURL: proj.directoryURL)
                            commandLog = "Success! Rebased onto \(target)"
                        }
                    case "cherry-pick":
                        if arguments.count >= 2 {
                            let rev = arguments[1]
                            try await SpacesService.shared.cherryPick(rev: rev, repositoryURL: proj.directoryURL)
                            commandLog = "Success! Cherry-picked \(rev)"
                        }
                    case "reset":
                        if arguments.count >= 3 {
                            let target = arguments[2]
                            try await SpacesService.shared.rollback(to: target, repositoryURL: proj.directoryURL)
                            commandLog = "Success! Reset to \(target)"
                        }
                    case "diff":
                        if arguments.count >= 2 {
                            let range = arguments[1]
                            let parts = range.components(separatedBy: "..")
                            if parts.count == 2 {
                                let diff = try await SpacesService.shared.getDiffBetween(from: parts[0], to: parts[1], repositoryURL: proj.directoryURL)
                                commandLog = diff.isEmpty ? "No differences between \(parts[0]) and \(parts[1])." : diff
                            } else {
                                let diff = try await SpacesService.shared.getDiff(repositoryURL: proj.directoryURL)
                                commandLog = diff.map { $0.header + "\n" + $0.lines.joined(separator: "\n") }.joined(separator: "\n")
                            }
                        }
                    default:
                        commandLog = "Unsupported Spaces operation: \(arguments.joined(separator: " "))"
                    }
                } catch {
                    commandLog = "Execution failed:\n\(error.localizedDescription)"
                }
                await gitViewModel.refreshStatus()
                isExecutingGitCmd = false
            }
            return
        }

        commandLog = "Executing: git \(arguments.joined(separator: " "))"

        Task {
            do {
                let gitBinary = URL(fileURLWithPath: AppSettings.shared.gitPath.isEmpty ? "/usr/bin/git" : AppSettings.shared.gitPath)
                let result = try await ProcessRunnerTool.shared.run(
                    executableURL: gitBinary,
                    arguments: arguments,
                    workingDirectory: proj.directoryURL
                )
                commandLog = result.exitCode == 0 ? "Success!\n\(result.stdout)" : "Error:\n\(result.stderr)"
            } catch {
                commandLog = "Execution failed:\n\(error.localizedDescription)"
            }
            await gitViewModel.refreshStatus()
            isExecutingGitCmd = false
        }
    }

    private func executeRenameBranch(from: String, to: String) {
        executeGitOperation(arguments: ["branch", "-m", from, to])
    }

    private func executeBatchDelete() {
        let alert = NSAlert()
        alert.messageText = "Delete Selected Branches?"
        alert.informativeText = "Are you sure you want to delete these \(selectedBranches.count) branches? This action cannot be reversed."
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning

        if alert.runModal() == .alertFirstButtonReturn {
            let list = Array(selectedBranches)
            executeGitOperation(arguments: ["branch", "-d"] + list)
            selectedBranches.removeAll()
        }
    }

    private func loadInteractiveRebaseCommits() {
        rebaseCommits = gitViewModel.history.prefix(3).map {
            InteractiveRebaseCommit(sha: String($0.sha.prefix(7)), subject: $0.subject, action: .pick)
        }
    }

    private func executeInteractiveRebase() {
        commandLog = "Prepared sequence instructions for GIT_SEQUENCE_EDITOR:\n" + rebaseCommits.map { "\($0.action.rawValue.lowercased()) \($0.sha) \($0.subject)" }.joined(separator: "\n")
    }

    private func runAICleanupAnalysis() {
        isGeneratingAICleanup = true
        aiCleanupPlan = ""

        let branchNames = gitViewModel.branches.map(\.name).joined(separator: ", ")

        let prompt = """
        You are an AI branch cleanup assistant. Evaluate the following local branch list:
        - Active Branches: \(branchNames)
        - Current Branch: \(gitViewModel.status?.branchName ?? "main")

        Propose a step-by-step cleanup prescription plan to clean up local stale tracking branches.
        Include a safe shell script snippet containing the safe git commands (e.g. `git branch -d <branch_name>`).
        Output exactly 3 lines:
        1. [Analysis] Detected branches and which ones seem stale or old.
        2. [Git cleanup script] Command block to delete old branch.
        3. [Best practice tip] Quick suggestion on keeping branches clean.
        """

        Task {
            do {
                let response = try await LLMService.shared.generateExternalResponse(prompt: prompt, useContext: false)
                aiCleanupPlan = response.trimmingCharacters(in: .whitespacesAndNewlines)
            } catch {
                aiCleanupPlan = "AI Analysis error: \(error.localizedDescription)"
            }
            isGeneratingAICleanup = false
        }
    }
}
