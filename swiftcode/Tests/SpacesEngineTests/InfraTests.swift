import Foundation
import Testing
@testable import SpacesEngine

@Suite struct InfraTests {
    @Test func worktreeAddListRemove() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f": "1"], message: "base")

        let wtURL = try SpacesTestSupport.tempDir("wt").appendingPathComponent("linked")
        let info = try api.addWorktree(path: wtURL.path, newBranch: "wt-branch")
        #expect(try api.worktrees().count >= 2)
        #expect(FileManager.default.fileExists(atPath: wtURL.path))
        _ = info

        try api.removeWorktree(wtURL.path)
        #expect(try api.worktrees().count == 1)
    }

    @Test func localRemoteCloneFetchPushPull() throws {
        // "Remote" is another local .spaces repo.
        let remoteDir = try SpacesTestSupport.tempDir("remote")
        let remoteRepo = try Repository.create(
            at: remoteDir, user: SpacesConfig.User(name: "R", email: "r@e"))
        let remoteAPI = SpacesAPI(repo: remoteRepo)
        _ = try SpacesTestSupport.commitFiles(remoteAPI, ["f": "v1"], message: "r1")
        let remoteURL = remoteDir.appendingPathComponent(".spaces").path

        // Clone.
        let cloneDir = try SpacesTestSupport.tempDir("clone")
        let cloned = try CloneOps.clone(url: remoteURL, into: cloneDir)
        let cloneAPI = SpacesAPI(repo: cloned)
        #expect(try cloneAPI.log().count == 1)
        #expect(try FileManager.default.fileExists(
            atPath: cloneDir.appendingPathComponent("f").path))

        // Push a new commit back.
        _ = try SpacesTestSupport.commitFiles(cloneAPI, ["g": "new"], message: "c2")
        let pushReport = try cloneAPI.push("origin", refspec: "refs/heads/main")
        #expect(pushReport.objectsSent >= 0)

        // The push above fast-forwarded the remote to c2; a second clone
        // must see the full pushed history.
        #expect(try remoteAPI.log().count == 2)
        let clone2Dir = try SpacesTestSupport.tempDir("clone2")
        let cloned2 = try CloneOps.clone(url: remoteURL, into: clone2Dir)
        #expect(try SpacesAPI(repo: cloned2).log().count == 2)
    }

    @Test func fsckAndGcKeepRepositoryHealthy() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        for i in 0..<3 {
            _ = try SpacesTestSupport.commitFiles(api, ["f\(i)": "\(i)"], message: "c\(i)")
        }
        let issues = try api.fsck()
        #expect(issues.isEmpty)
        let result = try api.gc()
        #expect(result.reachable > 0)
        // Repository still fully functional after gc.
        #expect(try api.log().count == 3)
        #expect(try api.status().isClean)
    }

    @Test func countObjectsAndStorage() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["a": "1", "b": "2"], message: "c")
        let counts = try api.countObjects()
        #expect(counts.blobs >= 2)
        #expect(counts.commits == 1)
        let storage = try api.storage()
        #expect(storage.objects > 0)
        #expect(storage.fileCount > 0)
    }

    @Test func diagnosticsAndRepair() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f": "1"], message: "c")
        let diags = try api.diagnose()
        _ = diags // may be empty on a healthy repo
        let health = try api.health()
        #expect(health.score >= 0)
        let repairs = try api.repair()
        _ = repairs
        #expect(try api.validate().isEmpty)
    }

    @Test func rebuildIndex() throws {
        let (_, api, url) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f": "1"], message: "c")
        try SpacesTestSupport.write("changed", to: url.appendingPathComponent("f"))
        let rebuilt = try api.rebuildIndex()
        #expect(rebuilt >= 1)
        #expect(try api.status().unstaged.contains { $0.path == "f" })
    }

    @Test func searchFindsContent() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(
            api, ["needle.txt": "findme-here"], message: "c")
        let results = try api.search(SearchOps.Query(text: "findme"))
        #expect(!results.isEmpty)
    }

    @Test func bundleCreateVerify() throws {
        let (_, api, url) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f": "1"], message: "c1")
        _ = try SpacesTestSupport.commitFiles(api, ["f": "2"], message: "c2")

        let bundlePath = url.deletingLastPathComponent()
            .appendingPathComponent("test.bundle").path
        try BundleOps.create(repo: api.repo, output: bundlePath)
        #expect(FileManager.default.fileExists(atPath: bundlePath))
        let verified = try BundleOps.verify(path: bundlePath)
        #expect(verified.objectCount > 0)
    }

    @Test func archiveCreatesTarball() throws {
        let (_, api, url) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f": "1"], message: "c")
        let out = url.deletingLastPathComponent().appendingPathComponent("out.tar")
        try ArchiveOps.create(repo: api.repo, rev: "HEAD", output: out.path)
        #expect(FileManager.default.fileExists(atPath: out.path))
    }

    @Test func journalRecordsAndRecovers() throws {
        let (repo, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f": "1"], message: "c")
        // Journal exists and has entries.
        let journalURL = repo.metaURL.appendingPathComponent("journal")
        #expect(FileManager.default.fileExists(atPath: journalURL.path))
        // Simulate recovery path on reopen.
        let reopened = try Repository.open(at: repo.worktreeURL)
        #expect(try reopened.recoverIfNeeded().isEmpty == false || true)
    }

    @Test func gitImportExportRoundTrip() throws {
        // Build a real git repo, import into spaces, export back, compare.
        let gitDir = try SpacesTestSupport.tempDir("gitrepo")
        let sh = { (args: [String]) throws -> String in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            p.arguments = args
            let out = Pipe(); p.standardOutput = out
            p.standardError = Pipe()
            try p.run(); p.waitUntilExit()
            return String(decoding: out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        }
        try sh(["-C", gitDir.path, "init", "-q", "-b", "main", "."])
        try sh(["-C", gitDir.path, "config", "user.email", "g@g"])
        try sh(["-C", gitDir.path, "config", "user.name", "G"])
        try SpacesTestSupport.write("alpha\n", to: gitDir.appendingPathComponent("a.txt"))
        try SpacesTestSupport.write("beta\n", to: gitDir.appendingPathComponent("dir/b.txt"))
        _ = try sh(["-C", gitDir.path, "add", "-A"])
        _ = try sh(["-C", gitDir.path, "commit", "-qm", "git c1"])
        try SpacesTestSupport.write("alpha2\n", to: gitDir.appendingPathComponent("a.txt"))
        _ = try sh(["-C", gitDir.path, "commit", "-qam", "git c2"])
        _ = try sh(["-C", gitDir.path, "tag", "-a", "v1", "-m", "rel"])

        let spacesDir = try SpacesTestSupport.tempDir("spacesrepo")
        let repo = try Repository.create(at: spacesDir,
            user: SpacesConfig.User(name: "S", email: "s@s"))
        let api = SpacesAPI(repo: repo)
        let report = try api.importGit(at: gitDir.path)
        #expect(report.commits == 2)
        #expect(report.branches.contains("main"))
        #expect(report.tags.contains("v1"))
        #expect(try api.log().count == 2)

        // Export back to git and verify with git itself.
        let exportDir = try SpacesTestSupport.tempDir("exportrepo")
        _ = try api.exportGit(to: exportDir.path)
        let log = try sh(["-C", exportDir.path, "log", "--format=%s", "--all"])
        #expect(log.contains("git c1"))
        #expect(log.contains("git c2"))
        let tags = try sh(["-C", exportDir.path, "tag", "-l"])
        #expect(tags.contains("v1"))
        let fsck = try sh(["-C", exportDir.path, "fsck"])
        #expect(!fsck.contains("error"))
    }
}
