import XCTest
@testable import SwiftCode

@MainActor
final class CollaborationTests: XCTestCase {
    var project: Project!
    var manager: CollaborationManager!
    let creatorID = "Creator"
    let collaboratorID = "Collaborator"

    override func setUp() {
        super.setUp()
        project = Project(name: "TestProject")
        manager = CollaborationManager(projectID: project.id, creatorID: creatorID, projectName: project.name)
    }

    func testInitialOwnerRole() {
        XCTAssertEqual(manager.permissions.memberRoles[creatorID], .owner)
    }

    func testInviteAndPermission() {
        manager.invite(memberID: collaboratorID, role: .member, actorID: creatorID)
        XCTAssertEqual(manager.permissions.memberRoles[collaboratorID], .member)

        // Member should not be able to invite others
        manager.invite(memberID: "Other", role: .member, actorID: collaboratorID)
        XCTAssertNil(manager.permissions.memberRoles["Other"])
    }

    func testCommitAndBranching() {
        let branch = manager.branches.createBranch(name: "feature", actorID: creatorID, permissions: manager.permissions)
        XCTAssertNotNil(branch)
        manager.branches.switchBranch(to: branch!.id, actorID: creatorID)

        manager.commit(message: "Initial feature commit", authorID: creatorID, changes: ["main.swift": "print(\"hello\")"])
        XCTAssertEqual(manager.commits.commits(for: branch!.id).count, 1)
    }

    func testPullRequestLifecycle() {
        let featureBranch = manager.branches.createBranch(name: "feature", actorID: creatorID, permissions: manager.permissions)!
        manager.branches.switchBranch(to: featureBranch.id, actorID: creatorID)
        manager.commit(message: "Feature update", authorID: creatorID, changes: ["file.txt": "data"])

        let mainBranch = manager.branches.branches.first { $0.name == "main" }!

        manager.createPR(title: "New feature", description: "Merging feature into main", sourceBranchID: featureBranch.id, targetBranchID: mainBranch.id, authorID: creatorID)

        XCTAssertEqual(manager.reviews.pullRequests.count, 1)
        let pr = manager.reviews.pullRequests.first!
        XCTAssertEqual(pr.status, .open)

        manager.merge(branch: pr.sourceBranchID, into: pr.targetBranchID, actorID: creatorID)
        manager.reviews.mergePR(pr.id, actorID: creatorID, permissions: manager.permissions)

        XCTAssertEqual(manager.reviews.pullRequests.first!.status, .merged)
        XCTAssertEqual(manager.commits.commits(for: mainBranch.id).count, 1)
    }
}
