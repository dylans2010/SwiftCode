import Foundation
import Testing
@testable import SpacesEngine

@Suite struct EndToEndScenarioTests {
    struct StepFailure: Error, CustomStringConvertible {
        var step: Int
        var label: String
        var underlying: Error
        var description: String {
            "step \(step) (\(label)) failed: \(underlying)"
        }
    }

    @Test func thirtyStepAcceptanceScenario() async throws {
        let (_, api, url) = try SpacesTestSupport.makeRepo()
        let appOriginal = "import Foundation\npublic struct Widget {\n    public func greet() -> String {\n        return \"hi\"\n    }\n}\n"
        let appFeature = "import Foundation\npublic struct Widget {\n    public func greet() -> String {\n        return \"hi\"\n    }\n    public func farewell() -> String {\n        return \"bye\"\n    }\n}\n"
        var expectedCount = 0
        var expectedMessages: [String] = []
        var featureOID: ObjectID?
        var topicOID: ObjectID?
        var mergeOID: ObjectID?
        var snapOID: ObjectID?
        var checkpointOID: ObjectID?
        var bundlePath = ""
        var backupPath = ""
        var remoteURL = url
        var cloneURL = url

        func runStep(_ n: Int, _ label: String, _ body: () async throws -> Void) async throws {
            do {
                try await body()
            } catch {
                throw StepFailure(step: n, label: label, underlying: error)
            }
        }

        try await runStep(1, "init") {
            #expect(Repository.isRepository(at: url))
            #expect(try api.validate().isEmpty)
            #expect(try api.info().branch == "main")
        }

        try await runStep(2, "add files") {
            try SpacesTestSupport.write(appOriginal, to: url.appendingPathComponent("App.swift"))
            try SpacesTestSupport.write("Spaces end to end\n", to: url.appendingPathComponent("README.md"))
            try SpacesTestSupport.write("debug\n", to: url.appendingPathComponent("config.txt"))
            let staged = try api.stageAll()
            #expect(staged.count == 3)
            #expect(try api.status().staged.count == 3)
        }

        try await runStep(3, "commit") {
            let oid = try api.commit(message: "step 3 initial commit").oid
            #expect(oid.hex.count == 64)
            expectedCount += 1
            expectedMessages.append("step 3 initial commit")
            #expect(try api.log().count == 1)
            #expect(try api.status().isClean)
        }

        try await runStep(4, "branch") {
            try api.createBranch("feature")
            #expect(try api.branches().map(\.name).contains("feature"))
        }

        try await runStep(5, "switch") {
            try api.switchTo("feature")
            #expect(try api.status().branch == "feature")
        }

        try await runStep(6, "edit and commit on branch") {
            try SpacesTestSupport.write(appFeature, to: url.appendingPathComponent("App.swift"))
            featureOID = try api.commit(message: "step 6 feature work").oid
            expectedCount += 1
            expectedMessages.append("step 6 feature work")
            #expect(try api.log().count == 2)
            #expect(try String(contentsOf: url.appendingPathComponent("App.swift"), encoding: .utf8).contains("farewell"))
        }

        try await runStep(7, "switch back") {
            try api.switchTo("main")
            #expect(try api.status().branch == "main")
            #expect(try api.log().count == 1)
            #expect(try !String(contentsOf: url.appendingPathComponent("App.swift"), encoding: .utf8).contains("farewell"))
        }

        try await runStep(8, "merge") {
            let outcome = try api.merge("feature")
            guard case .fastForward = outcome.result else {
                throw SpacesError.invalidArgument("expected fast-forward, got \(outcome.result)")
            }
            #expect(try api.log().count == 2)
            #expect(try String(contentsOf: url.appendingPathComponent("App.swift"), encoding: .utf8).contains("farewell"))
            #expect(try api.status().isClean)
        }

        try await runStep(9, "conflict and resolve") {
            try api.createBranch("topic")
            try api.switchTo("topic")
            topicOID = try SpacesTestSupport.commitFiles(api, ["config.txt": "topic\n"], message: "step 9 topic change")
            expectedCount += 1
            expectedMessages.append("step 9 topic change")
            try api.switchTo("main")
            _ = try SpacesTestSupport.commitFiles(api, ["config.txt": "main\n"], message: "step 9 main change")
            expectedCount += 1
            expectedMessages.append("step 9 main change")
            let outcome = try api.merge("topic")
            #expect(!outcome.conflicts.isEmpty)
            #expect(outcome.conflicts.contains { $0.path == "config.txt" })
            #expect(try api.repo.inMerge())
            #expect(try String(contentsOf: url.appendingPathComponent("config.txt"), encoding: .utf8).contains("<<<<<<<"))
            try SpacesTestSupport.write("resolved\n", to: url.appendingPathComponent("config.txt"))
            _ = try api.add("config.txt")
            mergeOID = try api.mergeContinue()
            expectedCount += 1
            #expect(try !api.repo.inMerge())
            #expect(try String(contentsOf: url.appendingPathComponent("config.txt"), encoding: .utf8) == "resolved\n")
            #expect(try api.status().isClean)
            #expect(try api.log().count == expectedCount)
        }

        try await runStep(10, "tag") {
            _ = try api.createTag("v1.0", annotated: true, message: "release 1.0")
            let tags = try api.tags()
            #expect(tags.contains { $0.name == "v1.0" && $0.isAnnotated })
            #expect(tags.first { $0.name == "v1.0" }?.peeled == mergeOID)
        }

        try await runStep(11, "snapshot") {
            snapOID = try api.snapshot(message: "step 11 snapshot", kind: .manual)
            #expect(try api.snapshots().contains { $0.oid == snapOID })
        }

        try await runStep(12, "modify and restore snapshot") {
            try SpacesTestSupport.write("garbage garbage\n", to: url.appendingPathComponent("App.swift"))
            try api.restoreSnapshot((try #require(snapOID)).hex)
            let restored = try String(contentsOf: url.appendingPathComponent("App.swift"), encoding: .utf8)
            #expect(restored.contains("farewell"))
            #expect(!restored.contains("garbage"))
            #expect(try api.status().isClean)
        }

        try await runStep(13, "timeline shows entries") {
            let timeline = try api.timeline(limit: 100)
            #expect(timeline.contains { $0.oid == snapOID && $0.kind == .snapshot })
            #expect(timeline.contains { $0.kind == .commit })
            #expect(timeline.count >= expectedCount + 1)
        }

        try await runStep(14, "semantic search finds a symbol") {
            #expect(try api.refreshSymbolIndex() > 0)
            let symbols = try api.semanticSearch(query: "greet")
            #expect(symbols.contains { $0.name == "greet" && $0.kind == .function && $0.file == "App.swift" })
        }

        try await runStep(15, "history search finds a commit") {
            let matches = try api.historySearch(query: "topic")
            #expect(matches.contains { $0.commit == topicOID && $0.path == "config.txt" })
        }

        try await runStep(16, "impact analysis") {
            let impact = try api.changeImpact(rev: (try #require(featureOID)).hex)
            #expect(impact.commit == featureOID)
            #expect(impact.changedFiles.contains("App.swift"))
            #expect(impact.declaredSymbols.contains { $0.name == "greet" })
            #expect(impact.directories.contains("."))
        }

        try await runStep(17, "checkpoint create and restore") {
            checkpointOID = try api.createRecoveryCheckpoint(operation: "e2e checkpoint")
            #expect(try api.recoveryCheckpoints().contains { $0.oid == checkpointOID })
            try SpacesTestSupport.write(appFeature + "public let extra = 1\n", to: url.appendingPathComponent("App.swift"))
            #expect(try String(contentsOf: url.appendingPathComponent("App.swift"), encoding: .utf8).contains("extra"))
            try api.restoreRecoveryCheckpoint((try #require(checkpointOID)).hex)
            let restored = try String(contentsOf: url.appendingPathComponent("App.swift"), encoding: .utf8)
            #expect(restored.contains("farewell"))
            #expect(!restored.contains("extra"))
        }

        try await runStep(18, "review create and approve") {
            let review = try api.createReview(title: "e2e review", base: "HEAD~1", head: "HEAD")
            #expect(review.status == .open)
            _ = try api.addComment(review: review.id, path: "App.swift", line: 2, body: "Reviewed in the acceptance scenario.")
            #expect(try api.listComments(review: review.id).count == 1)
            let approved = try api.approveReview(id: review.id, reviewer: "Test User")
            #expect(approved.status == .approved)
            #expect(try api.reviewStatus(id: review.id) == .approved)
            let check = try api.reviewMergeCheck(id: review.id)
            #expect(check.allowed == true)
            #expect(check.reasons.isEmpty)
            #expect(try api.changesSinceApproval(review: review.id).isEmpty)
        }

        try await runStep(19, "security scan and report") {
            _ = try SpacesTestSupport.commitFiles(api, [
                "secrets.txt": "aws_access_key_id = \"AKIA1234567890ABCDEF\"\n",
            ], message: "step 19 add key for scan")
            expectedCount += 1
            expectedMessages.append("step 19 add key for scan")
            let findings = try api.secretHistory()
            #expect(findings.contains { $0.path == "secrets.txt" && $0.patternName == "aws-access-key" })
            let report = try api.generateSecurityReport()
            #expect(report.secretFindingCount >= 1)
            #expect(report.secretFindings.contains { $0.path == "secrets.txt" })
        }

        try await runStep(20, "backup create and verify") {
            let dir = try SpacesTestSupport.tempDir()
            backupPath = dir.appendingPathComponent("e2e.spbd").path
            let manifest = try api.createBackup(to: backupPath)
            #expect(!manifest.objects.isEmpty)
            #expect(try api.verifyBackup(url: backupPath).objectCount > 0)
            #expect(try api.backups().contains { $0.id == manifest.id })
            let (_, freshBackupAPI, _) = try SpacesTestSupport.makeRepo()
            let restored = try freshBackupAPI.restoreBackup(url: backupPath)
            #expect(restored.objectCount > 0)
            #expect(try freshBackupAPI.log().count == expectedCount)
        }

        try await runStep(21, "storage report") {
            let storage = try api.storage()
            #expect(storage.total > 0)
            #expect(storage.objects > 0)
            let counts = try api.countObjects()
            #expect(counts.total > 0)
            #expect(counts.commits == expectedCount)
            #expect(try api.storageHeatmap().totalObjects > 0)
        }

        try await runStep(22, "fsck clean") {
            #expect(try api.fsck().isEmpty)
            #expect(try api.validate().isEmpty)
            #expect(try api.diagnose().allSatisfy { $0.level != .error })
        }

        try await runStep(23, "export bundle") {
            let dir = try SpacesTestSupport.tempDir()
            bundlePath = dir.appendingPathComponent("e2e.spbd").path
            try BundleOps.create(repo: api.repo, output: bundlePath)
            #expect(FileManager.default.fileExists(atPath: bundlePath))
            let verified = try BundleOps.verify(path: bundlePath)
            #expect(verified.objectCount > 0)
            #expect(verified.refs["refs/heads/main"] != nil)
            #expect(verified.refs["refs/tags/v1.0"] != nil)
        }

        try await runStep(24, "import bundle into fresh repo") {
            let (freshRepo, freshAPI, freshURL) = try SpacesTestSupport.makeRepo()
            let imported = try BundleOps.importBundle(into: freshRepo, path: bundlePath)
            #expect(imported.refs["refs/heads/main"] != nil)
            #expect(try freshAPI.log().map(\.oid) == api.log().map(\.oid))
            #expect(try freshAPI.tags().contains { $0.name == "v1.0" })
            try freshAPI.reset(to: "HEAD", mode: .hard)
            #expect(try String(contentsOf: freshURL.appendingPathComponent("README.md"), encoding: .utf8) == "Spaces end to end\n")
            #expect(try String(contentsOf: freshURL.appendingPathComponent("App.swift"), encoding: .utf8).contains("farewell"))
        }

        try await runStep(25, "remote add push and clone") {
            let (_, _, remote) = try SpacesTestSupport.makeRepo()
            remoteURL = remote
            try api.addRemote("origin", url: remoteURL.path)
            let push = try api.push("origin", refspec: "main")
            #expect(push.refsUpdated.contains("refs/heads/main"))
            let cloneBase = try SpacesTestSupport.tempDir()
            cloneURL = cloneBase.appendingPathComponent("cloned")
            let cloned = try CloneOps.clone(url: remoteURL.path, into: cloneURL)
            let clonedAPI = SpacesAPI(repo: cloned)
            #expect(try clonedAPI.log().map(\.oid) == api.log().map(\.oid))
            #expect(try String(contentsOf: cloneURL.appendingPathComponent("README.md"), encoding: .utf8) == "Spaces end to end\n")
        }

        try await runStep(26, "git import") {
            guard let git = SpacesValidationSupport.gitExecutable() else {
                Issue.record("step 26 (git import): git executable not found in this environment; step not executed")
                return
            }
            let (gitDir, _) = try SpacesValidationSupport.makeGitRepo(
                git: git, files: ["hello.txt": "hello git\n"], message: "git one", secondMessage: "git two")
            let (_, gitAPI, _) = try SpacesTestSupport.makeRepo()
            let report = try gitAPI.importGit(at: gitDir.path)
            #expect(report.commits == 2)
            #expect(try gitAPI.log().count == 2)
        }

        try await runStep(27, "git export") {
            guard let git = SpacesValidationSupport.gitExecutable() else {
                Issue.record("step 27 (git export): git executable not found in this environment; step not executed")
                return
            }
            let dest = try SpacesTestSupport.tempDir().appendingPathComponent("exported")
            let report = try api.exportGit(to: dest.path)
            #expect(report.objectsWritten > 0)
            let log = try SpacesValidationSupport.runGit(git, ["-C", dest.path, "log", "--format=%s"], cwd: dest)
            #expect(log.contains("step 3 initial commit"))
            #expect(log.contains("step 6 feature work"))
            let tags = try SpacesValidationSupport.runGit(git, ["-C", dest.path, "tag", "--list"], cwd: dest)
            #expect(tags.contains("v1.0"))
        }

        try await runStep(28, "reopen repo") {
            let reopened = try Repository.open(at: url)
            let reopenedAPI = SpacesAPI(repo: reopened)
            #expect(try reopened.refs.headOID(objects: reopened.objects) == reopenedAPI.log()[0].oid)
            #expect(try reopenedAPI.log()[0].message.hasPrefix("step 19 add key for scan"))
            #expect(try reopenedAPI.log().count == expectedCount)
            #expect(try String(contentsOf: url.appendingPathComponent("App.swift"), encoding: .utf8).contains("farewell"))
            #expect(try reopenedAPI.snapshots().contains { $0.oid == snapOID })
        }

        try await runStep(29, "concurrent read safety") {
            let expected = try api.log().count
            let counts = try await withThrowingTaskGroup(of: Int.self) { group in
                for _ in 0..<4 {
                    group.addTask { try api.log().count }
                }
                var collected: [Int] = []
                for try await count in group { collected.append(count) }
                return collected
            }
            #expect(counts.count == 4)
            #expect(counts.allSatisfy { $0 == expected })
            #expect(try api.fsck().isEmpty)
        }

        try await runStep(30, "full log and history intact") {
            let log = try api.log()
            #expect(log.count == expectedCount)
            for message in expectedMessages {
                #expect(log.contains { $0.message.hasPrefix(message) })
            }
            #expect(try api.reflog().count >= expectedCount)
            #expect(try api.graph().count >= expectedCount)
            #expect(try api.info().headOID == log[0].oid.hex)
            #expect(try api.status().isClean)
            #expect(try api.timeline(limit: 100).count >= expectedCount + 1)
        }
    }
}
