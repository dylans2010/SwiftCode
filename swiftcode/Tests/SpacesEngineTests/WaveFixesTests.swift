import Foundation
import Testing
@testable import SpacesEngine

@Suite struct WaveFixesTests {
    @Test func rebaseEditAdvances() throws {
        let (_, api, url) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f": "base"], message: "base")
        try api.createBranch("topic")
        try api.switchTo("topic")
        let editOID = try SpacesTestSupport.commitFiles(api, ["a": "1"], message: "edit me")
        _ = try SpacesTestSupport.commitFiles(api, ["b": "1"], message: "second")
        try api.switchTo("main")
        _ = try SpacesTestSupport.commitFiles(api, ["c": "1"], message: "main work")
        try api.switchTo("topic")
        let state = try #require(try api.rebase(onto: "main", todo: ["edit 1"]))
        #expect(state.step == "edit")
        #expect(state.done == 0)
        #expect(state.todo[0].oid == editOID)
        #expect(try api.repo.inRebase())
        let continued = try api.rebaseContinue()
        #expect(continued == nil)
        #expect(try !api.repo.inRebase())
        #expect(try api.status().isClean)
        let messages = try api.log().map { $0.message }
        #expect(messages.contains("edit me"))
        #expect(messages.contains("second"))
        #expect(messages.contains("main work"))
        #expect(try FileManager.default.fileExists(atPath: url.appendingPathComponent("a").path))
        #expect(try FileManager.default.fileExists(atPath: url.appendingPathComponent("b").path))
        #expect(try FileManager.default.fileExists(atPath: url.appendingPathComponent("c").path))
    }

    @Test func checkoutRefusesSpacesPaths() throws {
        let (_, api, url) = try SpacesTestSupport.makeRepo()
        let blob = try api.repo.objects.write(type: .blob, payload: Data("planted".utf8))
        let tree = try api.repo.objects.write(.tree, value: TreePayload(entries: [
            TreeEntry(name: ".spaces", mode: .regular, oid: blob),
        ]))
        #expect(throws: SpacesError.self) { _ = try TreeBuilder.checkout(repo: api.repo, treeOID: tree) }
        #expect(Repository.isRepository(at: url))
    }

