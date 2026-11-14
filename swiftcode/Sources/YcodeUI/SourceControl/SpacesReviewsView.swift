import Foundation
import SwiftUI
import SpacesEngine

@Observable
@MainActor
final class SpacesReviewsModel {
    let workspace: SpacesWorkspaceModel
    var error: String?
    var notice: String?
    var reviews: [ReviewOps.Review] = []
    var selectedReview: ReviewOps.Review?
    var reviewStatus: ReviewOps.Status?
    var comments: [DiscussionOps.Comment] = []
    var changesSinceApproval: [String] = []
    var mergeAllowed: Bool?
    var mergeReasons: [String] = []
    var newTitle = ""
    var newBase = "main"
    var newHead = "HEAD"
    var reviewerName = NSUserName()
    var commentPath = ""
    var commentLine = 1
    var commentBody = ""
    var editCommentBody = ""
    var policy: ReviewPolicyOps.Policy?
    var policyRequiredApprovals = 1
    var policyRequireValidation = false
    var policyRequiredReviewers = ""
    var activity: [ActivityFeedOps.Event] = []
    var ownershipRules: [OwnershipOps.Rule] = []
    var ownershipPattern = ""
    var ownershipOwners = ""
    var ownersLookupPath = ""
    var ownersLookupResult: [String] = []
    var templates: [WorkspaceTemplateOps.Template] = []
    var templateName = ""
    var templateBranch = "main"
    var sessionPaths = ""
    var session: ConflictSessionOps.Session?
    var sessionStatus: ConflictSessionOps.SessionStatus?
    var claimPath = ""
    var claimOwner = ""
    var resolutionPath = ""
    var resolutionText = ""
    var crossChangeId = ""
    var crossBranches = ""
    var crossStatuses: [CrossBranchOps.BranchStatus] = []
    var notificationRules: [NotificationOps.Rule] = []
    var pendingNotifications: [NotificationOps.PendingNotification] = []

    init(workspace: SpacesWorkspaceModel) {
        self.workspace = workspace
    }

    func refreshAll() {
        loadReviews()
        loadPolicy()
        loadActivity()
        loadOwnershipRules()
        loadTemplates()
        loadNotificationRules()
        loadPendingNotifications()
    }

    private func load<T: Sendable>(_ what: String, _ body: @escaping @Sendable (SpacesAPI) throws -> T, assign: @escaping @MainActor @Sendable (T) -> Void) {
        guard let api = workspace.api else { return }
        Task.detached {
            do {
                let value = try body(api)
                await MainActor.run { assign(value) }
            } catch {
                await MainActor.run { self.error = "\(what): \(error.localizedDescription)" }
            }
        }
    }

    private func perform(_ what: String, _ body: @escaping @Sendable (SpacesAPI) throws -> Void) {
        guard let api = workspace.api else { return }
        Task.detached {
            do { try body(api) } catch {
                await MainActor.run { self.error = "\(what): \(error.localizedDescription)" }
            }
            await MainActor.run { self.refreshAll() }
        }
    }

    func loadReviews() {
        load("reviews", { try $0.listReviews() }, assign: { self.reviews = $0 })
    }

    func loadPolicy() {
        load("review policy", { try $0.reviewPolicy() }, assign: { policy in
            self.policy = policy
            self.policyRequiredApprovals = policy.requiredApprovals
            self.policyRequireValidation = policy.requireValidation
            self.policyRequiredReviewers = policy.requiredReviewers.joined(separator: ", ")
        })
    }

    func loadActivity() {
        load("activity feed", { try $0.activityFeed(limit: 50) }, assign: { self.activity = $0 })
    }

    func loadOwnershipRules() {
        load("ownership rules", { try $0.ownershipRules() }, assign: { self.ownershipRules = $0 })
    }

    func loadTemplates() {
        load("workspace templates", { try $0.workspaceTemplates() }, assign: { self.templates = $0 })
    }

    func loadNotificationRules() {
        load("notification rules", { try $0.notificationRules() }, assign: { self.notificationRules = $0 })
    }

