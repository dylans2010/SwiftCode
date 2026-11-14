import Foundation
import Testing
@testable import SpacesEngine

@Suite struct CollaborationTests {

    @Test func reviewCreateListAndStatus() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        let base = try SpacesTestSupport.commitFiles(api, ["a.txt": "one\n"], message: "base")
        let review = try api.createReview(title: "Add feature", base: base.hex, head: "HEAD")
        #expect(review.status == .open)
        #expect(review.title == "Add feature")
        #expect(review.baseRev == base.hex)
        #expect(review.headRev == base.hex)
        #expect(review.author == "Test User")
        let listed = try api.listReviews()
        #expect(listed.count == 1)
        #expect(listed[0].id == review.id)
        #expect(try api.reviewStatus(id: review.id) == .open)
        let again = try api.listReviews()
        #expect(again.count == 1)
    }

    @Test func reviewMergeCheckFailsBeforeApprovalAndPassesAfter() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["a.txt": "one\n"], message: "base")
        let review = try api.createReview(title: "Ship it", base: "HEAD", head: "HEAD")
        try api.setReviewPolicy(ReviewPolicyOps.Policy(requiredApprovals: 1))
        let before = try api.reviewMergeCheck(id: review.id)
        #expect(!before.allowed)
        #expect(!before.reasons.isEmpty)
        _ = try api.approveReview(id: review.id, reviewer: "alice")
        let after = try api.reviewMergeCheck(id: review.id)
        #expect(after.allowed)
        #expect(after.reasons.isEmpty)
    }

    @Test func inlineDiscussionEditKeepsHistoryAndResolves() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["a.txt": "one\n"], message: "base")
        let review = try api.createReview(title: "Discuss", base: "HEAD", head: "HEAD")
        let comment = try api.addComment(review: review.id, path: "a.txt", line: 1,
                                         body: "Why this line?")
        #expect(comment.resolved == false)
        #expect(comment.history.isEmpty)
        let edited = try api.editComment(review: review.id, id: comment.id,
                                         body: "Why this line, exactly?")
        #expect(edited.body == "Why this line, exactly?")
        #expect(edited.history.count == 1)
        #expect(edited.history[0].body == "Why this line?")
        let resolved = try api.resolveComment(review: review.id, id: comment.id)
        #expect(resolved.resolved == true)
        let listed = try api.listComments(review: review.id)
        #expect(listed.count == 1)
        #expect(listed[0].history.count == 1)
    }

    @Test func changesSinceApprovalListsFileChangedAfterApproval() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f.txt": "v1\n"], message: "base")
        let review = try api.createReview(title: "Track changes", base: "HEAD", head: "HEAD")
        _ = try api.approveReview(id: review.id, reviewer: "alice")
        #expect(try api.changesSinceApproval(review: review.id).isEmpty)
        _ = try SpacesTestSupport.commitFiles(api, ["f.txt": "v2\n"], message: "edit f")
        let changed = try api.changesSinceApproval(review: review.id)
        #expect(changed == ["f.txt"])
        _ = try api.approveReview(id: review.id, reviewer: "alice")
        #expect(try api.changesSinceApproval(review: review.id).isEmpty)
    }

    @Test func reviewPolicyEnforcesRequiredReviewerAndValidation() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f.txt": "v1\n"], message: "base")
        let review = try api.createReview(title: "Gated", base: "HEAD", head: "HEAD")
        try api.setReviewPolicy(ReviewPolicyOps.Policy(
            requiredApprovals: 1, requiredReviewers: ["alice"], requireValidation: true))
        _ = try api.approveReview(id: review.id, reviewer: "bob")
        let missing = try api.reviewMergeCheck(id: review.id)
        #expect(!missing.allowed)
        #expect(missing.reasons.contains { $0.contains("alice") })
        _ = try api.approveReview(id: review.id, reviewer: "alice")
        #expect(try api.reviewMergeCheck(id: review.id).allowed)
        _ = try SpacesTestSupport.commitFiles(api, ["f.txt": "v2\n"], message: "drift")
        let drifted = try api.reviewMergeCheck(id: review.id)
        #expect(!drifted.allowed)
        #expect(drifted.reasons.contains { $0.contains("f.txt") })
    }

    @Test func conflictSessionClaimResolveAndStatus() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        let session = try api.createSession(paths: ["a.txt", "b.txt"])
        #expect(session.paths == ["a.txt", "b.txt"])
        #expect(!ConflictSessionOps.synchronizationDescription.isEmpty)
        var status = try api.sessionStatus(session: session.id)
        #expect(status.total == 2)
        #expect(status.claimed == 0)
        #expect(status.resolved == 0)
        #expect(status.unclaimed == ["a.txt", "b.txt"])
        _ = try api.claimPath(session: session.id, path: "a.txt", owner: "alice")
        let resolved = try api.recordResolution(session: session.id, path: "a.txt",
                                                resolution: "keep ours")
        #expect(resolved.resolutionsByPath["a.txt"] == "keep ours")
        status = try api.sessionStatus(session: session.id)
        #expect(status.claimed == 1)
        #expect(status.resolved == 1)
        #expect(status.unclaimed == ["b.txt"])
        #expect(status.unresolved == ["b.txt"])
        #expect(throws: SpacesError.self) {
            _ = try api.claimPath(session: session.id, path: "nope.txt", owner: "bob")
        }
    }

    @Test func activityFeedIncludesCommitsAndReviewsNewestFirst() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["a.txt": "one\n"], message: "first commit")
        _ = try api.createReview(title: "Feed review", base: "HEAD", head: "HEAD")
        let feed = try api.activityFeed(limit: 50)
        #expect(feed.contains { $0.type == "commit" })
        #expect(feed.contains { $0.type == "review" })
        #expect(feed.contains { $0.message.contains("Feed review") })
        var previous = Int64.max
        for event in feed {
            #expect(event.timestamp <= previous)
            previous = event.timestamp
        }
        let limited = try api.activityFeed(limit: 1)
        #expect(limited.count == 1)
    }

    @Test func ownershipRulesWinAndHistoryFallback() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(
            api, ["Sources/Foo.swift": "code\n", "README.md": "docs\n"], message: "base")
        try api.setOwnershipRules([
            OwnershipOps.Rule(pattern: "*.swift", owners: ["swift-team"]),
            OwnershipOps.Rule(pattern: "Sources/*.swift", owners: ["dylan"]),
        ])
        #expect(try api.ownersOf(path: "Sources/Foo.swift") == ["dylan"])
        #expect(try api.ownersOf(path: "README.md") == ["Test User"])
        #expect(try api.ownersOf(path: "missing.txt").isEmpty)
        #expect(try api.ownershipRules().count == 2)
    }

    @Test func workspaceTemplateCreateListAndApply() throws {
        let (_, api, url) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["a.txt": "one\n"], message: "base")
        let config = WorkspaceTemplateOps.Config(
            defaultBranch: "develop",
            reviewPolicy: ReviewPolicyOps.Policy(requiredApprovals: 2),
            ownershipRules: [OwnershipOps.Rule(pattern: "*.swift", owners: ["dylan"])],
            ignorePatterns: ["*.log"])
        let template = try api.createWorkspaceTemplate(name: "ios-app", config: config)
        #expect(template.name == "ios-app")
        #expect(try api.workspaceTemplates().count == 1)
        try api.applyWorkspaceTemplate(name: "ios-app")
        #expect(try api.branches().contains { $0.name == "develop" })
        #expect(try api.reviewPolicy().requiredApprovals == 2)
        #expect(try api.ownersOf(path: "Foo.swift") == ["dylan"])
        let ignoreText = try String(
            contentsOf: url.appendingPathComponent(".spacesignore"), encoding: .utf8)
        #expect(ignoreText.contains("*.log"))
        #expect(throws: SpacesError.self) {
            _ = try api.createWorkspaceTemplate(name: "ios-app", config: config)
        }
    }

    @Test func crossBranchStatusReachedAndPending() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        let first = try SpacesTestSupport.commitFiles(api, ["a.txt": "one\n"], message: "first")
        _ = try api.createBranch("feature", at: first.hex)
        let second = try SpacesTestSupport.commitFiles(api, ["a.txt": "two\n"], message: "second")
        _ = try api.trackChangeAcrossBranches(changeId: second.hex,
                                              branches: ["main", "feature"])
        let status = try api.crossBranchStatus(changeId: second.hex)
        #expect(status.count == 2)
        #expect(status.first { $0.branch == "main" }?.status == .reached)
        #expect(status.first { $0.branch == "feature" }?.status == .pending)
        #expect(status.first { $0.branch == "main" }?.headRev == second.hex)
    }

    @Test func notificationsPendingThenSeen() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["a.txt": "one\n"], message: "base")
        let pending = try api.pendingNotifications()
        #expect(pending.contains { $0.event == .commit })
        #expect(!NotificationOps.deliveryDescription.isEmpty)
        try api.setNotificationRules([
            NotificationOps.Rule(event: .commit, enabled: false),
            NotificationOps.Rule(event: .review, enabled: true),
        ])
        let filtered = try api.pendingNotifications()
        #expect(filtered.allSatisfy { $0.event != .commit })
        try api.setNotificationRules(NotificationOps.Event.allCases.map {
            NotificationOps.Rule(event: $0, enabled: true)
        })
        try api.markNotificationsSeen()
        #expect(try api.pendingNotifications().isEmpty)
    }
}
