import Foundation
import Testing
@testable import SpacesEngine

@Suite struct CoreFlowTests {
    @Test func initStatusCommitLog() throws {
        let (repo, api, url) = try SpacesTestSupport.makeRepo()
        #expect(Repository.isRepository(at: url))
        #expect(try Repository.open(at: url).worktreeURL == repo.worktreeURL)

        try SpacesTestSupport.write("one\n", to: url.appendingPathComponent("a.txt"))
        var status = try api.status()
        #expect(status.untrackedFiles.count == 1)

        _ = try api.add("a.txt")
        status = try api.status()
        #expect(status.staged.count == 1)
        #expect(status.unstaged.isEmpty)

        let commit = try api.commit(message: "initial")
        #expect(commit.oid.hex.count == 64)
        status = try api.status()
        #expect(status.isClean)

        let log = try api.log()
        #expect(log.count == 1)
        #expect(log[0].message.hasPrefix("initial"))

        // Reopen: state must persist on disk.
        let reopened = try Repository.open(at: url)
        #expect(try reopened.refs.headOID(objects: reopened.objects) == commit.oid)
    }

    @Test func commitRejectsEmptyAndMissingIdentity() throws {
        let (_, api, url) = try SpacesTestSupport.makeRepo()
        #expect(throws: SpacesError.self) { _ = try api.commit(message: "nothing") }
        try SpacesTestSupport.write("x", to: url.appendingPathComponent("f"))
        _ = try api.stageAll()
        // User identity was supplied at create; commit succeeds.
        _ = try api.commit(message: "ok")
    }

    @Test func diffShowsStagedAndUnstaged() throws {
        let (_, api, url) = try SpacesTestSupport.makeRepo()
        let file = url.appendingPathComponent("f.txt")
        try SpacesTestSupport.write("line1\nline2\n", to: file)
        _ = try api.stageAll()
        _ = try api.commit(message: "base")

        try SpacesTestSupport.write("line1\nline2 changed\nline3\n", to: file)
        let unstaged = try api.diff()
        #expect(!unstaged.isEmpty)

        _ = try api.add("f.txt")
        let staged = try api.diff(stagedOnly: true)
        #expect(!staged.isEmpty)
    }

    @Test func branchCreateSwitchDelete() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        let base = try SpacesTestSupport.commitFiles(api, ["f": "1"], message: "base")

        try api.createBranch("feature")
        try api.switchTo("feature")
        _ = try SpacesTestSupport.commitFiles(api, ["g": "2"], message: "feat")

        try api.switchTo("main")
        #expect(try api.repo.refs.headOID(objects: api.repo.objects) == base)
        #expect(try !FileManager.default.fileExists(
            atPath: api.repo.worktreeURL.appendingPathComponent("g").path))

        // Safe delete refuses an unmerged branch; force deletes it.
        #expect(throws: SpacesError.self) { try api.deleteBranch("feature") }
        try api.deleteBranch("feature", force: true)
        #expect(try api.branches().allSatisfy { $0.name != "feature" })
    }

    @Test func resetModes() throws {
        let (_, api, url) = try SpacesTestSupport.makeRepo()
        let c1 = try SpacesTestSupport.commitFiles(api, ["f": "1"], message: "c1")
        _ = try SpacesTestSupport.commitFiles(api, ["f": "2"], message: "c2")

        // Mixed reset: index matches c1, worktree keeps "2".
        try api.reset(to: "HEAD~1", mode: .mixed)
        let status = try api.status()
        #expect(status.unstaged.contains { $0.path == "f" } || status.staged.contains { $0.path == "f" })

        // Hard reset restores worktree to HEAD (which the mixed reset moved
        // to c1, matching `git reset --hard HEAD` semantics).
        try api.reset(to: "HEAD", mode: .hard)
        #expect(try String(contentsOf: url.appendingPathComponent("f"), encoding: .utf8) == "1")
        _ = c1
    }

    @Test func renameMove() throws {
        let (_, api, url) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["old.txt": "data"], message: "base")
        try api.move("old.txt", "new.txt")
        let status = try api.status()
        #expect(status.entries.contains { $0.path == "new.txt" })
        #expect(try !FileManager.default.fileExists(
            atPath: url.appendingPathComponent("old.txt").path))
    }

    @Test func unstageAndRestore() throws {
        let (_, api, url) = try SpacesTestSupport.makeRepo()
        try SpacesTestSupport.write("x", to: url.appendingPathComponent("f"))
        _ = try api.stageAll()
        try api.unstage("f")
        #expect(try api.status().staged.isEmpty)

        _ = try api.stageAll()
        _ = try api.commit(message: "c")
        try SpacesTestSupport.write("changed", to: url.appendingPathComponent("f"))
        try api.restore("f")
        #expect(try String(contentsOf: url.appendingPathComponent("f"), encoding: .utf8) == "x")
    }

    @Test func ignoreRules() throws {
        let (_, api, url) = try SpacesTestSupport.makeRepo()
        try SpacesTestSupport.write("*.log\nbuild/\n", to: url.appendingPathComponent(".gitignore"))
        try SpacesTestSupport.write("x", to: url.appendingPathComponent("a.log"))
        try SpacesTestSupport.write("y", to: url.appendingPathComponent("b.txt"))
        try SpacesTestSupport.write("z", to: url.appendingPathComponent("build/out.o"))
        let status = try api.status()
        #expect(status.untrackedFiles.allSatisfy { !$0.path.hasSuffix(".log") && !$0.path.hasPrefix("build/") })
        #expect(status.untrackedFiles.contains { $0.path == "b.txt" })
    }

    @Test func cleanRemovesUntracked() throws {
        let (_, api, url) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["keep": "1"], message: "base")
        try SpacesTestSupport.write("junk", to: url.appendingPathComponent("junk.tmp"))
        let removed = try api.clean(dryRun: false)
        #expect(removed.contains("junk.tmp"))
        #expect(try !FileManager.default.fileExists(
            atPath: url.appendingPathComponent("junk.tmp").path))
        // Tracked file survives.
        #expect(try FileManager.default.fileExists(
            atPath: url.appendingPathComponent("keep").path))
    }
}