    func loadPendingNotifications() {
        load("pending notifications", { try $0.pendingNotifications() }, assign: { self.pendingNotifications = $0 })
    }

    func selectReview(_ review: ReviewOps.Review) {
        selectedReview = review
        let id = review.id
        load("review status", { try $0.reviewStatus(id: id) }, assign: { self.reviewStatus = $0 })
        load("comments", { try $0.listComments(review: id) }, assign: { self.comments = $0 })
        load("changes since approval", { try $0.changesSinceApproval(review: id) }, assign: { self.changesSinceApproval = $0 })
        load("review merge check", { try $0.reviewMergeCheck(id: id) }, assign: { check in
            self.mergeAllowed = check.allowed
            self.mergeReasons = check.reasons
        })
    }

    func createReview() {
        let title = newTitle
        let base = newBase
        let head = newHead
        guard !title.isEmpty, !base.isEmpty, !head.isEmpty else {
            error = "create review: title, base, and head are all required"
            return
        }
        perform("create review") { _ = try $0.createReview(title: title, base: base, head: head) }
        newTitle = ""
    }

    func approveSelected() {
        guard let review = selectedReview else {
            error = "approve review: select a review first"
            return
        }
        let id = review.id
        let reviewer = reviewerName
        perform("approve review") { _ = try $0.approveReview(id: id, reviewer: reviewer) }
    }

    func addComment() {
        guard let review = selectedReview else {
            error = "add comment: select a review first"
            return
        }
        let id = review.id
        let path = commentPath
        let line = commentLine
        let body = commentBody
        guard !path.isEmpty, !body.isEmpty else {
            error = "add comment: path and body are both required"
            return
        }
        perform("add comment") { _ = try $0.addComment(review: id, path: path, line: line, body: body) }
        commentBody = ""
    }

    func resolveComment(_ comment: DiscussionOps.Comment) {
        guard let review = selectedReview else { return }
        let reviewId = review.id
        let commentId = comment.id
        perform("resolve comment") { _ = try $0.resolveComment(review: reviewId, id: commentId) }
    }

    func editSelectedComment(_ comment: DiscussionOps.Comment) {
        guard let review = selectedReview else { return }
        let reviewId = review.id
        let commentId = comment.id
        let body = editCommentBody
        guard !body.isEmpty else {
            error = "edit comment: enter the replacement body first"
            return
        }
        perform("edit comment") { _ = try $0.editComment(review: reviewId, id: commentId, body: body) }
        editCommentBody = ""
    }

    func savePolicy() {
        let approvals = policyRequiredApprovals
        let requireValidation = policyRequireValidation
        let reviewers = policyRequiredReviewers.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let policy = ReviewPolicyOps.Policy(requiredApprovals: approvals, requiredReviewers: reviewers, requireValidation: requireValidation)
        perform("save review policy") { try $0.setReviewPolicy(policy) }
    }

    func addOwnershipRule() {
        let pattern = ownershipPattern
        let owners = ownershipOwners.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard !pattern.isEmpty, !owners.isEmpty else {
            error = "ownership rule: pattern and at least one owner are required"
            return
        }
        var rules = ownershipRules
        rules.append(OwnershipOps.Rule(pattern: pattern, owners: owners))
        perform("save ownership rules") { try $0.setOwnershipRules(rules) }
        ownershipPattern = ""
        ownershipOwners = ""
    }

    func lookupOwners() {
        let path = ownersLookupPath
        guard !path.isEmpty else {
            error = "owners lookup: enter a path first"
            return
        }
        load("owners of path", { try $0.ownersOf(path: path) }, assign: { self.ownersLookupResult = $0 })
    }

    func createTemplate() {
        let name = templateName
        let branch = templateBranch
        guard !name.isEmpty else {
            error = "workspace template: enter a template name first"
            return
        }
        let config = WorkspaceTemplateOps.Config(defaultBranch: branch, reviewPolicy: policy ?? ReviewPolicyOps.Policy(), ownershipRules: ownershipRules, ignorePatterns: [])
        perform("create workspace template") { _ = try $0.createWorkspaceTemplate(name: name, config: config) }
        templateName = ""
    }

