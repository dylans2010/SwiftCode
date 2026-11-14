import Foundation
import Testing
@testable import SpacesEngine

@Suite struct AdvancedVCTests {
    @Test func multiRepoCommitAndRecover() throws {
        let (_, apiA, urlA) = try SpacesTestSupport.makeRepo()
        let (_, _, urlB) = try SpacesTestSupport.makeRepo()
        let apiB = try SpacesAPI.open(at: urlB.path)
        try SpacesTestSupport.write("a1\n", to: urlA.appendingPathComponent("a.txt"))
        try SpacesTestSupport.write("b1\n", to: urlB.appendingPathComponent("b.txt"))
        _ = try apiA.stageAll()
        _ = try apiB.stageAll()
        let result = try apiA.multiRepoCommit(repos: [urlA, urlB], message: "joint commit")
        #expect(result.bestEffort)
        #expect(result.committedCount == 2)
        #expect(result.results.allSatisfy { $0.committed != nil })
        #expect(try apiA.log().count == 1)
        #expect(try apiB.log().count == 1)
        let report = try apiA.multiRepoRecover(tx: result.tx)
        #expect(report.status == "committed")
        #expect(report.entries.allSatisfy { $0.state == "committed" })
    }

    @Test func branchCheckpointRestoresBytes() throws {
        let (_, api, url) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f.txt": "v1\n"], message: "base")
        let oid = try api.createBranchCheckpoint(branch: "main", name: "before-change")
        #expect(oid.hex.count == 64)
        let listed = try api.branchCheckpoints(branch: "main")
        #expect(listed.count == 1)
        #expect(listed[0].name == "before-change")
        _ = try SpacesTestSupport.commitFiles(api, ["f.txt": "v2\n"], message: "change")
        #expect(try String(contentsOf: url.appendingPathComponent("f.txt"), encoding: .utf8) == "v2\n")
        try api.restoreBranchCheckpoint(branch: "main", name: "before-change")
        #expect(try String(contentsOf: url.appendingPathComponent("f.txt"), encoding: .utf8) == "v1\n")
    }

    @Test func branchTimeTravelCreatesNewCommitWithOldTree() throws {
        let (_, api, url) = try SpacesTestSupport.makeRepo()
        let c1 = try SpacesTestSupport.commitFiles(api, ["f": "1"], message: "c1")
        let c2 = try SpacesTestSupport.commitFiles(api, ["f": "2"], message: "c2")
        let states = try api.branchStates(branch: "main")
        #expect(states.contains { $0.oid == c1 })
        let travelled = try api.timeTravelBranch(branch: "main", to: c1.hex)
        #expect(travelled != c1)
        #expect(try api.repo.commitObject(travelled).tree == api.repo.commitObject(c1).tree)
        #expect(try api.log().count == 3)
        #expect(try api.repo.commitObject(travelled).parents == [c2])
        #expect(try String(contentsOf: url.appendingPathComponent("f"), encoding: .utf8) == "1")
    }

