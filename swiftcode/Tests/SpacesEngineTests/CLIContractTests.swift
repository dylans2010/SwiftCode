import Foundation
import Testing
@testable import SpacesEngine

@Suite struct CLIContractTests {
    @Test func semanticSearchCommand() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, [
            "App.swift": "import Foundation\npublic struct Widget {\n    public func greet() -> String {\n        return \"hi\"\n    }\n}\n",
        ], message: "add app")
        let count = try api.refreshSymbolIndex()
        #expect(count > 0)
        let functions = try api.semanticSearch(query: "greet")
        #expect(functions.contains { $0.name == "greet" && $0.kind == .function && $0.file == "App.swift" })
        let structs = try api.semanticSearch(query: "Widget", kind: .structType)
        #expect(structs.contains { $0.name == "Widget" })
        let empty = try api.semanticSearch(query: "no-such-symbol-zzz")
        #expect(empty.isEmpty)
    }

    @Test func historySearchCommand() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        let first = try SpacesTestSupport.commitFiles(api, [
            "Main.swift": "import Foundation\nlet marker = \"alpha marker text\"\n",
        ], message: "first")
        _ = try SpacesTestSupport.commitFiles(api, [
            "Main.swift": "import Foundation\nlet marker = \"beta text\"\n",
        ], message: "second")
        let matches = try api.historySearch(query: "alpha marker")
        #expect(matches.contains { $0.commit == first && $0.path == "Main.swift" && $0.line == 2 })
        let regexMatches = try api.historySearch(query: "alp.a marker", useRegex: true)
        #expect(regexMatches.contains { $0.commit == first })
    }

    @Test func dependenciesCommand() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, [
            "A.swift": "import Foundation\npublic struct A {}\n",
            "B.swift": "import Alamofire\npublic struct B {}\n",
        ], message: "add modules")
        let graph = try api.refreshDependencyGraph()
        #expect(graph.edges.contains { $0.from == "A.swift" && $0.to == "Foundation" })
        #expect(graph.edges.contains { $0.from == "B.swift" && $0.to == "Alamofire" })
        let cached = try api.dependencyGraph()
        #expect(cached.edges.count == graph.edges.count)
    }

    @Test func fileEvolutionCommand() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["Old.swift": "public struct Old {}\n"], message: "add old")
        try api.move("Old.swift", "New.swift")
        _ = try api.commit(message: "rename file")
        let steps = try api.fileEvolution(path: "New.swift")
        #expect(steps.count >= 2)
        #expect(steps.first?.change == .renamed)
        #expect(steps.first?.oldPath == "Old.swift")
        #expect(steps.last?.change == .added)
    }

    @Test func branchStackCommand() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["a.txt": "one\n"], message: "base")
        _ = try api.createBranch("feature")
        let record = try api.createBranchStack(name: "stack", branches: ["feature"], base: "main")
        #expect(record.name == "stack")
        #expect(record.branches == ["feature"])
        #expect(record.base == "main")
        let stacks = try api.branchStacks()
        #expect(stacks.contains { $0.name == "stack" })
        let status = try api.branchStackStatus(name: "stack")
        #expect(status.branches.count == 1)
        #expect(status.branches.first?.branch == "feature")
        #expect(status.branches.first?.parent == "main")
        let updated = try api.updateBranchStack(name: "stack", branches: ["feature"])
        #expect(updated.branches == ["feature"])
    }

    @Test func branchCheckpointCommand() throws {
        let (_, api, url) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["notes.txt": "version one\n"], message: "first")
        let oid = try api.createBranchCheckpoint(branch: "main", name: "cp1")
        #expect(oid.hex.count == 64)
        let checkpoints = try api.branchCheckpoints(branch: "main")
        #expect(checkpoints.contains { $0.name == "cp1" && $0.oid == oid })
        _ = try SpacesTestSupport.commitFiles(api, ["notes.txt": "version two\n"], message: "second")
        try api.restoreBranchCheckpoint(branch: "main", name: "cp1")
        let contents = try String(contentsOf: url.appendingPathComponent("notes.txt"), encoding: .utf8)
        #expect(contents == "version one\n")
    }

    @Test func changesetCommand() throws {
        let (_, api, url) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["notes.txt": "base\n"], message: "base")
        try SpacesTestSupport.write("edited\n", to: url.appendingPathComponent("notes.txt"))
        let record = try api.createChangeSet(name: "work", description: "daily work")
        #expect(record.name == "work")
        let updated = try api.addToChangeSet(id: record.id, path: "notes.txt")
        #expect(updated.paths == ["notes.txt"])
        #expect(try api.changeSets().contains { $0.id == record.id })
        #expect(try api.changeSetPaths(id: record.id) == ["notes.txt"])
        let staged = try api.stageChangeSet(id: record.id)
        #expect(staged == ["notes.txt"])
        #expect(try api.status().staged.map { $0.path }.contains("notes.txt"))
    }

    @Test func provenanceCommand() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        let oid = try SpacesTestSupport.commitFiles(api, ["a.txt": "one\n"], message: "base")
        let checks = try api.verifyProvenance(rev: oid.hex)
        #expect(checks.contains { $0.name == "commit-exists" && $0.passed })
    }

    @Test func policyCommand() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["a.txt": "one\n"], message: "base")
        let policy = try api.repositoryPolicy()
        #expect(policy.rules.isEmpty)
        let violations = try api.checkPolicy(
            operation: .commit,
            details: PolicyEngineOps.PolicyOperationDetails(message: "hello", paths: ["a.txt"]))
        #expect(violations.isEmpty)
    }

    @Test func securityReportCommand() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["a.txt": "one\n"], message: "base")
        let report = try api.generateSecurityReport()
        #expect(report.generatedAt > 0)
        #expect(report.secretFindingCount == 0)
        #expect(report.secretFindings.isEmpty)
    }

    @Test func secretHistoryCommand() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["a.txt": "one\n"], message: "base")
        let findings = try api.secretHistory(limit: 100)
        #expect(findings.isEmpty)
    }

    @Test func ownershipCommand() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["src/a.txt": "one\n"], message: "base")
        #expect(try api.ownershipRules().isEmpty)
        #expect(try api.ownersOf(path: "src/a.txt").isEmpty)
    }

    @Test func reviewCommand() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        let first = try SpacesTestSupport.commitFiles(api, ["a.txt": "one\n"], message: "base")
        let second = try SpacesTestSupport.commitFiles(api, ["a.txt": "two\n"], message: "second")
        let review = try api.createReview(title: "Add feature", base: first.hex, head: second.hex)
        #expect(review.title == "Add feature")
        #expect(review.status == .open)
        #expect(try api.listReviews().contains { $0.id == review.id })
        #expect(try api.reviewStatus(id: review.id) == .open)
        let approved = try api.approveReview(id: review.id, reviewer: "Dylan")
        #expect(approved.status == .approved)
        #expect(approved.approvals.contains { $0.reviewer == "Dylan" })
        #expect(try api.reviewStatus(id: review.id) == .approved)
    }

    @Test func reviewStatusCommand() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        let first = try SpacesTestSupport.commitFiles(api, ["a.txt": "one\n"], message: "base")
        let review = try api.createReview(title: "Check me", base: first.hex, head: first.hex)
        let status = try api.reviewStatus(id: review.id)
        #expect(status == .open)
        #expect(status.rawValue == "open")
    }

    @Test func discussionCommand() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        let first = try SpacesTestSupport.commitFiles(api, ["a.txt": "one\n"], message: "base")
        let review = try api.createReview(title: "Discuss", base: first.hex, head: first.hex)
        let comment = try api.addComment(review: review.id, path: "a.txt", line: 1, body: "Looks good")
        #expect(comment.body == "Looks good")
        #expect(comment.resolved == false)
        let comments = try api.listComments(review: review.id)
        #expect(comments.contains { $0.id == comment.id })
        let resolved = try api.resolveComment(review: review.id, id: comment.id)
        #expect(resolved.resolved == true)
    }

    @Test func notificationsCommand() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["a.txt": "one\n"], message: "base")
        _ = try api.notificationRules()
        let pending = try api.pendingNotifications()
        #expect(pending.isEmpty)
        try api.markNotificationsSeen()
        #expect(try api.pendingNotifications().isEmpty)
    }

    @Test func backupCommand() throws {
        let (_, api, url) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["a.txt": "one\n"], message: "base")
        let path = url.appendingPathComponent("backup.spacesbundle").path
        let manifest = try api.createBackup(to: path)
        #expect(!manifest.objects.isEmpty)
        #expect(FileManager.default.fileExists(atPath: path))
        let verified = try api.verifyBackup(url: path)
        #expect(verified.objectCount == manifest.objects.count)
        #expect(try api.backups().contains { $0.id == manifest.id })
        let restored = try api.restoreBackup(url: path)
        #expect(restored.objectCount == manifest.objects.count)
    }

    @Test func storageHeatmapCommand() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["a.txt": "one\n"], message: "base")
        let heatmap = try api.storageHeatmap()
        #expect(heatmap.totalObjects > 0)
        #expect(heatmap.totalBytes > 0)
        #expect(heatmap.reachableBytes + heatmap.unreachableBytes == heatmap.totalBytes)
    }

    @Test func storageProfileCommand() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["a.txt": "one\n"], message: "base")
        let profiles = try api.compactionProfiles()
        #expect(profiles.contains { $0.name == "read-optimized" })
        #expect(profiles.contains { $0.name == "size-optimized" })
        let result = try api.applyCompactionProfile(name: "read-optimized")
        #expect(result.profile == "read-optimized")
        #expect(result.objectsAfter <= result.objectsBefore)
    }

    @Test func workspaceTemplateCommand() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["a.txt": "one\n"], message: "base")
        let template = try api.createWorkspaceTemplate(name: "standard", config: WorkspaceTemplateOps.Config())
        #expect(template.name == "standard")
        #expect(template.defaultBranch == "main")
        #expect(try api.workspaceTemplates().contains { $0.name == "standard" })
        try api.applyWorkspaceTemplate(name: "standard")
        #expect(try api.workspaceTemplates().contains { $0.name == "standard" })
    }

    @Test func automationCommand() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["a.txt": "one\n"], message: "base")
        #expect(try api.automationPipelines().isEmpty)
        let results = try api.runAutomation(event: .postCommit)
        #expect(results.isEmpty)
    }

    @Test func patchCollectionCommand() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        let first = try SpacesTestSupport.commitFiles(api, ["a.txt": "one\n"], message: "base")
        let second = try SpacesTestSupport.commitFiles(api, ["a.txt": "one\ntwo\n"], message: "second")
        let collection = try api.createPatchCollection(name: "feature-patches", from: first.hex, to: second.hex)
        #expect(collection.name == "feature-patches")
        #expect(collection.patches.count == 1)
        #expect(try api.patchCollections().contains { $0.name == "feature-patches" })
        try api.reset(to: first.hex, mode: .hard)
        let applied = try api.applyPatchCollection(name: "feature-patches")
        #expect(applied.contains("a.txt"))
        #expect(try api.status().unstaged.map { $0.path }.contains("a.txt"))
    }

    @Test func symbolHistoryCommand() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, [
            "App.swift": "import Foundation\npublic func greet() -> String {\n    return \"hi\"\n}\n",
        ], message: "add greet")
        _ = try SpacesTestSupport.commitFiles(api, [
            "App.swift": "import Foundation\npublic func greet() -> String {\n    return \"hello\"\n}\n",
        ], message: "change greet")
        let entries = try api.symbolHistory(symbol: "greet", path: "App.swift")
        #expect(entries.count == 2)
        #expect(entries.allSatisfy { $0.declaration.name == "greet" })
        #expect(entries.allSatisfy { $0.path == "App.swift" })
    }

    @Test func apiCompatibilityCommand() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        let first = try SpacesTestSupport.commitFiles(api, [
            "App.swift": "import Foundation\npublic func greet() -> String {\n    return \"hi\"\n}\n",
        ], message: "add greet")
        let second = try SpacesTestSupport.commitFiles(api, [
            "App.swift": "import Foundation\npublic struct Widget {}\n",
        ], message: "remove greet")
        let changes = try api.apiCompatibilityBetween(from: first.hex, to: second.hex)
        #expect(changes.contains { $0.name == "greet" && $0.change == .removed && $0.breaking })
    }

    @Test func testProvenanceCommand() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        let oid = try SpacesTestSupport.commitFiles(api, ["a.txt": "one\n"], message: "base")
        try api.recordTestResult(commit: oid, suite: "UnitTests", passed: 12, failed: 1)
        let records = try api.testResultsFor(commit: oid)
        #expect(records.contains { $0.suite == "UnitTests" && $0.passed == 12 && $0.failed == 1 })
    }

    @Test func buildImpactCommand() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        let oid = try SpacesTestSupport.commitFiles(api, ["a.txt": "one\n"], message: "base")
        try api.recordBuildResult(commit: oid, result: .success, durationMs: 1234, failures: [])
        try api.recordBuildResult(commit: oid, result: .failure, durationMs: 500, failures: ["link error"])
        let history = try api.buildHistory(commit: oid)
        #expect(history.contains { $0.result == .success && $0.durationMs == 1234 })
        #expect(history.contains { $0.result == .failure && $0.failures == ["link error"] })
    }

    @Test func performanceCommand() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["a.txt": "one\n"], message: "base")
        let sample = try api.profileOperation(.status)
        #expect(sample.operation == "status")
        #expect(sample.durationMs >= 0)
        #expect(sample.objectCount > 0)
        for operation in PerformanceProfilerOps.ProfileOperation.allCases {
            #expect(try api.profileOperation(operation).operation == operation.rawValue)
        }
        let summaries = try api.performanceProfile()
        #expect(summaries.contains { $0.operation == "status" && $0.samples >= 1 })
    }

    @Test func operationUndoCommand() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["a.txt": "one\n"], message: "base")
        _ = try api.createBranchUndoable(name: "undo-branch")
        #expect(try api.branches().contains { $0.name == "undo-branch" })
        #expect(try api.undoableOperations().contains { $0.operation == "branch-create" && $0.target == "undo-branch" })
        let undone = try api.undoLast()
        #expect(undone.operation == "branch-create")
        #expect(undone.target == "undo-branch")
        #expect(!(try api.branches().contains { $0.name == "undo-branch" }))
    }

    @Test func snapshotsAliasCommand() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["a.txt": "one\n"], message: "base")
        let oid = try api.snapshot(message: "manual snap")
        #expect(oid.hex.count == 64)
        #expect(try api.snapshots().contains { $0.oid == oid })
    }

    @Test func historyAliasCommand() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        let first = try SpacesTestSupport.commitFiles(api, ["a.txt": "one\n"], message: "first")
        _ = try SpacesTestSupport.commitFiles(api, ["a.txt": "two\n"], message: "second")
        let log = try api.log(limit: 100)
        #expect(log.count >= 2)
        #expect(log.contains { $0.oid == first })
    }

    @Test func workspaceSwitchResolvesRegisteredWorktree() throws {
        let (_, api, url) = try SpacesTestSupport.makeRepo()
        let head = try SpacesTestSupport.commitFiles(api, ["a.txt": "one\n"], message: "base")
        let main = try api.resolveWorktree("main")
        #expect(main.name == "main")
        #expect(main.path == api.repo.worktreeURL.path)
        #expect(main.branch == "main")
        #expect(main.headOID == head.hex)
        let wtPath = URL(fileURLWithPath: url.appendingPathComponent("wt-side").path).standardizedFileURL.path
        let added = try api.addWorktree(path: wtPath, newBranch: "side")
        #expect(added.name == "wt-side")
        let byName = try api.resolveWorktree("wt-side")
        #expect(byName.path == wtPath)
        #expect(byName.branch == "side")
        #expect(byName.headOID == head.hex)
        let byPath = try api.resolveWorktree(wtPath)
        #expect(byPath.name == "wt-side")
        #expect(byPath.headOID == head.hex)
    }

    @Test func workspaceSwitchRejectsUnknownWorktree() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["a.txt": "one\n"], message: "base")
        do {
            _ = try api.resolveWorktree("no-such-worktree")
            Issue.record("expected unknown worktree to throw")
        } catch {
            #expect(String(describing: error).contains("no-such-worktree"))
            #expect(String(describing: error).contains("main"))
        }
    }
}