    func applyTemplate(_ template: WorkspaceTemplateOps.Template) {
        let name = template.name
        perform("apply workspace template") { try $0.applyWorkspaceTemplate(name: name) }
    }

    func createSession() {
        let paths = sessionPaths.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard !paths.isEmpty else {
            error = "conflict session: enter at least one path first"
            return
        }
        guard let api = workspace.api else { return }
        Task.detached {
            do {
                let created = try api.createSession(paths: paths)
                await MainActor.run {
                    self.session = created
                    self.notice = "Conflict session \(created.id) created"
                }
            } catch {
                await MainActor.run { self.error = "create session: \(error.localizedDescription)" }
            }
        }
    }

    func claimSessionPath() {
        guard let current = session else {
            error = "claim path: create a conflict session first"
            return
        }
        let id = current.id
        let path = claimPath
        let owner = claimOwner
        guard !path.isEmpty, !owner.isEmpty else {
            error = "claim path: path and owner are both required"
            return
        }
        perform("claim path") { _ = try $0.claimPath(session: id, path: path, owner: owner) }
    }

    func recordSessionResolution() {
        guard let current = session else {
            error = "record resolution: create a conflict session first"
            return
        }
        let id = current.id
        let path = resolutionPath
        let resolution = resolutionText
        guard !path.isEmpty, !resolution.isEmpty else {
            error = "record resolution: path and resolution are both required"
            return
        }
        perform("record resolution") { _ = try $0.recordResolution(session: id, path: path, resolution: resolution) }
    }

    func refreshSessionStatus() {
        guard let current = session else {
            error = "session status: create a conflict session first"
            return
        }
        let id = current.id
        load("session status", { try $0.sessionStatus(session: id) }, assign: { self.sessionStatus = $0 })
    }

    func trackCrossBranch() {
        let changeId = crossChangeId
        let branches = crossBranches.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard !changeId.isEmpty, !branches.isEmpty else {
            error = "cross-branch tracking: change id and at least one branch are required"
            return
        }
        guard let api = workspace.api else { return }
        Task.detached {
            do {
                _ = try api.trackChangeAcrossBranches(changeId: changeId, branches: branches)
                let statuses = try api.crossBranchStatus(changeId: changeId)
                await MainActor.run { self.crossStatuses = statuses }
            } catch {
                await MainActor.run { self.error = "track change across branches: \(error.localizedDescription)" }
            }
        }
    }

    func toggleNotificationRule(_ rule: NotificationOps.Rule) {
        var rules = notificationRules
        if let index = rules.firstIndex(where: { $0.event == rule.event }) {
            rules[index] = NotificationOps.Rule(event: rule.event, enabled: !rule.enabled)
            let updated = rules
            perform("save notification rules") { try $0.setNotificationRules(updated) }
        }
    }

    func markNotificationsSeen() {
        perform("mark notifications seen") { try $0.markNotificationsSeen() }
    }

    static func dateString(_ timestamp: Int64) -> String {
        Date(timeIntervalSince1970: TimeInterval(timestamp)).formatted(date: .abbreviated, time: .shortened)
    }
}

struct SpacesReviewsView: View {
    @State private var model: SpacesReviewsModel

    init(workspace: SpacesWorkspaceModel) {
        _model = State(initialValue: SpacesReviewsModel(workspace: workspace))
    }

