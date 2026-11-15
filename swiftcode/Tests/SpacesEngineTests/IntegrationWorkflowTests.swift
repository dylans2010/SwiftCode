import Foundation
import Testing
@testable import SpacesEngine

@Suite struct IntegrationWorkflowTests {
    @Test func branchMergeSnapshotRestoreWorkflow() throws {
        let (_, api, url) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["App.swift": "public struct App {}\n"], message: "initial")
        try api.createBranch("feature")
        try api.switchTo("feature")
        _ = try SpacesTestSupport.commitFiles(api, ["App.swift": "public struct App {\n    public var name = \"feature\"\n}\n"], message: "feature change")
        try api.switchTo("main")
        let outcome = try api.merge("feature")
        guard case .fastForward = outcome.result else {
            Issue.record("integration workflow: expected fast-forward merge, got \(outcome.result)")
            return
        }
        #expect(try String(contentsOf: url.appendingPathComponent("App.swift"), encoding: .utf8).contains("feature"))
        let snap = try api.snapshot(message: "post-merge checkpoint", kind: .manual)
        try SpacesTestSupport.write("corrupted contents\n", to: url.appendingPathComponent("App.swift"))
        #expect(try String(contentsOf: url.appendingPathComponent("App.swift"), encoding: .utf8) == "corrupted contents\n")
        #expect(try !api.status().isClean)
        try api.restoreSnapshot(snap.hex)
        #expect(try String(contentsOf: url.appendingPathComponent("App.swift"), encoding: .utf8).contains("feature"))
        #expect(try !String(contentsOf: url.appendingPathComponent("App.swift"), encoding: .utf8).contains("corrupted"))
        #expect(try api.status().isClean)
        #expect(try api.log().count == 2)
    }

    @Test func tagBundleExportImportWorkflow() throws {
        let (_, api, url) = try SpacesTestSupport.makeRepo()
        let c1 = try SpacesTestSupport.commitFiles(api, ["README.md": "hello\n"], message: "first")
        let c2 = try SpacesTestSupport.commitFiles(api, ["src.swift": "print(1)\n"], message: "second")
        try api.createTag("v1.0", annotated: true, message: "release one")
        let bundleDir = try SpacesTestSupport.tempDir()
        let bundlePath = bundleDir.appendingPathComponent("workflow.spbd").path
        try BundleOps.create(repo: api.repo, output: bundlePath)
        #expect(FileManager.default.fileExists(atPath: bundlePath))
        let inspected = try BundleOps.verify(path: bundlePath)
        #expect(inspected.objectCount > 0)
        #expect(inspected.refs["refs/heads/main"] == c2.hex)
        #expect(inspected.refs["refs/tags/v1.0"] != nil)
        let (freshRepo, freshAPI, freshURL) = try SpacesTestSupport.makeRepo()
        let imported = try BundleOps.importBundle(into: freshRepo, path: bundlePath)
        #expect(imported.objectCount > 0)
        let freshLog = try freshAPI.log()
        #expect(freshLog.map(\.oid) == [c2, c1])
        #expect(freshLog[0].message.hasPrefix("second"))
        #expect(freshLog[1].message.hasPrefix("first"))
        #expect(try freshAPI.tags().contains { $0.name == "v1.0" })
        try freshAPI.reset(to: "HEAD", mode: .hard)
        #expect(try String(contentsOf: freshURL.appendingPathComponent("README.md"), encoding: .utf8) == "hello\n")
        #expect(try String(contentsOf: freshURL.appendingPathComponent("src.swift"), encoding: .utf8) == "print(1)\n")
        #expect(try freshAPI.status().isClean)
        _ = url
    }

    @Test func reviewApproveMergeWorkflow() throws {
        let (_, api, url) = try SpacesTestSupport.makeRepo()
        let base = try SpacesTestSupport.commitFiles(api, ["f": "base\n"], message: "base")
        try api.createBranch("feature")
        try api.switchTo("feature")
        let head = try SpacesTestSupport.commitFiles(api, ["f": "feature\n"], message: "feature work")
        try api.switchTo("main")
        #expect(try api.repo.refs.headOID(objects: api.repo.objects) == base)
        let review = try api.createReview(title: "feature review", base: base.hex, head: head.hex)
        #expect(review.status == .open)
        #expect(try api.reviewStatus(id: review.id) == .open)
        let comment = try api.addComment(review: review.id, path: "f", line: 1, body: "Looks good, one nit.")
        #expect(comment.body == "Looks good, one nit.")
        #expect(try api.listComments(review: review.id).count == 1)
        let before = try api.reviewMergeCheck(id: review.id)
        #expect(before.allowed == false)
        #expect(before.reasons.contains { $0.contains("approval") })
        let approved = try api.approveReview(id: review.id, reviewer: "Test User")
        #expect(approved.status == .approved)
        #expect(try api.reviewStatus(id: review.id) == .approved)
        #expect(try api.changesSinceApproval(review: review.id) == ["f"])
        let check = try api.reviewMergeCheck(id: review.id)
        #expect(check.allowed == true)
        #expect(check.reasons.isEmpty)
        let outcome = try api.merge("feature")
        guard case .fastForward = outcome.result else {
            Issue.record("integration review workflow: expected fast-forward merge, got \(outcome.result)")
            return
        }
        #expect(try String(contentsOf: url.appendingPathComponent("f"), encoding: .utf8) == "feature\n")
        #expect(try api.log()[0].oid == head)
        #expect(try api.status().isClean)
    }

    @Test func remoteBackupRestoreWorkflow() throws {
        let (_, localAPI, localURL) = try SpacesTestSupport.makeRepo()
        let (_, _, remoteURL) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(localAPI, ["data.txt": "important\n"], message: "data")
        try localAPI.addRemote("origin", url: remoteURL.path)
        _ = try localAPI.push("origin", refspec: "main")
        let backupDir = try SpacesTestSupport.tempDir()
        let backupPath = backupDir.appendingPathComponent("remote-backup.spbd").path
        let manifest = try localAPI.createBackup(to: backupPath)
        #expect(!manifest.objects.isEmpty)
        #expect(try localAPI.verifyBackup(url: backupPath).objectCount > 0)
        let (restoredRepo, restoredAPI, restoredURL) = try SpacesTestSupport.makeRepo()
        let restoredReport = try BundleOps.importBundle(into: restoredRepo, path: backupPath)
        #expect(restoredReport.refs["refs/heads/main"] != nil)
        #expect(try restoredAPI.log().count == 1)
        #expect(try restoredAPI.log()[0].message.hasPrefix("data"))
        let cloneBase = try SpacesTestSupport.tempDir()
        let cloneURL = cloneBase.appendingPathComponent("cloned")
        let cloned = try CloneOps.clone(url: remoteURL.path, into: cloneURL)
        let clonedAPI = SpacesAPI(repo: cloned)
        #expect(try clonedAPI.log().count == 1)
        #expect(try String(contentsOf: cloneURL.appendingPathComponent("data.txt"), encoding: .utf8) == "important\n")
        _ = localURL
        _ = restoredURL
    }
}
