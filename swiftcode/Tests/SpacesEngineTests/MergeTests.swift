import Foundation
import Testing
@testable import SpacesEngine

@Suite struct MergeTests {
    @Test func fastForwardMerge() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f": "1"], message: "base")
        try api.createBranch("side")
        try api.switchTo("side")
        _ = try SpacesTestSupport.commitFiles(api, ["g": "2"], message: "side work")
        try api.switchTo("main")

        let outcome = try api.merge("side")
        guard case .fastForward = outcome.result else {
            Issue.record("expected fast-forward, got \(outcome.result)")
            return
        }
        #expect(try api.status().isClean)
    }

    @Test func cleanThreeWayMerge() throws {
        let (_, api, url) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["a": "1", "b": "1"], message: "base")
        try api.createBranch("feature")
        try api.switchTo("feature")
        _ = try SpacesTestSupport.commitFiles(api, ["a": "feature"], message: "feat a")
        try api.switchTo("main")
        _ = try SpacesTestSupport.commitFiles(api, ["b": "main"], message: "main b")

        let outcome = try api.merge("feature")
        guard case .merged = outcome.result else {
            Issue.record("expected merge commit, got \(outcome.result)")
            return
        }
        #expect(outcome.conflicts.isEmpty)
        #expect(try String(contentsOf: url.appendingPathComponent("a"), encoding: .utf8) == "feature")
        #expect(try String(contentsOf: url.appendingPathComponent("b"), encoding: .utf8) == "main")
        #expect(try api.status().isClean)
        #expect(try api.repo.inMerge() == false)
    }

    @Test func conflictThenContinue() throws {
        let (_, api, url) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f": "base\n"], message: "base")
        try api.createBranch("side")
        try api.switchTo("side")
        _ = try SpacesTestSupport.commitFiles(api, ["f": "side\n"], message: "side")
        try api.switchTo("main")
        _ = try SpacesTestSupport.commitFiles(api, ["f": "main\n"], message: "main")

        let outcome = try api.merge("side")
        #expect(!outcome.conflicts.isEmpty)
        #expect(try api.repo.inMerge())

        
        let conflicted = try String(contentsOf: url.appendingPathComponent("f"), encoding: .utf8)
        #expect(conflicted.contains("<<<<<<<"))

        
        try SpacesTestSupport.write("resolved\n", to: url.appendingPathComponent("f"))
        _ = try api.add("f")
        let oid = try api.mergeContinue()
        #expect(oid.hex.count == 64)
        #expect(try !api.repo.inMerge())
        #expect(try String(contentsOf: url.appendingPathComponent("f"), encoding: .utf8) == "resolved\n")
        #expect(try api.status().isClean)
    }

    @Test func mergeAbortRestores() throws {
        let (_, api, url) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f": "base\n"], message: "base")
        try api.createBranch("side")
        try api.switchTo("side")
        _ = try SpacesTestSupport.commitFiles(api, ["f": "side\n"], message: "side")
        try api.switchTo("main")
        _ = try SpacesTestSupport.commitFiles(api, ["f": "main\n"], message: "main")
        let headBefore = try api.repo.refs.headOID(objects: api.repo.objects)

        _ = try api.merge("side")
        #expect(try api.repo.inMerge())
        try api.mergeAbort()
        #expect(try !api.repo.inMerge())
        #expect(try api.repo.refs.headOID(objects: api.repo.objects) == headBefore)
        #expect(try String(contentsOf: url.appendingPathComponent("f"), encoding: .utf8) == "main\n")
    }

    @Test func mergeUpToDate() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f": "1"], message: "c")
        let outcome = try api.merge("main")
        if case .upToDate = outcome.result {} else {
            Issue.record("expected up-to-date, got \(outcome.result)")
        }
        #expect(outcome.commitOID == nil)
    }

    @Test func cherryPickAndRevert() throws {
        let (_, api, url) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f": "1"], message: "base")
        try api.createBranch("work")
        try api.switchTo("work")
        let pick = try SpacesTestSupport.commitFiles(api, ["f": "2"], message: "change")
        try api.switchTo("main")

        _ = try api.cherryPick("work")
        #expect(try String(contentsOf: url.appendingPathComponent("f"), encoding: .utf8) == "2")

        _ = try api.revert("HEAD")
        #expect(try String(contentsOf: url.appendingPathComponent("f"), encoding: .utf8) == "1")
        _ = pick
    }

    @Test func stashCreateApplyPopDrop() throws {
        let (_, api, url) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f": "1"], message: "base")
        try SpacesTestSupport.write("dirty", to: url.appendingPathComponent("f"))
        try SpacesTestSupport.write("new", to: url.appendingPathComponent("untracked.txt"))

        let entry = try api.stash(message: "wip")
        #expect(entry != nil)
        #expect(try api.status().isClean)
        #expect(try api.stashes().count == 1)
        let stashID = try #require(entry?.id)

        try api.stashApply(stashID)
        #expect(try !api.status().isClean)

        
        _ = try api.stash(message: "wip2")
        let stashID2 = try #require(try api.stashes().first?.id)
        try api.stashDrop(stashID2)
        
        #expect(try api.stashes().map(\.id) == [stashID])
    }

    @Test func annotatedAndLightweightTags() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        let c = try SpacesTestSupport.commitFiles(api, ["f": "1"], message: "c")
        try api.createTag("v1.0", annotated: true, message: "release")
        try api.createTag("latest", annotated: false)

        let tags = try api.tags()
        #expect(tags.count == 2)
        #expect(try api.verifyTag("v1.0") == false)
        #expect(tags.first { $0.name == "v1.0" }?.peeled == c)
        #expect(tags.first { $0.name == "v1.0" }?.isAnnotated == true)
        #expect(tags.first { $0.name == "latest" }?.oid == c)
    }

    @Test func snapshotsAndTimeline() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f": "1"], message: "c1")
        let snap = try api.snapshot(message: "checkpoint", kind: .manual)
        _ = try SpacesTestSupport.commitFiles(api, ["f": "2"], message: "c2")

        let snaps = try api.snapshots()
        #expect(snaps.contains { $0.oid == snap })
        let timeline = try api.timeline(limit: 50)
        #expect(!timeline.isEmpty)
    }

    @Test func rebaseOnto() throws {
        let (_, api, url) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f": "base"], message: "base")
        try api.createBranch("topic")
        try api.switchTo("topic")
        _ = try SpacesTestSupport.commitFiles(api, ["t": "topic"], message: "topic work")
        try api.switchTo("main")
        _ = try SpacesTestSupport.commitFiles(api, ["m": "main"], message: "main work")

        
        try api.switchTo("topic")
        _ = try api.rebase(onto: "main")
        #expect(try !api.repo.inRebase())
        #expect(try api.status().isClean)
        #expect(try FileManager.default.fileExists(
            atPath: url.appendingPathComponent("m").path))
        #expect(try FileManager.default.fileExists(
            atPath: url.appendingPathComponent("t").path))
    }

    @Test func reflogAndGraph() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f": "1"], message: "c1")
        try api.createBranch("b")
        _ = try SpacesTestSupport.commitFiles(api, ["f": "2"], message: "c2")

        let reflog = try api.reflog()
        #expect(reflog.count >= 2)
        let graph = try api.graph()
        #expect(graph.count >= 2)
        #expect(try api.describe().isEmpty == false)
    }

    @Test func blameAndShow() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        try SpacesTestSupport.write("alpha\nbeta\n", to: api.repo.worktreeURL.appendingPathComponent("f"))
        _ = try api.stageAll()
        _ = try api.commit(message: "first")
        try SpacesTestSupport.write("alpha\nbeta\ngamma\n", to: api.repo.worktreeURL.appendingPathComponent("f"))
        _ = try api.stageAll()
        _ = try api.commit(message: "second")

        let blame = try api.blame("f")
        #expect(blame.count == 3)
        let show = try api.show("HEAD")
        #expect(show.info.message.hasPrefix("second"))
    }

    @Test func mergeStrategyListingIsEngineBacked() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f": "1"], message: "c1")
        let strategies = api.mergeStrategies()
        #expect(strategies.map { $0.name } == ["ort", "recursive"])
        #expect(strategies.first { $0.name == "ort" }?.implemented == true)
        #expect(strategies.first { $0.name == "recursive" }?.implemented == false)
        #expect(api.defaultMergeStrategy().name == "ort")
        #expect(api.defaultMergeStrategy().implemented)
        let ort = try api.mergeStrategy(named: "ort")
        #expect(ort.implemented)
        let recursive = try api.mergeStrategy(named: "recursive")
        #expect(!recursive.implemented)
    }

    @Test func mergeStrategyUnknownNameThrows() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f": "1"], message: "c1")
        do {
            _ = try api.mergeStrategy(named: "bogus")
            Issue.record("expected unknown strategy to throw")
        } catch {
            #expect(String(describing: error).contains("bogus"))
            #expect(String(describing: error).contains("ort"))
        }
    }

    @Test func mergeWithUnknownStrategyThrowsBeforeWork() throws {
        let (repo, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f": "1"], message: "c1")
        let headBefore = try repo.refs.headOID(objects: repo.objects)
        do {
            _ = try MergeEngine(repo: repo).merge("main", strategy: "bogus")
            Issue.record("expected unknown strategy to throw")
        } catch {
            #expect(String(describing: error).contains("bogus"))
        }
        #expect(try repo.refs.headOID(objects: repo.objects) == headBefore)
        #expect(try api.log().count == 1)
    }

    @Test func mergeWithRecursiveStrategyIsRejected() throws {
        let (repo, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f": "1"], message: "c1")
        let headBefore = try repo.refs.headOID(objects: repo.objects)
        do {
            _ = try MergeEngine(repo: repo).merge("main", strategy: "recursive")
            Issue.record("expected unimplemented strategy to throw")
        } catch {
            #expect(String(describing: error).contains("recursive"))
            #expect(String(describing: error).contains("not implemented"))
        }
        #expect(try repo.refs.headOID(objects: repo.objects) == headBefore)
        #expect(try api.log().count == 1)
    }

    @Test func mergeWithExplicitOrtStrategySucceeds() throws {
        let (repo, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f": "1"], message: "base")
        try api.createBranch("side")
        try api.switchTo("side")
        _ = try SpacesTestSupport.commitFiles(api, ["g": "2"], message: "side work")
        try api.switchTo("main")
        let outcome = try MergeEngine(repo: repo).merge("side", strategy: "ort")
        guard case .fastForward = outcome.result else {
            Issue.record("expected fast-forward, got \(outcome.result)")
            return
        }
        #expect(try api.status().isClean)
    }
}
