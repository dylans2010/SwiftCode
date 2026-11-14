import SwiftUI
import SwiftCodeGitHub
import YcodeIDECore

@MainActor
struct GitHubIssuesView: View {
    let project: Project?
    @Binding var showSuccess: Bool
    @Binding var successMessage: String?
    @Binding var showError: Bool
    @Binding var errorMessage: String?

    @State private var issues: [GitHubIssue] = []
    @State private var isLoading = false
    @State private var searchPattern = ""
    @State private var filterState = "open"
    @State private var showCreateIssue = false
    @State private var selectedIssue: GitHubIssue?

    @State private var selectedIssueIDs: Set<Int> = []

    @State private var newTitle = ""
    @State private var newBody = ""
    @State private var selectedLabel = "bug"
    @State private var milestones: [GitHubMilestone] = []
    @State private var selectedMilestoneNumber: Int?
    @State private var selectedAssignee = "" 

    private var context: RepositoryContext {
        RepositoryContext.shared
    }

    private var ownerAndRepo: (String, String)? {
        guard let repoStr = context.connectedRepository, !repoStr.isEmpty else { return nil }
        let parts = repoStr.split(separator: "/")
        guard parts.count == 2 else { return nil }
        return (String(parts[0]), String(parts[1]))
    }

    var body: some View {
        VStack(spacing: 0) {
            if context.displayMode == .connectedRepository && context.connectedRepository == nil {
                disconnectedPlaceholder
            } else {
                mainContent
            }
        }
        .onAppear {
            fetchIssues()
        }
        .onChange(of: context.displayMode) {
            fetchIssues()
        }
        .onChange(of: context.syncEventsCount) {
            fetchIssues()
        }
        .sheet(isPresented: $showCreateIssue) {
            createIssueSheet
                .task { await loadMilestones() }
        }
        .sheet(item: $selectedIssue) { issue in
            if let (owner, repo) = ownerAndRepo {
                IssueDetailView(issue: issue, owner: owner, repo: repo)
            } else {
                Text("No repository is linked to this issue.")
                    .padding()
            }
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search issues...", text: $searchPattern)
                        .textFieldStyle(.plain)
                }
                .padding(6)
                .background(Color.secondary.opacity(0.12))
                .cornerRadius(6)

                Picker("State", selection: $filterState) {
                    Text("Open").tag("open")
                    Text("Closed").tag("closed")
                    Text("All").tag("all")
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
                .onChange(of: filterState) {
                    fetchIssues()
                }

                Button {
                    fetchIssues()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoading)

                Button {
                    showCreateIssue = true
                } label: {
                    Label("New Issue", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.accentColor)
                .disabled(context.connectedRepository == nil)
            }
            .padding()
            .liquidGlass(style: .subtle, cornerRadius: 10)

            Divider()

            if isLoading {
                GitHubLoadingView(message: "Loading issues...")
            } else if issues.isEmpty {
                GitHubEmptyStateView(
                    title: "No Issues Open",
                    description: "No issues match your filter criteria. Create one now!",
                    systemImage: "exclamationmark.bubble",
                    accentColor: Color.accentColor,
                    actionTitle: "Create Issue"
                ) {
                    showCreateIssue = true
                }
                .disabled(context.connectedRepository == nil)
            } else {
                let filtered = processedIssues

                if filtered.isEmpty {
                    ContentUnavailableView.search(text: searchPattern)
                } else {
                    List {
                        Section("Repository Issue Register") {
                            ForEach(filtered) { issue in
                                Button {
                                    selectedIssue = issue
                                } label: {
                                    HStack(spacing: 16) {
                                        Button {
                                            if selectedIssueIDs.contains(issue.id) {
                                                selectedIssueIDs.remove(issue.id)
                                            } else {
                                                selectedIssueIDs.insert(issue.id)
                                            }
                                        } label: {
                                            Image(systemName: selectedIssueIDs.contains(issue.id) ? "checkmark.square.fill" : "square")
                                                .foregroundStyle(selectedIssueIDs.contains(issue.id) ? Color.accentColor : .secondary)
                                        }
                                        .buttonStyle(.plain)

                                        Image(systemName: issue.state == "open" ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                                            .foregroundStyle(issue.state == "open" ? Color.accentColor : .secondary)
                                            .font(.title3)

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(issue.title)
                                                .font(.subheadline.bold())
                                                .foregroundStyle(.primary)

                                            HStack(spacing: 8) {
                                                Text("#\(issue.number)")
                                                    .font(.caption)
                                                    .bold()
                                                    .foregroundStyle(.secondary)

                                                Text("opened by \(issue.userLogin) on \(issue.createdAt?.formatted(date: .abbreviated, time: .shortened) ?? "unknown date")")
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)

                                                ForEach(issue.labels.prefix(3), id: \.self) { label in
                                                    Text(label)
                                                        .font(.system(size: 8, weight: .bold))
                                                        .padding(.horizontal, 4)
                                                        .padding(.vertical, 1)
                                                        .background(Color.secondary.opacity(0.12))
                                                        .foregroundStyle(.secondary)
                                                        .cornerRadius(3)
                                                }
                                            }
                                        }

                                        Spacer()

                                        Text(issue.state.uppercased())
                                            .font(.system(size: 8, weight: .bold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(issue.state == "open" ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.12))
                                            .foregroundStyle(issue.state == "open" ? Color.accentColor : .secondary)
                                            .cornerRadius(4)
                                    }
                                }
                                .buttonStyle(.plain)
                                .padding(.vertical, 6)
                                Divider()
                            }
                        }

                        if !selectedIssueIDs.isEmpty {
                            Section("Bulk Commands Panel") {
                                HStack {
                                    Text("\(selectedIssueIDs.count) issues selected")
                                        .font(.subheadline.bold())
                                    Spacer()
                                    Button {
                                        executeBulkClose()
                                    } label: {
                                        Label("Close Selected Issues", systemImage: "xmark.circle")
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(Color.accentColor)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
        }
    }

    private var processedIssues: [GitHubIssue] {
        var list = issues
        if !searchPattern.isEmpty {
            list = list.filter {
                $0.title.localizedCaseInsensitiveContains(searchPattern) ||
                ($0.body ?? "").localizedCaseInsensitiveContains(searchPattern)
            }
        }
        return list
    }

    private var disconnectedPlaceholder: some View {
        GitHubEmptyStateView(
            title: "No Repository Associated",
            description: "A GitHub repository must first be associated with this project to view and manage Issues.",
            systemImage: "exclamationmark.circle",
            accentColor: Color.accentColor,
            actionTitle: "Configure Repository Association"
        ) {
            RepositoryContext.shared.showingSetRepoSheet = true
        }
    }

    private var createIssueSheet: some View {
        VStack(spacing: 20) {
            HStack {
                Label("New Issue Specification", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)
                Spacer()
                Button("Cancel") {
                    showCreateIssue = false
                }
                .buttonStyle(.bordered)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Issue Title").font(.caption.bold())
                    TextField("Title", text: $newTitle)
                        .textFieldStyle(.roundedBorder)

                    Text("Labels").font(.caption.bold())
                    Picker("Labels", selection: $selectedLabel) {
                        Text("bug").tag("bug")
                        Text("enhancement").tag("enhancement")
                        Text("documentation").tag("documentation")
                    }
                    .pickerStyle(.segmented)

                    if !milestones.isEmpty {
                        Text("Milestone").font(.caption.bold())
                        Picker("Milestone", selection: $selectedMilestoneNumber) {
                            Text("None").tag(nil as Int?)
                            ForEach(milestones) { milestone in
                                Text(milestone.title).tag(milestone.number as Int?)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    Text("Assignee").font(.caption.bold())
                    TextField("GitHub username (optional)", text: $selectedAssignee)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()

                    Text("Description").font(.caption.bold())
                    TextEditor(text: $newBody)
                        .frame(height: 120)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                }
                .padding()
            }

            Button {
                submitIssue()
            } label: {
                Text("Submit New Issue")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.accentColor)
            .disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(24)
        .frame(width: 480, height: 520)
    }

    private func loadMilestones() async {
        guard let (owner, repo) = ownerAndRepo else { return }
        milestones = (try? await GitHubTokenProvider.service().listMilestones(owner: owner, repo: repo)) ?? []
    }

    private func fetchIssues() {
        isLoading = true
        Task {
            do {
                if context.displayMode == .entireAccount {
                    let query = filterState == "all" ? "is:issue" : "is:issue is:\(filterState)"
                    let result = try await GitHubTokenProvider.service().searchIssues(query: query)
                    self.issues = result.items.filter { !$0.isPullRequest }
                } else if let (owner, repo) = ownerAndRepo {
                    self.issues = try await GitHubTokenProvider.service().listIssues(owner: owner, repo: repo, state: filterState)
                } else {
                    issues = []
                }
            } catch {
                errorMessage = "Failed to load issues: \(error.localizedDescription)"
                showError = true
            }
            isLoading = false
        }
    }


    private func submitIssue() {
        guard let (owner, repo) = ownerAndRepo else { return }
        let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = newBody.trimmingCharacters(in: .whitespacesAndNewlines)
        let assignee = selectedAssignee.trimmingCharacters(in: .whitespacesAndNewlines)
        let milestoneNumber = selectedMilestoneNumber
        Task {
            do {
                let created = try await GitHubTokenProvider.service().createIssue(
                    owner: owner, repo: repo, title: title,
                    body: body.isEmpty ? nil : body, labels: [selectedLabel])
                if let milestoneNumber {
                    try? await GitHubTokenProvider.service().updateIssueMilestone(
                        owner: owner, repo: repo, number: created.number, milestoneNumber: milestoneNumber)
                }
                if !assignee.isEmpty {
                    try? await GitHubTokenProvider.service().addIssueAssignees(
                        owner: owner, repo: repo, number: created.number, assignees: [assignee])
                }
                newTitle = ""
                newBody = ""
                selectedAssignee = ""
                selectedMilestoneNumber = nil
                showCreateIssue = false
                fetchIssues()
            } catch {
                errorMessage = "Failed to create: \(error.localizedDescription)"
                showError = true
            }
        }
    }


    private func executeBulkClose() {
        guard let (owner, repo) = ownerAndRepo else { return }
        isLoading = true
        let idsToClose = selectedIssueIDs
        Task {
            do {
                for issueID in idsToClose {
                    guard let issue = issues.first(where: { $0.id == issueID }) else { continue }
                    _ = try await GitHubTokenProvider.service().updateIssue(
                        owner: owner, repo: repo, number: issue.number, state: "closed")
                }
                successMessage = "Successfully closed selected issues on GitHub!"
                showSuccess = true
                selectedIssueIDs.removeAll()
                fetchIssues()
            } catch {
                errorMessage = "Failed to bulk close: \(error.localizedDescription)"
                showError = true
            }
            isLoading = false
        }
    }
}
