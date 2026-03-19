import SwiftUI

struct BranchWorkspaceView: View {
    @ObservedObject var manager: CollaborationManager
    let actorID: String

    @State private var selectedFilePath: String?
    @State private var editorText = ""
    @State private var newFilePath = ""
    @State private var commitMessage = ""
    @State private var newBranchName = ""
    @State private var pullRequestTargetID: UUID?
    @State private var showingCommitManager = false
    @State private var showingCreatePRSheet = false
    @State private var preparedPullRequest: PullRequestDraftPayload?

    private var workspace: BranchWorkspace? { manager.workspaces.currentWorkspace }

    var body: some View {
        List {
            headerSection
            filesSection
            changesSection
            actionsSection
            statusSection
        }
        .navigationTitle("Branches")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if manager.workspaces.isLoadingWorkspace {
                    ProgressView()
                }
                Menu {
                    ForEach(manager.branches.branches) { branch in
                        Button(branch.name) {
                            _ = manager.workspaces.loadWorkspace(for: branch.id, actorID: actorID)
                            selectCurrentFileIfNeeded()
                        }
                    }
                } label: {
                    Label("Switch Branch", systemImage: "arrow.triangle.branch")
                }
            }
        }
        .sheet(isPresented: $showingCommitManager) {
            NavigationStack {
                CommitManagerView(manager: manager, actorID: actorID)
            }
        }
        .sheet(isPresented: $showingCreatePRSheet) {
            if let currentBranch = workspace?.branchID {
                CreatePullRequestView(manager: manager, actorID: actorID, preferredSourceBranchID: currentBranch, preferredTargetBranchID: pullRequestTargetID, preparedPayload: preparedPullRequest)
            }
        }
        .onAppear {
            if workspace == nil {
                _ = manager.workspaces.loadWorkspace(for: manager.branches.currentBranch.id, actorID: actorID)
            }
            selectCurrentFileIfNeeded()
        }
    }

    private var headerSection: some View {
        Section("Workspace") {
            if let workspace {
                VStack(alignment: .leading, spacing: 10) {
                    Label(workspace.branchName, systemImage: "arrow.triangle.branch")
                        .font(.headline)
                    Text(workspace.workingDirectory)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("New Branch Name", text: $newBranchName)
                    Button {
                        let branch = manager.branches.createBranch(name: newBranchName, from: manager.branches.currentBranch.id, actorID: actorID)
                        _ = manager.workspaces.createWorkspace(for: branch, from: manager.branches.currentBranch.id, actorID: actorID)
                        newBranchName = ""
                        selectCurrentFileIfNeeded()
                    } label: {
                        Label("Create Branch", systemImage: "plus")
                    }
                    .disabled(newBranchName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    HStack {
                        statBadge(title: "Files", value: "\(workspace.files.count)")
                        statBadge(title: "Changes", value: "\(workspace.pendingChanges.count)")
                        statBadge(title: "Commits", value: "\(manager.commits.commits(for: workspace.branchID).count)")
                    }
                }
            } else {
                ContentUnavailableView("No Workspace", systemImage: "externaldrive.badge.exclamationmark", description: Text("Create or load a branch workspace to start editing."))
            }
        }
    }

    private var filesSection: some View {
        Section("Files") {
            if let workspace {
                TextField("New File Path", text: $newFilePath)
                Button {
                    manager.workspaces.createFile(path: newFilePath, authorID: actorID)
                    newFilePath = ""
                    selectCurrentFileIfNeeded()
                } label: {
                    Label("Create File", systemImage: "doc.badge.plus")
                }
                .disabled(newFilePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                ForEach(workspace.files.sorted { $0.path < $1.path }) { file in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Button(file.path) {
                                selectedFilePath = file.path
                                editorText = file.content
                            }
                            Spacer()
                            Button(role: .destructive) {
                                manager.workspaces.deleteFile(path: file.path, authorID: actorID)
                                if selectedFilePath == file.path {
                                    selectedFilePath = nil
                                    editorText = ""
                                }
                            } label: {
                                Image(systemName: "trash")
                            }
                        }
                        if selectedFilePath == file.path {
                            TextEditor(text: $editorText)
                                .frame(minHeight: 160)
                            Button {
                                manager.workspaces.updateFile(path: file.path, content: editorText, authorID: actorID)
                            } label: {
                                Label("Save File", systemImage: "square.and.arrow.down")
                            }
                        }
                    }
                }
            }
        }
    }

    private var changesSection: some View {
        Section("Active Changes") {
            if let workspace, workspace.pendingChanges.isEmpty {
                Text("No Uncommitted Changes")
                    .foregroundStyle(.secondary)
            } else if let workspace {
                ForEach(workspace.pendingChanges) { change in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(change.path).font(.headline)
                                Text(change.kind.rawValue.capitalized)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(change.isStaged ? "Unstage" : "Stage") {
                                if change.isStaged {
                                    manager.commits.unstage(path: change.path, actorID: actorID, branchID: workspace.branchID)
                                } else {
                                    manager.commits.stage(path: change.path, authorID: actorID, branchID: workspace.branchID)
                                }
                                manager.workspaces.syncWorkspaceStateFromCommitManager()
                            }
                        }
                        NavigationLink("View Diff") {
                            CollaborationDiffViewerView(diff: change.diff)
                        }
                    }
                }
            }
        }
    }

    private var actionsSection: some View {
        Section("Actions") {
            TextField("Commit message", text: $commitMessage)
            Button {
                _ = manager.workspaces.commitCurrentWorkspace(message: commitMessage, authorID: actorID)
                commitMessage = ""
            } label: {
                Label("Commit Changes", systemImage: "checkmark.circle.fill")
            }
            .disabled(commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Button {
                showingCommitManager = true
            } label: {
                Label("Open Commit Flow", systemImage: "shippingbox.circle")
            }

            Button(role: .destructive) {
                manager.workspaces.discardChanges()
                selectCurrentFileIfNeeded()
            } label: {
                Label("Discard Changes", systemImage: "arrow.uturn.backward.circle")
            }

            Button {
                manager.workspaces.resetToLastCommit()
                selectCurrentFileIfNeeded()
            } label: {
                Label("Reset to Last Commit", systemImage: "clock.arrow.circlepath")
            }

            Picker("PR Target", selection: Binding(get: {
                pullRequestTargetID ?? manager.branches.branches.first(where: { $0.id != manager.branches.currentBranch.id })?.id
            }, set: { pullRequestTargetID = $0 })) {
                ForEach(manager.branches.branches.filter { $0.id != manager.branches.currentBranch.id }) { branch in
                    Text(branch.name).tag(Optional(branch.id))
                }
            }

            Button {
                if let target = pullRequestTargetID ?? manager.branches.branches.first(where: { $0.id != manager.branches.currentBranch.id })?.id {
                    preparedPullRequest = manager.workspaces.preparePullRequestPayload(targetBranchID: target, actorID: actorID)
                }
                showingCreatePRSheet = true
            } label: {
                Label("Create Pull Request", systemImage: "arrow.triangle.pull")
            }
            .disabled(manager.branches.branches.count < 2)
        }
    }

    private var statusSection: some View {
        Section {
            if let success = manager.workspaces.lastSuccessMessage {
                Label(success, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
            if let error = manager.workspaces.lastErrorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            }
        }
    }

    private func statBadge(title: String, value: String) -> some View {
        VStack(alignment: .leading) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline)
        }
        .padding(8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func selectCurrentFileIfNeeded() {
        guard let workspace else { return }
        if let selectedFilePath, let file = workspace.files.first(where: { $0.path == selectedFilePath }) {
            editorText = file.content
        } else if let first = workspace.files.first {
            selectedFilePath = first.path
            editorText = first.content
        }
    }
}