    @Test func checkoutRemoveUntrackedHonored() throws {
        let (_, api, url) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["tracked.txt": "tracked"], message: "base")
        let head = try #require(try api.repo.headCommit())
        try SpacesTestSupport.write("scratch", to: url.appendingPathComponent("scratch.txt"))
        _ = try TreeBuilder.checkout(repo: api.repo, treeOID: head.tree, removeUntracked: false)
        #expect(FileManager.default.fileExists(atPath: url.appendingPathComponent("scratch.txt").path))
        _ = try TreeBuilder.checkout(repo: api.repo, treeOID: head.tree, removeUntracked: true)
        #expect(!FileManager.default.fileExists(atPath: url.appendingPathComponent("scratch.txt").path))
        #expect(try String(contentsOf: url.appendingPathComponent("tracked.txt"), encoding: .utf8) == "tracked")
    }

    @Test func stashIncludeUntrackedHonored() throws {
        let (_, api, url) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["tracked.txt": "base"], message: "base")
        try SpacesTestSupport.write("untracked", to: url.appendingPathComponent("new.txt"))
        let entry = try #require(try StashOps(repo: api.repo).create(includeUntracked: true))
        #expect(!FileManager.default.fileExists(atPath: url.appendingPathComponent("new.txt").path))
        #expect(try api.stashes().contains { $0.id == entry.id })
        #expect(try api.status().isClean)
    }

    @Test func gitImportDryRunWritesNothing() throws {
        let (gitDir, _) = try SpacesValidationSupport.makeGitRepo(
            files: ["README.md": "hello\n"], message: "import one", secondMessage: "import two")
        let (_, api, url) = try SpacesTestSupport.makeRepo()
        let before = try api.repo.objects.allIDs()
        let report = try GitMigration(repo: api.repo).importGit(at: gitDir.path, dryRun: true)
        #expect(report.commits == 2)
        #expect(report.objectsWritten > 0)
        #expect(try api.repo.objects.allIDs().count == before.count)
        #expect(try api.repo.refs.allRefs().isEmpty)
        #expect(!FileManager.default.fileExists(
            atPath: api.repo.metaURL.appendingPathComponent("migration.log").path))
        #expect(!FileManager.default.fileExists(atPath: url.appendingPathComponent("README.md").path))
    }

    @Test func mergeRespectsReviewPolicy() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        let base = try SpacesTestSupport.commitFiles(api, ["f": "base\n"], message: "base")
        try api.createBranch("feature")
        try api.switchTo("feature")
        let head = try SpacesTestSupport.commitFiles(api, ["f": "feature\n"], message: "feature work")
        try api.switchTo("main")
        let review = try api.createReview(title: "feature review", base: base.hex, head: head.hex)
        try api.setReviewPolicy(ReviewPolicyOps.Policy(requiredApprovals: 1))
        #expect(throws: SpacesError.self) { _ = try api.merge("feature") }
        #expect(try api.repo.refs.headOID(objects: api.repo.objects) == base)
        _ = try api.approveReview(id: review.id, reviewer: "Test User")
        let outcome = try api.merge("feature")
        guard case .fastForward = outcome.result else {
            Issue.record("expected fast-forward, got \(outcome.result)")
            return
        }
        #expect(try api.repo.refs.headOID(objects: api.repo.objects) == head)
    }

    @Test func twoPhaseMultiRepoCommitRollsBackOnFailure() throws {
        let (_, apiA, urlA) = try SpacesTestSupport.makeRepo()
        let (_, apiB, urlB) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(apiA, ["a": "1"], message: "base a")
        _ = try SpacesTestSupport.commitFiles(apiB, ["b": "1"], message: "base b")
        try apiB.setCommitPolicies([
            ValidationPolicyOps.PolicyRule(id: "ticket", kind: .messagePattern, pattern: "^TICKET-[0-9]+"),
        ])
        try SpacesTestSupport.write("a2\n", to: urlA.appendingPathComponent("a2"))
        try SpacesTestSupport.write("b2\n", to: urlB.appendingPathComponent("b2"))
        _ = try apiA.stageAll()
        _ = try apiB.stageAll()
        let result = try apiA.multiRepoCommit(repos: [urlA, urlB], message: "shared work")
        #expect(result.bestEffort == false)
        #expect(result.results.count == 2)
        #expect(result.results.allSatisfy { $0.committed == nil })
        #expect(result.results[1].error != nil)
        #expect(try apiA.log().count == 1)
        #expect(try apiB.log().count == 1)
    }

    @Test func syncReturnsSyncReportWithPushError() throws {
        let (_, localAPI, _) = try SpacesTestSupport.makeRepo()
        let (_, remoteAPI, remoteURL) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(localAPI, ["f": "1"], message: "base")
        try localAPI.addRemote("origin", url: remoteURL.path)
        _ = try localAPI.push("origin", refspec: "main")
        _ = try SpacesTestSupport.commitFiles(remoteAPI, ["r": "remote\n"], message: "remote work")
        _ = try SpacesTestSupport.commitFiles(localAPI, ["l": "local\n"], message: "local work")
        let report = try RemoteOps(repo: localAPI.repo).sync("origin")
        #expect(report.push == nil)
        let pushError = try #require(report.pushError)
        #expect(pushError.contains("non-fast-forward"))
        #expect(try localAPI.log().count == 2)
    }

    @Test func snapshotSignatureInfoFingerprintAfterKeyMigration() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f.txt": "1"], message: "base")
        let legacyURL = api.repo.metaURL.appendingPathComponent("signing.key")
        try Data(repeating: 7, count: 32).write(to: legacyURL)
        let expected = try #require(SigningKeyStore(repo: api.repo).existingKeyInfo()?.fingerprint)
        let snap = try api.snapshot(message: "checkpoint")
        _ = try api.signSnapshot(snap.hex)
        #expect(!FileManager.default.fileExists(atPath: legacyURL.path))
        let info = try api.signedSnapshotInfo(snap.hex)
        #expect(info.snapshot == snap.hex)
        #expect(info.keyFingerprint == expected)
        #expect(info.verified == true)
        #expect(info.method == SignedSnapshotOps.signingMethod)
    }

    @Test func setDetachedHeadDetaches() throws {
        let (repo, api, _) = try SpacesTestSupport.makeRepo()
        let oid = try SpacesTestSupport.commitFiles(api, ["f": "1"], message: "base")
        #expect(try !repo.isDetachedHead())
        try repo.setDetachedHead(oid)
        #expect(try repo.isDetachedHead())
        #expect(try repo.refs.currentBranch() == nil)
        #expect(try repo.refs.headOID(objects: repo.objects) == oid)
    }

    @Test func gcPruneDaysHonorsAge() throws {
        let (repo, _, _) = try SpacesTestSupport.makeRepo()
        let oldUnreachable = try repo.objects.write(type: .blob, payload: Data("old orphan".utf8))
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(-40 * 86400)],
            ofItemAtPath: repo.objects.url(for: oldUnreachable).path)
        let freshUnreachable = try repo.objects.write(type: .blob, payload: Data("fresh orphan".utf8))
        let first = try MaintenanceOps(repo: repo).gc(pruneDays: 30)
        #expect(first.pruned == 1)
        #expect(!repo.objects.exists(oldUnreachable))
        #expect(repo.objects.exists(freshUnreachable))
        let second = try MaintenanceOps(repo: repo).gc(pruneDays: 30)
        #expect(second.pruned == 0)
        #expect(repo.objects.exists(freshUnreachable))
        let third = try MaintenanceOps(repo: repo).gc()
        #expect(third.pruned >= 1)
        #expect(!repo.objects.exists(freshUnreachable))
    }

    @Test func gcKeepsReachableObjectsRegardlessOfAge() throws {
        let (repo, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["keep.txt": "keep me"], message: "base")
        let head = try #require(try repo.headCommit())
        let flat = try TreeBuilder.flattenTree(repo: repo, treeOID: head.tree)
        let entry = try #require(flat["keep.txt"])
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(-400 * 86400)],
            ofItemAtPath: repo.objects.url(for: entry.oid).path)
        let result = try MaintenanceOps(repo: repo).gc(pruneDays: 30)
        #expect(result.pruned == 0)
        #expect(repo.objects.exists(entry.oid))
    }

    @Test func gcRejectsNegativePruneDays() throws {
        let (repo, _, _) = try SpacesTestSupport.makeRepo()
        #expect(throws: SpacesError.self) { _ = try MaintenanceOps(repo: repo).gc(pruneDays: -1) }
    }
}
