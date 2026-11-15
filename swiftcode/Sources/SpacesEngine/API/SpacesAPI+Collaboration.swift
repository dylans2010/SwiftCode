import Foundation

extension SpacesAPI {

    @discardableResult
    public func createReview(title: String, base: String,
                             head: String) throws -> ReviewOps.Review {
        try ReviewOps(repo: repo).createReview(title: title, base: base, head: head)
    }

    public func listReviews() throws -> [ReviewOps.Review] {
        try ReviewOps(repo: repo).listReviews()
    }

    public func reviewStatus(id: String) throws -> ReviewOps.Status {
        try ReviewOps(repo: repo).reviewStatus(id)
    }

    @discardableResult
    public func addComment(review: String, path: String, line: Int,
                           body: String) throws -> DiscussionOps.Comment {
        try DiscussionOps(repo: repo).addComment(review: review, path: path,
                                                 line: line, body: body)
    }

    public func listComments(review: String) throws -> [DiscussionOps.Comment] {
        try DiscussionOps(repo: repo).listComments(review: review)
    }

    @discardableResult
    public func editComment(review: String, id: String,
                            body: String) throws -> DiscussionOps.Comment {
        try DiscussionOps(repo: repo).editComment(review: review, id: id, body: body)
    }

    @discardableResult
    public func resolveComment(review: String,
                               id: String) throws -> DiscussionOps.Comment {
        try DiscussionOps(repo: repo).resolveComment(review: review, id: id)
    }

    @discardableResult
    public func approveReview(id: String, reviewer: String) throws -> ReviewOps.Review {
        try ReviewTrackingOps(repo: repo).approveReview(id: id, reviewer: reviewer)
    }

    public func changesSinceApproval(review: String) throws -> [String] {
        try ReviewTrackingOps(repo: repo).changesSinceApproval(review: review)
    }

    public func reviewPolicy() throws -> ReviewPolicyOps.Policy {
        try ReviewPolicyOps(repo: repo).reviewPolicy()
    }

    public func setReviewPolicy(_ policy: ReviewPolicyOps.Policy) throws {
        try ReviewPolicyOps(repo: repo).setReviewPolicy(policy)
    }

    public func reviewMergeCheck(id: String) throws -> (allowed: Bool, reasons: [String]) {
        try ReviewPolicyOps(repo: repo).reviewMergeCheck(id: id)
    }

    @discardableResult
    public func createSession(paths: [String]) throws -> ConflictSessionOps.Session {
        try ConflictSessionOps(repo: repo).createSession(paths: paths)
    }

    @discardableResult
    public func claimPath(session: String, path: String,
                          owner: String) throws -> ConflictSessionOps.Session {
        try ConflictSessionOps(repo: repo).claimPath(session: session, path: path,
                                                    owner: owner)
    }

    @discardableResult
    public func recordResolution(session: String, path: String,
                                 resolution: String) throws -> ConflictSessionOps.Session {
        try ConflictSessionOps(repo: repo).recordResolution(session: session, path: path,
                                                           resolution: resolution)
    }

    public func sessionStatus(session: String) throws -> ConflictSessionOps.SessionStatus {
        try ConflictSessionOps(repo: repo).sessionStatus(session: session)
    }

    public func activityFeed(limit: Int = 50) throws -> [ActivityFeedOps.Event] {
        try ActivityFeedOps(repo: repo).activityFeed(limit: limit)
    }

    public func ownershipRules() throws -> [OwnershipOps.Rule] {
        try OwnershipOps(repo: repo).ownershipRules()
    }

    public func setOwnershipRules(_ rules: [OwnershipOps.Rule]) throws {
        try OwnershipOps(repo: repo).setOwnershipRules(rules)
    }

    public func ownersOf(path: String) throws -> [String] {
        try OwnershipOps(repo: repo).ownersOf(path: path)
    }

    @discardableResult
    public func createWorkspaceTemplate(name: String,
                                        config: WorkspaceTemplateOps.Config) throws -> WorkspaceTemplateOps.Template {
        try WorkspaceTemplateOps(repo: repo).createTemplate(name: name, config: config)
    }

    public func workspaceTemplates() throws -> [WorkspaceTemplateOps.Template] {
        try WorkspaceTemplateOps(repo: repo).workspaceTemplates()
    }

    public func applyWorkspaceTemplate(name: String) throws {
        try WorkspaceTemplateOps(repo: repo).applyTemplate(name: name)
    }

    @discardableResult
    public func trackChangeAcrossBranches(changeId: String,
                                          branches: [String]) throws -> CrossBranchOps.Tracking {
        try CrossBranchOps(repo: repo).trackChangeAcrossBranches(changeId: changeId,
                                                                 branches: branches)
    }

    public func crossBranchStatus(changeId: String) throws -> [CrossBranchOps.BranchStatus] {
        try CrossBranchOps(repo: repo).crossBranchStatus(changeId: changeId)
    }

    public func notificationRules() throws -> [NotificationOps.Rule] {
        try NotificationOps(repo: repo).notificationRules()
    }

    public func setNotificationRules(_ rules: [NotificationOps.Rule]) throws {
        try NotificationOps(repo: repo).setNotificationRules(rules)
    }

    public func pendingNotifications() throws -> [NotificationOps.PendingNotification] {
        try NotificationOps(repo: repo).pendingNotifications()
    }

    @discardableResult
    public func deliverPendingNotifications() throws -> [NotificationOps.InboxNotification] {
        try NotificationOps(repo: repo).deliverPendingNotifications()
    }

    public func notificationInbox() throws -> [NotificationOps.InboxNotification] {
        try NotificationOps(repo: repo).notificationInbox()
    }

    public func notificationDeliveryDescription() -> String {
        NotificationOps.inboxDescription
    }

    public func markNotificationsSeen() throws {
        try NotificationOps(repo: repo).markNotificationsSeen()
    }
}
