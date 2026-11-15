import SwiftUI
import SpacesEngine
import SwiftCodeSDK





@Observable
@MainActor
final class SpacesWorkspaceModel {
    enum Section: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case changes = "Changes"
        case branches = "Branches"
        case tags = "Tags"
        case compare = "Compare"
        case search = "Search"
        case history = "History"
        case operations = "Operations"
        case remotes = "Remotes"
        case maintenance = "Maintenance"
        case intelligence = "Intelligence"
        case reviews = "Reviews"
        case security = "Security"
        case storage = "Storage"
        case migration = "Migration"
        case console = "Console (CLI)"
        var id: String { rawValue }
    }

    var section: Section = .overview
    var repo: Repository?
    var api: SpacesAPI?
    var error: String?
    var notice: String?
    var inFlight = 0
    private var runningTasks: [Task<Void, Never>] = []

    var isBusy: Bool { inFlight > 0 }

    func cancelOperations() {
        for task in runningTasks { task.cancel() }
        runningTasks.removeAll()
    }

    
    var status: WorktreeScanner.StatusReport?
    var commitMessage = ""
    var isAmending = false
    var selectedFilePath: String?
    var fileDiffLines: [String] = []

    
    var commits: [HistoryOps.CommitInfo] = []
    var graphNodes: [BranchOps.GraphNode] = []
    var selectedCommit: HistoryOps.CommitInfo?
    var selectedCommitPatch: String = ""

    
    var branches: [BranchOps.BranchInfo] = []
    var tags: [TagOps.TagInfo] = []
    var newBranchName = ""
    var newTagName = ""
    var newTagMessage = ""
    var mergeTarget = ""
    var rebaseOnto = ""
    var cherryPickRev = ""
    var stashMessage = ""

    var compareFrom = ""
    var compareTo = ""
    var compareOutput = ""

    var searchQuery = ""
    var searchResults: [SearchOps.Result] = []
    var hasSearched = false

    
    var stashes: [StashOps.StashEntry] = []
    var snapshots: [SnapshotOps.SnapshotInfo] = []
    var timeline: [SnapshotOps.TimelineEntry] = []

    
    var remotes: [RemoteOps.RemoteInfo] = []
    var remoteName = "origin"
    var remoteURL = ""

    
    var fsckIssues: [MaintenanceOps.FSCKIssue] = []
    var objectCounts: (blobs: Int, trees: Int, commits: Int, tags: Int, snapshots: Int, total: Int)?
    var healthScore: Int?
    var diagnostics: [String] = []

    
    var gitPath = ""
    var exportPath = ""

    
    var consoleInput = ""
    var consoleOutput = "Spaces Native Source Control Console ready.\nType a command or click a preset below.\n"
    var isExecutingConsole = false

    let project: Project

    init(project: Project) {
        self.project = project
        open()
    }

    func open() {
        do {
            let r = try Repository.open(at: project.directoryURL)
            repo = r
            api = SpacesAPI(repo: r)
            self.error = nil
            refreshAll()
        } catch {
            repo = nil
            api = nil
            self.error = error.localizedDescription
        }
    }

    func initialize() {
        do {
            let identity = Signature(name: NSFullUserName(), email: "\(NSUserName())@localhost")
            let r = try Repository.create(at: project.directoryURL,
                                          defaultBranch: SpacesService.defaultBranchSetting,
                                          user: SpacesConfig.User(name: identity.name, email: identity.email))
            repo = r
            api = SpacesAPI(repo: r)
            error = nil
            notice = "Spaces native repository initialized (.spaces/)"
            refreshAll()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func refreshAll() {
        refreshStatus()
        refreshHistory()
        refreshBranches()
        refreshTags()
        refreshStashes()
        refreshSnapshots()
        refreshRemotes()
        refreshMaintenance()
    }

    private func run(_ what: String, _ body: @escaping @Sendable (SpacesAPI) throws -> Void) {
        guard let api else { return }
        inFlight += 1
        let task = Task.detached {
            defer { Task { @MainActor in self.inFlight -= 1 } }
            do { try body(api) } catch {
                await MainActor.run { self.error = "\(what): \(error.localizedDescription)" }
            }
            guard !Task.isCancelled else { return }
            await MainActor.run { self.refreshAll() }
        }
        runningTasks.append(task)
    }

    private func runValue<T: Sendable>(_ what: String, _ body: @escaping @Sendable (SpacesAPI) throws -> T,
                                       assign: @escaping @MainActor @Sendable (T) -> Void) {
        guard let api else { return }
        inFlight += 1
        let task = Task.detached {
            defer { Task { @MainActor in self.inFlight -= 1 } }
            do {
                let value = try body(api)
                guard !Task.isCancelled else { return }
                await MainActor.run { assign(value) }
            } catch {
                await MainActor.run { self.error = "\(what): \(error.localizedDescription)" }
            }
        }
        runningTasks.append(task)
    }

    func refreshStatus() {
        runValue("status", { try $0.status() }, assign: {
            self.status = $0
            if let sel = self.selectedFilePath {
                self.loadFileDiff(path: sel)
            }
        })
    }

    func refreshHistory() {
        runValue("log", { try $0.log(limit: 100) }, assign: { self.commits = $0 })
        runValue("graph", { try $0.graph(limit: 100) }, assign: { self.graphNodes = $0 })
    }

    func refreshBranches() {
        runValue("branches", { try $0.branches() }, assign: { self.branches = $0 })
    }

    func refreshTags() {
        runValue("tags", { try $0.tags() }, assign: { self.tags = $0 })
    }

    func refreshStashes() {
        runValue("stash list", { try $0.stashes() }, assign: { self.stashes = $0 })
    }

    func refreshSnapshots() {
        runValue("snapshots", { try $0.snapshots() }, assign: { self.snapshots = $0 })
        runValue("timeline", { try $0.timeline(limit: 50) }, assign: { self.timeline = $0 })
    }

    func refreshRemotes() {
        guard let repo else { return }
        remotes = RemoteOps(repo: repo).list()
    }

    func refreshMaintenance() {
        runValue("fsck", { try $0.fsck() }, assign: { self.fsckIssues = $0 })
        runValue("count", { try $0.countObjects() }, assign: { self.objectCounts = $0 })
        runValue("health", { try $0.health() }, assign: {
            self.healthScore = $0.score
            self.diagnostics = $0.issues.map { "\($0.level.rawValue): \($0.name) — \($0.detail)" }
        })
    }

    

    func stage(_ path: String) { run("stage") { _ = try $0.add(path) } }
    func unstage(_ path: String) { run("unstage") { try $0.unstage(path) } }
    func stageAll() { run("stage all") { _ = try $0.stageAll() } }
    func restore(_ path: String) { run("restore") { try $0.restore(path) } }
    func clean() { run("clean") { _ = try $0.clean() } }

    func commit() {
        let msg = commitMessage
        let amend = isAmending
        run("commit") { _ = try $0.commit(message: msg, amend: amend) }
        commitMessage = ""
        isAmending = false
    }

    func createBranch() {
        let name = newBranchName
        run("create branch") { _ = try $0.createBranch(name) }
        newBranchName = ""
    }

    func switchTo(_ name: String) { run("switch") { try $0.switchTo(name) } }
    func deleteBranch(_ name: String) { run("delete branch") { try $0.deleteBranch(name) } }
    func renameBranch(_ old: String, to new: String) { run("rename branch") { try $0.renameBranch(old, to: new) } }

    func merge() {
        let target = mergeTarget
        run("merge") { _ = try $0.merge(target) }
        mergeTarget = ""
    }
    func mergeContinue() { run("merge continue") { _ = try $0.mergeContinue() } }
    func mergeAbort() { run("merge abort") { try $0.mergeAbort() } }

    func rebase() {
        let onto = rebaseOnto
        run("rebase") { _ = try $0.rebase(onto: onto) }
        rebaseOnto = ""
    }
    func rebaseContinue() { run("rebase continue") { _ = try $0.rebaseContinue() } }
    func rebaseSkip() { run("rebase skip") { _ = try $0.rebaseSkip() } }
    func rebaseAbort() { run("rebase abort") { try $0.rebaseAbort() } }

    func cherryPick() {
        let rev = cherryPickRev
        run("cherry-pick") { _ = try $0.cherryPick(rev) }
        cherryPickRev = ""
    }

    func stash(message: String) {
        let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
        run("stash") { _ = try $0.stash(message: text.isEmpty ? nil : text) }
        stashMessage = ""
    }
    func applyStash(_ id: String, pop: Bool = false) { run("apply stash") { try $0.stashApply(id, pop: pop) } }
    func dropStash(_ id: String) { run("drop stash") { try $0.stashDrop(id) } }

    func createTag() {
        let name = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let message = newTagMessage
        run("create tag") { _ = try $0.createTag(name, at: "HEAD", annotated: !message.isEmpty, message: message) }
        newTagName = ""
        newTagMessage = ""
    }

    func deleteTag(_ name: String) { run("delete tag") { try $0.deleteTag(name) } }

    func compare() {
        let from = compareFrom
        let to = compareTo
        guard !from.isEmpty, !to.isEmpty, from != to else { return }
        Task {
            do {
                let out = try await SpacesService.shared.compare(from: from, to: to, repositoryURL: project.directoryURL)
                self.compareOutput = out.isEmpty ? "No differences between \(from) and \(to)." : out
            } catch {
                self.error = "compare: \(error.localizedDescription)"
                self.compareOutput = ""
            }
        }
    }

    func search() {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        hasSearched = true
        runValue("search", { try $0.search(SearchOps.Query(text: query)) }, assign: { self.searchResults = $0 })
    }
    func snapshot() { run("snapshot") { _ = try $0.snapshot(message: "manual snapshot") } }
    func restoreSnapshot(_ rev: String) { run("restore snapshot") { try $0.restoreSnapshot(rev) } }

    func addRemote() {
        let name = remoteName, url = remoteURL
        run("add remote") { try $0.addRemote(name, url: url) }
        remoteURL = ""
    }
    func removeRemote(_ name: String) { run("remove remote") { try $0.removeRemote(name) } }
    func fetch() { run("fetch") { _ = try $0.fetch("origin") } }
    func pull() { run("pull") { _ = try $0.pull("origin") } }
    func push() { run("push") { _ = try $0.push("origin", refspec: "refs/heads/*:refs/heads/*") } }
    func forcePush() {
        guard let branch = status?.branch else { return }
        run("force push") { _ = try $0.push("origin", refspec: "refs/heads/\(branch):refs/heads/\(branch)", force: true) }
    }

    func gc() { run("gc") { _ = try $0.gc() } }
    func rebuildIndex() { run("rebuild index") { _ = try $0.rebuildIndex() } }

    func importGit() {
        let path = gitPath
        run("git import") { _ = try $0.importGit(at: path) }
    }
    func exportGit() {
        let path = exportPath
        run("git export") { _ = try $0.exportGit(to: path) }
    }

    func selectFile(_ path: String) {
        selectedFilePath = path
        loadFileDiff(path: path)
    }

    private func loadFileDiff(path: String) {
        guard let api else { return }
        Task.detached {
            do {
                let diffs = try api.diff()
                if let hit = diffs.first(where: { $0.newPath == path || $0.oldPath == path }) {
                    let patch = hit.patch ?? "No textual differences"
                    let lines = patch.components(separatedBy: .newlines)
                    await MainActor.run { self.fileDiffLines = lines }
                } else {
                    await MainActor.run { self.fileDiffLines = ["File unchanged in worktree."] }
                }
            } catch {
                await MainActor.run { self.fileDiffLines = ["Diff error: \(error.localizedDescription)"] }
            }
        }
    }

    func selectCommit(_ c: HistoryOps.CommitInfo) {
        selectedCommit = c
        guard let api else { return }
        Task.detached {
            do {
                let res = try api.show(c.oid.hex)
                await MainActor.run { self.selectedCommitPatch = res.patch }
            } catch {
                await MainActor.run { self.selectedCommitPatch = "Show error: \(error.localizedDescription)" }
            }
        }
    }

    func executeConsole(_ commandText: String? = nil) {
        let raw = (commandText ?? consoleInput).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty, let api else { return }
        consoleInput = ""
        isExecutingConsole = true
        consoleOutput += "\n❯ spaces \(raw)\n"

        Task.detached {
            var output = ""
            do {
                let cmd = raw.components(separatedBy: " ").first ?? raw
                switch cmd {
                case "status":
                    let s = try api.status()
                    output = "On branch \(s.branch ?? "HEAD")\n"
                    if s.isClean { output += "nothing to commit, working tree clean\n" }
                    for e in s.entries {
                        let st = e.isStaged ? "staged" : (e.isUntracked ? "untracked" : "modified")
                        output += "  \(st): \(e.path)\n"
                    }
                case "log":
                    let commits = try api.log(limit: 20)
                    for c in commits {
                        output += "\(c.oid.hex.prefix(8)) \(c.author.name) — \(c.summary.isEmpty ? c.message : c.summary)\n"
                    }
                case "branches", "branch":
                    let branches = try api.branches()
                    for b in branches {
                        output += "\(b.isCurrent ? "* " : "  ")\(b.name) (\(b.lastCommit.prefix(8)))\n"
                    }
                case "tags", "tag":
                    let tags = try api.tags()
                    for t in tags {
                        output += "tag \(t.name) -> \(t.oid.hex.prefix(8))\n"
                    }
                case "diff":
                    let diffs = try api.diff()
                    for d in diffs {
                        output += "\(d.patch ?? "\(d.status.rawValue) \(d.newPath)\n")\n"
                    }
                case "stashes", "stash":
                    let stashes = try api.stashes()
                    for s in stashes { output += "\(s.id): \(s.message)\n" }
                    if stashes.isEmpty { output += "No stashes recorded.\n" }
                case "snapshots", "snapshot":
                    let snaps = try api.snapshots()
                    for s in snaps { output += "\(s.oid.hex.prefix(8)): \(s.message) (\(s.kind))\n" }
                    if snaps.isEmpty { output += "No snapshots recorded.\n" }
                case "timeline":
                    let tl = try api.timeline(limit: 20)
                    for e in tl { output += "\(e.timestamp): \(e.title) — \(e.detail)\n" }
                case "doctor", "health":
                    let h = try api.health()
                    output = "Spaces Health Score: \(h.score)/100\n"
                    for issue in h.issues { output += "[\(issue.level.rawValue.uppercased())] \(issue.name): \(issue.detail)\n" }
                case "fsck":
                    let issues = try api.fsck()
                    output = issues.isEmpty ? "All repository objects verified. Repository is fully consistent.\n"
                        : issues.map { "\($0.severity.rawValue): \($0.message)" }.joined(separator: "\n") + "\n"
                case "gc":
                    let gc = try api.gc()
                    output = "Garbage collection complete: pruned \(gc.pruned) unreachable objects, \(gc.reachable) reachable objects retained.\n"
                case "info":
                    let info = try api.info()
                    output = "Path: \(info.path)\nFormat: spaces/\(info.formatVersion)\nBranch: \(info.branch ?? "—")\nObjects: \(info.objectCount)\nStorage: \(info.storageBytes) bytes\n"
                case "clean":
                    let removed = try api.clean()
                    output = "Cleaned \(removed.count) untracked items:\n" + removed.joined(separator: "\n") + "\n"
                default:
                    output = "spaces: unknown command '\(cmd)'\n"
                }
            } catch {
                output = "spaces: error: \(error.localizedDescription)\n"
            }
            await MainActor.run {
                self.consoleOutput += output
                self.isExecutingConsole = false
                self.refreshAll()
            }
        }
    }
}

struct SpacesWorkspaceView: View {
    @State private var model: SpacesWorkspaceModel
    @State private var pendingAction: PendingDestructiveAction?

    private enum PendingDestructiveAction: Identifiable {
        case deleteBranch(String)
        case deleteTag(String)
        case dropStash(String)
        case restoreSnapshot(String)
        case removeRemote(String)
        case discardFile(String)
        case cleanUntracked
        case forcePush

        var id: String {
            switch self {
            case .deleteBranch(let name): return "deleteBranch:\(name)"
            case .deleteTag(let name): return "deleteTag:\(name)"
            case .dropStash(let id): return "dropStash:\(id)"
            case .restoreSnapshot(let rev): return "restoreSnapshot:\(rev)"
            case .removeRemote(let name): return "removeRemote:\(name)"
            case .discardFile(let path): return "discardFile:\(path)"
            case .cleanUntracked: return "cleanUntracked"
            case .forcePush: return "forcePush"
            }
        }
    }

    private var pendingActionMessage: String {
        switch pendingAction {
        case .deleteBranch(let name): return "Delete the branch \(name)? This action cannot be reversed."
        case .deleteTag(let name): return "Delete the tag \(name)? This does not delete the tag on any remote."
        case .dropStash(let id): return "Drop the stash \(id)? Its changes will be lost."
        case .restoreSnapshot(let rev): return "Restore the snapshot \(rev)? The working tree returns to that checkpoint and uncommitted changes may be lost."
        case .removeRemote(let name): return "Remove the remote \(name)?"
        case .discardFile(let path): return "Discard all changes to \(path)? This cannot be reversed."
        case .cleanUntracked: return "Delete all untracked files? This cannot be reversed."
        case .forcePush: return "Force push the current branch (\(model.status?.branch ?? "HEAD"))? Remote history will be rewritten."
        case .none: return ""
        }
    }

    private func confirmPendingAction() {
        guard let action = pendingAction else { return }
        pendingAction = nil
        switch action {
        case .deleteBranch(let name): model.deleteBranch(name)
        case .deleteTag(let name): model.deleteTag(name)
        case .dropStash(let id): model.dropStash(id)
        case .restoreSnapshot(let rev): model.restoreSnapshot(rev)
        case .removeRemote(let name): model.removeRemote(name)
        case .discardFile(let path): model.restore(path)
        case .cleanUntracked: model.clean()
        case .forcePush: model.forcePush()
        }
    }

    init(project: Project) {
        _model = State(initialValue: SpacesWorkspaceModel(project: project))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HSplitView {
                sectionList
                detail
            }
        }
        .alert("Spaces", isPresented: Binding(
            get: { model.error != nil || model.notice != nil },
            set: { if !$0 { model.error = nil; model.notice = nil } }
        )) {
            Button("OK") { model.error = nil; model.notice = nil }
        } message: {
            Text(model.error ?? model.notice ?? "")
        }
        .alert("Confirm", isPresented: Binding(
            get: { pendingAction != nil },
            set: { if !$0 { pendingAction = nil } }
        )) {
            Button("Confirm", role: .destructive) { confirmPendingAction() }
            Button("Cancel", role: .cancel) { pendingAction = nil }
        } message: {
            Text(pendingActionMessage)
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "externaldrive.badge.checkmark")
                .foregroundStyle(Color.accentColor)
            Text("Spaces — Native Apple Source Control")
                .font(.headline)
            Spacer()
            if model.isBusy {
                ProgressView().controlSize(.small)
                Button("Cancel") { model.cancelOperations() }
                    .controlSize(.small)
            }
            Button {
                model.refreshAll()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .controlSize(.small)
            .disabled(model.isBusy)
            if let status = model.status {
                Text(status.branch ?? "HEAD")
                    .font(.caption.monospaced())
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(.quaternary, in: Capsule())
                if status.inMerge { badge("Merging", .orange) }
                if status.inRebase { badge("Rebasing", .orange) }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    private func badge(_ text: String, _ color: Color) -> some View {
        Text(text).font(.caption2.bold())
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.2), in: Capsule())
            .foregroundStyle(color)
    }

    private var sectionList: some View {
        List(SpacesWorkspaceModel.Section.allCases, selection: $model.section) { s in
            Text(s.rawValue).tag(s)
        }
        .listStyle(.sidebar)
        .frame(minWidth: 160, idealWidth: 180)
    }

    @ViewBuilder
    private var detail: some View {
        Group {
            if model.repo == nil {
                emptyState
            } else {
                switch model.section {
                case .overview: overview
                case .changes: changes
                case .branches: branchesView
                case .tags: tagsView
                case .compare: compareView
                case .search: searchView
                case .history: history
                case .operations: operations
                case .remotes: remotes
                case .maintenance: maintenance
                case .intelligence: SpacesIntelligenceView(workspace: model)
                case .reviews: SpacesReviewsView(workspace: model)
                case .security: SpacesSecurityView(workspace: model)
                case .storage: SpacesStorageView(workspace: model)
                case .migration: migration
                case .console: consoleView
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Spaces Repository", systemImage: "externaldrive")
        } description: {
            Text("This workspace does not yet have a native Spaces (.spaces/) repository. Initialize one to start tracking changes natively without Git.")
        } actions: {
            Button("Initialize Spaces Repository") { model.initialize() }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    

    private var overview: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                infoCard("Repository", [
                    ("Format", "spaces/\(RepositoryFormat.formatVersion)"),
                    ("Path", model.repo?.worktreeURL.path ?? ""),
                    ("Branch", model.status?.branch ?? "—"),
                    ("Status", model.status?.isClean == true ? "Clean" : "\(model.status?.entries.count ?? 0) modified files")
                ])
                if let counts = model.objectCounts {
                    infoCard("Object Store (Content-Addressable)", [
                        ("Blobs", "\(counts.blobs)"), ("Trees", "\(counts.trees)"),
                        ("Commits", "\(counts.commits)"), ("Tags", "\(counts.tags)"),
                        ("Snapshots", "\(counts.snapshots)"), ("Total Objects", "\(counts.total)")
                    ])
                }
                if let score = model.healthScore {
                    infoCard("Health & Diagnostics", [("Consistency Score", "\(score)/100")])
                }
                if !model.diagnostics.isEmpty {
                    infoCard("Diagnostic Notices", model.diagnostics.prefix(10).map { ($0, "") })
                }
            }
            .padding(20)
        }
    }

    private func infoCard(_ title: String, _ rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack {
                    Text(row.0).font(.caption).foregroundStyle(.secondary).frame(width: 140, alignment: .leading)
                    Text(row.1.isEmpty ? "—" : row.1).font(.callout.monospaced())
                    Spacer()
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
    }

    private var changes: some View {
        HSplitView {
            VStack(spacing: 0) {
                HStack {
                    Text("Working Tree Changes").font(.headline)
                    Spacer()
                    Button("Clean") { pendingAction = .cleanUntracked }
                        .controlSize(.small)
                    Button("Stage All") { model.stageAll() }
                        .controlSize(.small)
                }
                .padding(12)
                Divider()
                if let status = model.status, !status.entries.isEmpty {
                    List(status.entries, id: \.path) { entry in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(entry.path).font(.callout.monospaced())
                                HStack(spacing: 4) {
                                    if entry.isStaged { badge("staged", .green) }
                                    if entry.isUnstaged { badge("modified", .orange) }
                                    if entry.isUntracked { badge("untracked", .gray) }
                                    if let i = entry.indexStatus { badge("\(i.rawValue)+", .blue) }
                                }
                            }
                            Spacer()
                            if entry.isStaged {
                                Button("Unstage") { model.unstage(entry.path) }.controlSize(.small)
                            } else {
                                Button("Stage") { model.stage(entry.path) }.controlSize(.small)
                                Button("Discard") { pendingAction = .discardFile(entry.path) }
                                    .controlSize(.small)
                                    .foregroundStyle(.red)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            model.selectFile(entry.path)
                        }
                    }
                } else {
                    ContentUnavailableView("No Changes", systemImage: "checkmark.circle", description: Text("Working tree is completely clean."))
                }
                Divider()
                VStack(spacing: 8) {
                    HStack {
                        TextField("Commit message", text: $model.commitMessage)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { model.commit() }
                        Toggle("Amend", isOn: $model.isAmending)
                            .toggleStyle(.checkbox)
                            .controlSize(.small)
                        Button(model.isAmending ? "Amend Commit" : "Commit") { model.commit() }
                            .disabled(model.commitMessage.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .padding(12)
            }
            .frame(minWidth: 320)

            
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Label(model.selectedFilePath ?? "File Diff Inspector", systemImage: "doc.text.magnifyingglass")
                        .font(.headline)
                    Spacer()
                }
                .padding(12)
                Divider()
                if model.fileDiffLines.isEmpty {
                    ContentUnavailableView("Select a file", systemImage: "doc.text", description: Text("Select any modified file to inspect its unified diff."))
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(model.fileDiffLines.enumerated()), id: \.offset) { _, line in
                                Text(line)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(diffLineColor(line))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 1)
                                    .background(diffLineBackground(line))
                            }
                        }
                    }
                }
            }
            .frame(minWidth: 350)
        }
    }

    private func diffLineColor(_ line: String) -> Color {
        if line.hasPrefix("+") && !line.hasPrefix("+++") { return .green }
        if line.hasPrefix("-") && !line.hasPrefix("---") { return .red }
        if line.hasPrefix("@@") { return .blue }
        return .primary
    }

    private func diffLineBackground(_ line: String) -> Color {
        if line.hasPrefix("+") && !line.hasPrefix("+++") { return Color.green.opacity(0.08) }
        if line.hasPrefix("-") && !line.hasPrefix("---") { return Color.red.opacity(0.08) }
        return .clear
    }

    private var branchesView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Branches").font(.headline)
                Spacer()
                TextField("New branch", text: $model.newBranchName)
                    .textFieldStyle(.roundedBorder).frame(width: 160)
                Button("Create") { model.createBranch() }
                    .disabled(model.newBranchName.isEmpty)
            }
            .padding(12)
            Divider()
            List(model.branches, id: \.name) { b in
                HStack {
                    Text(b.name).font(.callout.monospaced())
                    if b.isCurrent { badge("current", .green) }
                    if b.isRemote { badge("remote", .gray) }
                    Spacer()
                    Text(b.lastCommit.prefix(8)).font(.caption).foregroundStyle(.secondary)
                    Button("Switch") { model.switchTo(b.name) }
                        .controlSize(.small)
                        .disabled(b.isCurrent)
                    Button("Delete") { pendingAction = .deleteBranch(b.name) }
                        .controlSize(.small)
                        .disabled(b.isCurrent)
                }
            }
        }
    }

    private var graphLaneSpans: [Int: (start: Int, end: Int)] {
        var spans: [Int: (start: Int, end: Int)] = [:]
        for (index, node) in model.graphNodes.enumerated() {
            if let span = spans[node.lane] {
                spans[node.lane] = (min(span.start, index), max(span.end, index))
            } else {
                spans[node.lane] = (index, index)
            }
        }
        return spans
    }

    private var graphMaxLane: Int { model.graphNodes.map(\.lane).max() ?? 0 }

    private var graphIndexByOID: [String: Int] {
        var map: [String: Int] = [:]
        for (index, node) in model.graphNodes.enumerated() { map[node.oid.hex] = index }
        return map
    }

    private var graphByOID: [String: BranchOps.GraphNode] {
        Dictionary(uniqueKeysWithValues: model.graphNodes.map { ($0.oid.hex, $0) })
    }

    private var history: some View {
        HSplitView {
            VStack(spacing: 0) {
                Text("Commit History").font(.headline).frame(maxWidth: .infinity, alignment: .leading).padding(12)
                Divider()
                List(model.commits, id: \.oid) { c in
                    HStack(spacing: 4) {
                        if let node = graphByOID[c.oid.hex], let rowIndex = graphIndexByOID[c.oid.hex] {
                            CommitGraphLaneView(node: node, rowIndex: rowIndex, laneSpans: graphLaneSpans, maxLane: graphMaxLane)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(c.summary.isEmpty ? c.message : c.summary).font(.callout)
                            HStack {
                                Text(c.oid.hex.prefix(8)).font(.caption.monospaced()).foregroundStyle(.secondary)
                                Text(c.author.name).font(.caption).foregroundStyle(.secondary)
                                if c.isMerge { badge("merge", .purple) }
                                ForEach(c.refs.prefix(3), id: \.self) { r in badge(r, .blue) }
                            }
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        model.selectCommit(c)
                    }
                }
            }
            .frame(minWidth: 320)

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Label(model.selectedCommit != nil ? "Commit \(model.selectedCommit!.oid.hex.prefix(8))" : "Commit Detail", systemImage: "clock")
                        .font(.headline)
                    Spacer()
                }
                .padding(12)
                Divider()
                if let commit = model.selectedCommit {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(commit.message).font(.headline)
                            HStack {
                                Text("Author: \(commit.author.name) <\(commit.author.email)>").font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                Text("SHA: \(commit.oid.hex)").font(.caption.monospaced()).foregroundStyle(.secondary)
                            }
                            Divider()
                            Text("Diff Patch:").font(.subheadline.bold())
                            Text(model.selectedCommitPatch.isEmpty ? "Loading patch..." : model.selectedCommitPatch)
                                .font(.system(.caption, design: .monospaced))
                                .padding(8)
                                .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                        }
                        .padding(12)
                    }
                } else {
                    ContentUnavailableView("Select a commit", systemImage: "clock.arrow.circlepath", description: Text("Click any commit in the list to inspect its metadata and diff patch."))
                }
            }
            .frame(minWidth: 350)
        }
    }

    private var operations: some View {
        Form {
            Section("Merge") {
                HStack {
                    TextField("Branch to merge", text: $model.mergeTarget)
                    Button("Merge") { model.merge() }.disabled(model.mergeTarget.isEmpty)
                }
                if let s = model.status, s.inMerge {
                    HStack {
                        Label("Merge in progress — resolve conflicts and continue.", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                        Spacer()
                        Button("Abort Merge") { model.mergeAbort() }
                        Button("Continue Merge") { model.mergeContinue() }
                    }
                }
            }
            Section("Rebase") {
                HStack {
                    TextField("Onto branch", text: $model.rebaseOnto)
                    Button("Rebase") { model.rebase() }.disabled(model.rebaseOnto.isEmpty)
                }
                if let s = model.status, s.inRebase {
                    HStack {
                        Label("Rebase in progress.", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                        Spacer()
                        Button("Abort") { model.rebaseAbort() }
                        Button("Skip") { model.rebaseSkip() }
                        Button("Continue") { model.rebaseContinue() }
                    }
                }
            }
            Section("Cherry-Pick") {
                HStack {
                    TextField("Commit SHA to cherry-pick", text: $model.cherryPickRev)
                    Button("Cherry-Pick") { model.cherryPick() }.disabled(model.cherryPickRev.isEmpty)
                }
            }
            Section("Stash Changes") {
                HStack {
                    TextField("Stash message (e.g. work in progress on login flow)", text: $model.stashMessage)
                    Button("Stash Current Changes") { model.stash(message: model.stashMessage) }
                        .disabled(model.stashMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                if !model.stashes.isEmpty {
                    ForEach(model.stashes, id: \.id) { s in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(s.message).font(.subheadline)
                                Text(s.id).font(.caption.monospaced()).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Apply") { model.applyStash(s.id, pop: false) }
                            Button("Pop") { model.applyStash(s.id, pop: true) }
                            Button("Drop") { pendingAction = .dropStash(s.id) }.foregroundStyle(.red)
                        }
                    }
                }
            }
            Section("Snapshots & Timeline") {
                HStack {
                    Button("Create Snapshot Checkpoint") { model.snapshot() }
                }
                if !model.snapshots.isEmpty {
                    ForEach(model.snapshots, id: \.oid) { snap in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(snap.message).font(.subheadline)
                                Text("\(snap.oid.hex.prefix(8)) • \(snap.kind)").font(.caption.monospaced()).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Restore") { pendingAction = .restoreSnapshot(snap.oid.hex) }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var remotes: some View {
        Form {
            Section("Remotes") {
                ForEach(model.remotes, id: \.name) { r in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(r.name).font(.headline)
                            Text(r.url).font(.caption.monospaced()).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Remove") { pendingAction = .removeRemote(r.name) }
                            .controlSize(.small)
                    }
                }
                HStack {
                    TextField("Name", text: $model.remoteName).frame(width: 100)
                    TextField("URL (.spaces path or spaces://…)", text: $model.remoteURL)
                    Button("Add") { model.addRemote() }.disabled(model.remoteURL.isEmpty)
                }
                HStack {
                    Button("Fetch") { model.fetch() }
                    Button("Pull") { model.pull() }
                    Button("Push") { model.push() }
                    Button("Force Push") { pendingAction = .forcePush }
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var tagsView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Tags").font(.headline)
                Spacer()
                TextField("New tag (e.g. v1.2.0)", text: $model.newTagName)
                    .textFieldStyle(.roundedBorder).frame(width: 140)
                TextField("Message (optional, empty makes a lightweight tag)", text: $model.newTagMessage)
                    .textFieldStyle(.roundedBorder).frame(width: 220)
                Button("Create") { model.createTag() }
                    .disabled(model.newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(12)
            Divider()
            if model.tags.isEmpty {
                ContentUnavailableView("No Tags", systemImage: "tag", description: Text("This repository has no tags yet."))
            } else {
                List(model.tags, id: \.name) { tag in
                    HStack {
                        Image(systemName: "tag.fill").foregroundStyle(.secondary)
                        Text(tag.name).font(.callout.monospaced())
                        if tag.isAnnotated { badge("annotated", .blue) }
                        Spacer()
                        Text(tag.oid.hex.prefix(8)).font(.caption).foregroundStyle(.secondary)
                        Button("Delete") { pendingAction = .deleteTag(tag.name) }
                            .controlSize(.small)
                    }
                }
            }
        }
    }

    private var compareView: some View {
        Form {
            Section("Compare Revisions") {
                HStack {
                    TextField("From (branch, tag, or SHA)", text: $model.compareFrom)
                    Text("vs")
                    TextField("To (branch, tag, or SHA)", text: $model.compareTo)
                    Button("Compare") { model.compare() }
                        .disabled(model.compareFrom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.compareTo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.compareFrom == model.compareTo || model.isBusy)
                }
                if model.compareOutput.isEmpty {
                    Text("Enter two revisions to see the unified diff between them.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(model.compareOutput.components(separatedBy: .newlines).enumerated()), id: \.offset) { _, line in
                                Text(line)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(diffLineColor(line))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 1)
                                    .background(diffLineBackground(line))
                            }
                        }
                    }
                    .frame(minHeight: 200)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            if model.compareFrom.isEmpty {
                model.compareFrom = model.status?.branch ?? "main"
            }
            if model.compareTo.isEmpty {
                model.compareTo = model.branches.first(where: { !$0.isCurrent })?.name ?? ""
            }
        }
    }

    private var searchView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Search").font(.headline)
                Spacer()
                TextField("Search files, commits, and content…", text: $model.searchQuery)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 320)
                    .onSubmit { model.search() }
                Button("Search") { model.search() }
                    .disabled(model.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isBusy)
            }
            .padding(12)
            Divider()
            if model.isBusy {
                ProgressView("Searching…")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else if model.searchResults.isEmpty {
                ContentUnavailableView(
                    model.hasSearched ? "No Results" : "Search this Repository",
                    systemImage: "magnifyingglass",
                    description: Text(model.hasSearched ? "Nothing matched \"\(model.searchQuery)\"." : "Search file names, commit messages, and file contents across the Spaces history.")
                )
            } else {
                List(Array(model.searchResults.enumerated()), id: \.offset) { _, result in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            badge(result.kind.rawValue, .blue)
                            Text(result.title).font(.callout)
                            Spacer()
                            if let line = result.line {
                                Text("line \(line)").font(.caption.monospaced()).foregroundStyle(.secondary)
                            }
                        }
                        if !result.detail.isEmpty {
                            Text(result.detail).font(.caption).foregroundStyle(.secondary)
                        }
                        if let path = result.path {
                            Text(path).font(.caption.monospaced()).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var maintenance: some View {
        Form {
            Section("Integrity & Housekeeping") {
                HStack {
                    Button("Run fsck") { model.refreshMaintenance() }
                    Button("Garbage Collect") { model.gc() }
                    Button("Rebuild Index") { model.rebuildIndex() }
                    Button("Clean Untracked") { model.clean() }
                }
                if !model.fsckIssues.isEmpty {
                    ForEach(Array(model.fsckIssues.enumerated()), id: \.offset) { _, issue in
                        Label("\(issue.severity.rawValue): \(issue.message)", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                } else {
                    Label("No integrity issues found. All objects and refs verified.", systemImage: "checkmark.seal")
                        .foregroundStyle(.green)
                }
            }
            Section("Worktrees") {
                ForEach((try? model.api?.worktrees()) ?? [], id: \.path) { wt in
                    LabeledContent(URL(fileURLWithPath: wt.path).lastPathComponent, value: wt.head)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var migration: some View {
        Form {
            Section("Import from Git") {
                TextField("Git repository path", text: $model.gitPath)
                Button("Import Git Repository") { model.importGit() }
                    .disabled(model.gitPath.isEmpty)
                Text("Reads objects, refs, branches and tags from an existing git repository into native .spaces/ storage.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Export to Git") {
                TextField("Destination directory", text: $model.exportPath)
                Button("Export as Git Repository") { model.exportGit() }
                    .disabled(model.exportPath.isEmpty)
                Text("Exports a native .spaces/ repository into a standard .git repository at the destination.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var consoleView: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Spaces Native CLI Console", systemImage: "terminal")
                    .font(.headline)
                Spacer()
                if model.isExecutingConsole {
                    ProgressView().controlSize(.small)
                }
            }
            .padding(12)
            Divider()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(["status", "log", "diff", "branches", "tags", "stashes", "snapshots", "timeline", "doctor", "health", "fsck", "gc", "info", "clean"], id: \.self) { cmd in
                        Button(cmd) {
                            model.executeConsole(cmd)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(model.isExecutingConsole)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            Divider()

            ScrollView {
                Text(model.consoleOutput)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .background(Color.black.opacity(0.85))
            .foregroundStyle(Color.green)

            Divider()
            HStack {
                Text("spaces")
                    .font(.system(.body, design: .monospaced).bold())
                    .foregroundStyle(.secondary)
                TextField("e.g. status, log, diff, health...", text: $model.consoleInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onSubmit { model.executeConsole() }
                    .disabled(model.isExecutingConsole)
                Button("Run") { model.executeConsole() }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.consoleInput.trimmingCharacters(in: .whitespaces).isEmpty || model.isExecutingConsole)
            }
            .padding(12)
        }
    }
}

private struct CommitGraphLaneView: View {
    let node: BranchOps.GraphNode
    let rowIndex: Int
    let laneSpans: [Int: (start: Int, end: Int)]
    let maxLane: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0...maxLane, id: \.self) { lane in
                ZStack {
                    if let span = laneSpans[lane], rowIndex >= span.start, rowIndex <= span.end {
                        Rectangle().fill(Color.secondary.opacity(0.5)).frame(width: 1.5)
                    }
                    if lane == node.lane {
                        Circle()
                            .fill(node.parents.count > 1 ? Color.purple : Color.accentColor)
                            .frame(width: 8, height: 8)
                    }
                }
                .frame(width: 12)
            }
        }
    }
}