    var body: some View {
        Form {
            if let error = model.error {
                Section {
                    HStack {
                        Text(error).foregroundStyle(.red)
                        Spacer()
                        Button("Dismiss") { model.error = nil }
                    }
                }
            }
            if let notice = model.notice {
                Section {
                    HStack {
                        Text(notice)
                        Spacer()
                        Button("Dismiss") { model.notice = nil }
                    }
                }
            }
            Section("New Review") {
                TextField("Title", text: $model.newTitle)
                HStack {
                    TextField("Base", text: $model.newBase)
                    TextField("Head", text: $model.newHead)
                }
                Button("Create Review") { model.createReview() }
                    .disabled(model.newTitle.isEmpty)
            }
            Section("Reviews") {
                if model.reviews.isEmpty {
                    Text("No reviews yet.").font(.caption).foregroundStyle(.secondary)
                }
                ForEach(Array(model.reviews.enumerated()), id: \.offset) { _, review in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(review.title).font(.subheadline)
                            Text("\(review.baseRev) → \(review.headRev) • \(review.author) • \(SpacesReviewsModel.dateString(review.created))")
                                .font(.caption).foregroundStyle(.secondary)
                            Text("\(review.approvals.count) approvals")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(review.status.rawValue).font(.caption)
                        Button("Select") { model.selectReview(review) }
                            .controlSize(.small)
                    }
                }
            }
            if let review = model.selectedReview {
                Section("Selected Review: \(review.title)") {
                    HStack {
                        Text("Status: \(model.reviewStatus?.rawValue ?? review.status.rawValue)")
                        Spacer()
                        if let allowed = model.mergeAllowed {
                            Text(allowed ? "Merge allowed" : "Merge blocked")
                                .foregroundStyle(allowed ? .green : .orange)
                        }
                    }
                    ForEach(Array(model.mergeReasons.enumerated()), id: \.offset) { _, reason in
                        Text(reason).font(.caption).foregroundStyle(.secondary)
                    }
                    if !model.changesSinceApproval.isEmpty {
                        Text("Changed since approval: \(model.changesSinceApproval.joined(separator: ", "))")
                            .font(.caption).foregroundStyle(.orange)
                    }
                    HStack {
                        TextField("Reviewer", text: $model.reviewerName)
                        Button("Approve") { model.approveSelected() }
                    }
                    Section("Comments") {
                        HStack {
                            TextField("Path", text: $model.commentPath)
                            TextField("Line", value: $model.commentLine, format: .number)
                                .frame(width: 70)
                        }
                        TextField("Comment body", text: $model.commentBody)
                        Button("Add Comment") { model.addComment() }
                            .disabled(model.commentBody.isEmpty)
                        ForEach(Array(model.comments.enumerated()), id: \.offset) { _, comment in
                            VStack(alignment: .leading) {
                                HStack {
                                    Text("\(comment.path):\(comment.line)").font(.caption.monospaced())
                                    Text(comment.author).font(.caption).foregroundStyle(.secondary)
                                    Spacer()
                                    Text(comment.resolved ? "resolved" : "open").font(.caption)
                                }
                                Text(comment.body).font(.subheadline)
                                HStack {
                                    TextField("Replacement body", text: $model.editCommentBody)
                                    Button("Save Edit") { model.editSelectedComment(comment) }
                                        .controlSize(.small)
                                    if !comment.resolved {
                                        Button("Resolve") { model.resolveComment(comment) }
                                            .controlSize(.small)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            Section("Review Policy") {
                Stepper("Required approvals: \(model.policyRequiredApprovals)", value: $model.policyRequiredApprovals, in: 0...10)
                Toggle("Require validation", isOn: $model.policyRequireValidation)
                TextField("Required reviewers (comma separated)", text: $model.policyRequiredReviewers)
                Button("Save Review Policy") { model.savePolicy() }
            }
            Section("Activity Feed") {
                Button("Refresh Activity") { model.loadActivity() }
                ForEach(Array(model.activity.enumerated()), id: \.offset) { _, event in
                    HStack {
                        Text(event.message).font(.subheadline)
                        Spacer()
                        Text(event.type).font(.caption).foregroundStyle(.secondary)
                        Text(SpacesReviewsModel.dateString(event.timestamp)).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Section("Ownership") {
                HStack {
                    TextField("Pattern", text: $model.ownershipPattern)
                    TextField("Owners (comma separated)", text: $model.ownershipOwners)
                    Button("Add Rule") { model.addOwnershipRule() }
                        .disabled(model.ownershipPattern.isEmpty)
                }
                ForEach(Array(model.ownershipRules.enumerated()), id: \.offset) { _, rule in
                    Text("\(rule.pattern): \(rule.owners.joined(separator: ", "))").font(.callout.monospaced())
                }
                HStack {
                    TextField("Path to look up", text: $model.ownersLookupPath)
                    Button("Owners Of") { model.lookupOwners() }
                        .disabled(model.ownersLookupPath.isEmpty)
                }
                if !model.ownersLookupResult.isEmpty {
                    Text("Owners: \(model.ownersLookupResult.joined(separator: ", "))").font(.caption)
                }
            }
            Section("Workspace Templates") {
                HStack {
                    TextField("Template name", text: $model.templateName)
                    TextField("Default branch", text: $model.templateBranch)
                    Button("Create Template") { model.createTemplate() }
                        .disabled(model.templateName.isEmpty)
                }
                ForEach(Array(model.templates.enumerated()), id: \.offset) { _, template in
                    HStack {
                        Text(template.name).font(.subheadline)
                        Text("branch \(template.defaultBranch)").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("Apply") { model.applyTemplate(template) }
                            .controlSize(.small)
                    }
                }
            }
            Section("Conflict Sessions") {
                TextField("Paths (comma separated)", text: $model.sessionPaths)
                Button("Create Session") { model.createSession() }
                    .disabled(model.sessionPaths.isEmpty)
                if let session = model.session {
                    Text("Session \(session.id) — \(session.paths.count) paths")
                        .font(.caption)
                    HStack {
                        TextField("Path to claim", text: $model.claimPath)
                        TextField("Owner", text: $model.claimOwner)
                        Button("Claim") { model.claimSessionPath() }
                            .disabled(model.claimPath.isEmpty)
                    }
                    HStack {
                        TextField("Path", text: $model.resolutionPath)
                        TextField("Resolution", text: $model.resolutionText)
                        Button("Record Resolution") { model.recordSessionResolution() }
                            .disabled(model.resolutionPath.isEmpty)
                    }
                    HStack {
                        Button("Refresh Status") { model.refreshSessionStatus() }
                        if let status = model.sessionStatus {
                            Text("\(status.claimed)/\(status.total) claimed, \(status.resolved) resolved")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Section("Cross-Branch Tracking") {
                HStack {
                    TextField("Change id", text: $model.crossChangeId)
                    TextField("Branches (comma separated)", text: $model.crossBranches)
                    Button("Track") { model.trackCrossBranch() }
                        .disabled(model.crossChangeId.isEmpty)
                }
                ForEach(Array(model.crossStatuses.enumerated()), id: \.offset) { _, status in
                    HStack {
                        Text(status.branch).font(.callout.monospaced())
                        Spacer()
                        Text(status.status.rawValue).font(.caption)
                        Text(status.headRev).font(.caption.monospaced()).foregroundStyle(.secondary)
                    }
                }
            }
            Section("Notifications") {
                ForEach(Array(model.notificationRules.enumerated()), id: \.offset) { _, rule in
                    HStack {
                        Text(rule.event.rawValue).font(.subheadline)
                        Spacer()
                        Text(rule.enabled ? "enabled" : "disabled").font(.caption).foregroundStyle(.secondary)
                        Button(rule.enabled ? "Disable" : "Enable") { model.toggleNotificationRule(rule) }
                            .controlSize(.small)
                    }
                }
                Button("Mark All Seen") { model.markNotificationsSeen() }
                ForEach(Array(model.pendingNotifications.enumerated()), id: \.offset) { _, notification in
                    HStack {
                        Text(notification.message).font(.subheadline)
                        Spacer()
                        Text(notification.event.rawValue).font(.caption).foregroundStyle(.secondary)
                        Text(SpacesReviewsModel.dateString(notification.timestamp)).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { model.refreshAll() }
    }
}