    @Test func branchStackReportsAheadBehind() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f": "1"], message: "base")
        try api.createBranch("feature")
        try api.switchTo("feature")
        _ = try SpacesTestSupport.commitFiles(api, ["g": "2"], message: "feat")
        try api.switchTo("main")
        let stack = try api.createBranchStack(name: "work", branches: ["feature"], base: "main")
        #expect(stack.branches == ["feature"])
        #expect(try api.branchStacks().count == 1)
        let status = try api.branchStackStatus(name: "work")
        #expect(status.branches.count == 1)
        #expect(status.branches[0].ahead == 1)
        #expect(status.branches[0].behind == 0)
        let updated = try api.updateBranchStack(name: "work", branches: ["feature"])
        #expect(updated.branches == ["feature"])
    }

    @Test func changeSetGroupsAndStagesPaths() throws {
        let (_, api, url) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["a.txt": "1", "b.txt": "1"], message: "base")
        try SpacesTestSupport.write("2", to: url.appendingPathComponent("a.txt"))
        try SpacesTestSupport.write("2", to: url.appendingPathComponent("b.txt"))
        let set = try api.createChangeSet(name: "pair", description: "two files together")
        _ = try api.addToChangeSet(id: set.id, path: "a.txt")
        _ = try api.addToChangeSet(id: set.id, path: "b.txt")
        #expect(try api.changeSetPaths(id: set.id) == ["a.txt", "b.txt"])
        #expect(try api.changeSets().count == 1)
        let staged = try api.stageChangeSet(id: set.id)
        #expect(staged.contains("a.txt"))
        #expect(staged.contains("b.txt"))
        #expect(try api.status().staged.count == 2)
    }

    @Test func partialRestoreTouchesOnlySelectedPaths() throws {
        let (_, api, url) = try SpacesTestSupport.makeRepo()
        let c1 = try SpacesTestSupport.commitFiles(api, ["a": "1", "b": "1"], message: "c1")
        _ = try SpacesTestSupport.commitFiles(api, ["a": "2", "b": "2"], message: "c2")
        try SpacesTestSupport.write("3", to: url.appendingPathComponent("a"))
        let restored = try api.partialRestore(rev: c1.hex, paths: ["a"])
        #expect(restored == ["a"])
        #expect(try String(contentsOf: url.appendingPathComponent("a"), encoding: .utf8) == "1")
        #expect(try String(contentsOf: url.appendingPathComponent("b"), encoding: .utf8) == "2")
        #expect(try api.status().staged.contains { $0.path == "a" })
    }

    @Test func commitDependencyGraph() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        let c1 = try SpacesTestSupport.commitFiles(api, ["f": "1"], message: "c1")
        let c2 = try SpacesTestSupport.commitFiles(api, ["f": "2"], message: "c2")
        let dep = try api.addCommitDependency(from: c2.hex, to: c1.hex, kind: .dependsOn)
        #expect(dep.from == c2)
        #expect(dep.to == c1)
        #expect(dep.kind == .dependsOn)
        #expect(try api.commitDependencies(of: c2.hex).count == 1)
        #expect(try api.commitDependents(of: c1.hex).count == 1)
        #expect(try api.commitDependencies(of: c1.hex).isEmpty)
        #expect(throws: SpacesError.self) { try api.addCommitDependency(from: c2.hex, to: c1.hex, kind: .dependsOn) }
    }

    @Test func validationPolicyBlocksBadMessage() throws {
        let (_, api, url) = try SpacesTestSupport.makeRepo()
        try api.setCommitPolicies([
            ValidationPolicyOps.PolicyRule(id: "msg", kind: .messagePattern, pattern: #"^\[feat\]"#),
            ValidationPolicyOps.PolicyRule(id: "cat", kind: .requireCategory)
        ])
        #expect(try api.commitPolicies().count == 2)
        try SpacesTestSupport.write("x", to: url.appendingPathComponent("f"))
        _ = try api.stageAll()
        let violations = try api.validateCommit(message: "plain message")
        #expect(!violations.isEmpty)
        #expect(throws: SpacesError.self) { try api.commitValidated(message: "plain message") }
        let result = try api.commitValidated(message: "[feat] add thing")
        #expect(result.oid.hex.count == 64)
        #expect(try api.log().count == 1)
    }

    @Test func multiStageCommitFlow() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f": "1"], message: "base")
        try SpacesTestSupport.write("2", to: api.repo.worktreeURL.appendingPathComponent("f"))
        let tx = try api.prepareCommit(message: "[feat] staged change", paths: ["f"])
        #expect(!tx.isEmpty)
        let violations = try api.validateStagedCommit(tx: tx)
        #expect(violations.isEmpty)
        let preview = try api.previewStagedCommit(tx: tx)
        #expect(preview.files == 1)
        #expect(preview.added >= 1)
        let oid = try api.finalizeStagedCommit(tx: tx)
        #expect(oid.hex.count == 64)
        #expect(try api.log().first?.message == "[feat] staged change")
    }

    @Test func undoRestoresDeletedBranchAndRemovesCreatedBranch() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f": "1"], message: "base")
        _ = try api.createBranchUndoable(name: "temp")
        #expect(try api.branches().contains { $0.name == "temp" })
        let undoneCreate = try api.undoLast()
        #expect(undoneCreate.operation == "branch-create")
        #expect(try !api.branches().contains { $0.name == "temp" })

        try api.createBranch("gone")
        try api.deleteBranchUndoable(name: "gone", force: true)
        #expect(try !api.branches().contains { $0.name == "gone" })
        let undoneDelete = try api.undoLast()
        #expect(undoneDelete.operation == "branch-delete")
        #expect(try api.branches().contains { $0.name == "gone" })

        _ = try api.createTagUndoable(name: "v1")
        #expect(try api.tags().contains { $0.name == "v1" })
        _ = try api.undoLast()
        #expect(try !api.tags().contains { $0.name == "v1" })

        #expect(try api.undoableOperations().isEmpty)
        #expect(throws: SpacesError.self) { try api.undoLast() }
    }
}
