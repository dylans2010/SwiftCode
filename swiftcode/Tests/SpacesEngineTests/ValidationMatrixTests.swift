import Foundation
import Testing
@testable import SpacesEngine

enum SpacesValidationSupport {
    static func gitExecutable() -> String? {
        for path in ["/usr/bin/git", "/opt/homebrew/bin/git", "/usr/local/bin/git"] {
            if FileManager.default.isExecutableFile(atPath: path) { return path }
        }
        guard let pathEnv = ProcessInfo.processInfo.environment["PATH"] else { return nil }
        for dir in pathEnv.components(separatedBy: ":") {
            let candidate = dir + "/git"
            if FileManager.default.isExecutableFile(atPath: candidate) { return candidate }
        }
        return nil
    }

    static func requireGit() throws -> String {
        if let git = gitExecutable() { return git }
        try Test.skip("git executable not found; Git import and export cannot be validated in this environment")
        throw SpacesError.migrationError("git executable not found")
    }

    @discardableResult
    static func runGit(_ git: String, _ args: [String], cwd: URL) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: git)
        process.arguments = args
        process.currentDirectoryURL = cwd
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        try process.run()
        process.waitUntilExit()
        let out = String(decoding: outPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        let err = String(decoding: errPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        guard process.terminationStatus == 0 else {
            throw SpacesError.invalidArgument("git \(args.joined(separator: " ")) failed: \(err)")
        }
        return out
    }

    static func makeGitRepo(files: [String: String], message: String, secondMessage: String? = nil) throws -> (URL, String) {
        let git = try requireGit()
        return try makeGitRepo(git: git, files: files, message: message, secondMessage: secondMessage)
    }

    static func makeGitRepo(git: String, files: [String: String], message: String, secondMessage: String? = nil) throws -> (URL, String) {
        let dir = try SpacesTestSupport.tempDir()
        _ = try runGit(git, ["init", "-q"], cwd: dir)
        _ = try runGit(git, ["symbolic-ref", "HEAD", "refs/heads/main"], cwd: dir)
        _ = try runGit(git, ["config", "user.name", "Test User"], cwd: dir)
        _ = try runGit(git, ["config", "user.email", "test@example.com"], cwd: dir)
        for (path, contents) in files {
            try SpacesTestSupport.write(contents, to: dir.appendingPathComponent(path))
        }
        _ = try runGit(git, ["add", "."], cwd: dir)
        _ = try runGit(git, ["commit", "-q", "-m", message], cwd: dir)
        if let second = secondMessage {
            try SpacesTestSupport.write("second change\n", to: dir.appendingPathComponent("second.txt"))
            _ = try runGit(git, ["add", "."], cwd: dir)
            _ = try runGit(git, ["commit", "-q", "-m", second], cwd: dir)
        }
        return (dir, git)
    }
}

@Suite struct ValidationMatrixTests {
    @Test func initCreatesRepositoryAndReopens() throws {
        let (_, api, url) = try SpacesTestSupport.makeRepo()
        #expect(Repository.isRepository(at: url))
        #expect(try api.validate().isEmpty)
        let info = try api.info()
        #expect(info.branch == "main")
        #expect(info.headOID == nil)
        #expect(info.formatVersion == RepositoryFormat.formatVersion)
        let reopened = try Repository.open(at: url)
        #expect(reopened.worktreeURL == api.repo.worktreeURL)
        #expect(try SpacesAPI(repo: reopened).validate().isEmpty)
    }

    @Test func initRejectsSecondInitAtSamePath() throws {
        let (_, _, url) = try SpacesTestSupport.makeRepo()
        #expect(throws: SpacesError.self) {
            _ = try Repository.create(at: url, user: SpacesConfig.User(name: "T", email: "t@example.com"))
        }
    }

    @Test func stageAddTracksFile() throws {
        let (_, api, url) = try SpacesTestSupport.makeRepo()
        try SpacesTestSupport.write("hello\n", to: url.appendingPathComponent("a.txt"))
        #expect(try api.status().untrackedFiles.count == 1)
        let staged = try api.add("a.txt")
        #expect(staged.contains("a.txt"))
        let status = try api.status()
        #expect(status.staged.count == 1)
        #expect(status.untrackedFiles.isEmpty)
    }

    @Test func commitCreatesLogEntry() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        let result = try SpacesTestSupport.commitFiles(api, ["f": "1"], message: "matrix commit")
        #expect(result.hex.count == 64)
        let log = try api.log()
        #expect(log.count == 1)
        #expect(log[0].oid == result)
        #expect(log[0].message.hasPrefix("matrix commit"))
        #expect(try api.status().isClean)
    }

    @Test func commitRejectsEmptyChange() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        #expect(throws: SpacesError.self) { _ = try api.commit(message: "nothing staged") }
    }

    @Test func branchCreateSwitchAndDelete() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        let base = try SpacesTestSupport.commitFiles(api, ["f": "1"], message: "base")
        try api.createBranch("feature")
        try api.switchTo("feature")
        _ = try SpacesTestSupport.commitFiles(api, ["g": "2"], message: "feature work")
        try api.switchTo("main")
        #expect(try api.repo.refs.headOID(objects: api.repo.objects) == base)
        #expect(try !FileManager.default.fileExists(
            atPath: api.repo.worktreeURL.appendingPathComponent("g").path))
        let names = try api.branches().map(\.name)
        #expect(names.contains("feature"))
        #expect(names.contains("main"))
        try api.deleteBranch("feature", force: true)
        #expect(try api.branches().allSatisfy { $0.name != "feature" })
    }

    @Test func diffBetweenCommitsShowsChange() throws {
        let (_, api, url) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f": "1\n"], message: "base")
        _ = try SpacesTestSupport.commitFiles(api, ["f": "2\n"], message: "change")
        let diffs = try api.diff("HEAD~1")
        let file = try #require(diffs.first { $0.newPath == "f" })
        #expect(file.status == .modified)
        #expect(file.added >= 1)
        #expect(file.removed >= 1)
        try SpacesTestSupport.write("3\n", to: url.appendingPathComponent("f"))
        #expect(try !api.diff().isEmpty)
    }

    @Test func mergeCleanThreeWay() throws {
        let (_, api, url) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["a": "1", "b": "1"], message: "base")
        try api.createBranch("feature")
        try api.switchTo("feature")
        _ = try SpacesTestSupport.commitFiles(api, ["a": "feature"], message: "feature a")
        try api.switchTo("main")
        _ = try SpacesTestSupport.commitFiles(api, ["b": "main"], message: "main b")
        let outcome = try api.merge("feature")
        guard case .merged = outcome.result else {
            Issue.record("matrix merge: expected merge commit, got \(outcome.result)")
            return
        }
        #expect(outcome.conflicts.isEmpty)
        #expect(outcome.commitOID != nil)
        #expect(try String(contentsOf: url.appendingPathComponent("a"), encoding: .utf8) == "feature")
        #expect(try String(contentsOf: url.appendingPathComponent("b"), encoding: .utf8) == "main")
        #expect(try api.status().isClean)
        #expect(try !api.repo.inMerge())
    }

    @Test func mergeConflictLeavesMarkers() throws {
        let (_, api, url) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f": "base\n"], message: "base")
        try api.createBranch("side")
        try api.switchTo("side")
        _ = try SpacesTestSupport.commitFiles(api, ["f": "side\n"], message: "side")
        try api.switchTo("main")
        _ = try SpacesTestSupport.commitFiles(api, ["f": "main\n"], message: "main")
        let outcome = try api.merge("side")
        #expect(!outcome.conflicts.isEmpty)
        #expect(outcome.conflicts.contains { $0.path == "f" })
        #expect(try api.repo.inMerge())
        let conflicted = try String(contentsOf: url.appendingPathComponent("f"), encoding: .utf8)
        #expect(conflicted.contains("<<<<<<<"))
        #expect(conflicted.contains("side"))
        #expect(conflicted.contains("main"))
    }

    @Test func conflictResolutionRestoresCleanTree() throws {
        let (_, api, url) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f": "base\n"], message: "base")
        try api.createBranch("side")
        try api.switchTo("side")
        _ = try SpacesTestSupport.commitFiles(api, ["f": "side\n"], message: "side")
        try api.switchTo("main")
        _ = try SpacesTestSupport.commitFiles(api, ["f": "main\n"], message: "main")
        _ = try api.merge("side")
        let provenance = try api.conflictProvenance()
        #expect(provenance.contains { $0.path == "f" })
        #expect(provenance.first { $0.path == "f" }?.category == .content)
        try SpacesTestSupport.write("resolved\n", to: url.appendingPathComponent("f"))
        _ = try api.add("f")
        let oid = try api.mergeContinue()
        #expect(oid.hex.count == 64)
        #expect(try !api.repo.inMerge())
        #expect(try String(contentsOf: url.appendingPathComponent("f"), encoding: .utf8) == "resolved\n")
        #expect(try api.status().isClean)
        let history = try api.conflictHistory()
        #expect(history.contains { $0.paths.contains("f") && $0.resolution == "resolved" })
        let resolvedProvenance = try api.conflictProvenance()
        #expect(resolvedProvenance.first { $0.path == "f" }?.resolved == true)
    }

    @Test func historyLogShowAndBlame() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f": "alpha\nbeta\n"], message: "first")
        _ = try SpacesTestSupport.commitFiles(api, ["f": "alpha\nbeta\ngamma\n"], message: "second")
        let log = try api.log()
        #expect(log.count == 2)
        #expect(log[0].message.hasPrefix("second"))
        #expect(log[1].message.hasPrefix("first"))
        #expect(log[0].isMerge == false)
        let show = try api.show("HEAD")
        #expect(show.info.message.hasPrefix("second"))
        #expect(show.diffStat.files >= 1)
        let blame = try api.blame("f")
        #expect(blame.count == 3)
        #expect(blame[2].line == "gamma")
    }

    @Test func snapshotCreateAndRestore() throws {
        let (_, api, url) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f": "version one\n"], message: "v1")
        let snap = try api.snapshot(message: "before change", kind: .manual)
        try SpacesTestSupport.write("version two\n", to: url.appendingPathComponent("f"))
        #expect(try String(contentsOf: url.appendingPathComponent("f"), encoding: .utf8) == "version two\n")
        try api.restoreSnapshot(snap.hex)
        #expect(try String(contentsOf: url.appendingPathComponent("f"), encoding: .utf8) == "version one\n")
        #expect(try api.snapshots().contains { $0.oid == snap })
        #expect(try api.timeline(limit: 50).contains { $0.oid == snap && $0.kind == .snapshot })
    }

    @Test func recoveryCorruptObjectDetectedByFsck() throws {
        let (_, api, url) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["data.txt": "recover me\n"], message: "base")
        let head = try #require(try api.repo.headCommit())
        let entries = try api.repo.treeEntries(head.tree)
        let blob = try #require(entries.first { $0.name == "data.txt" })
        let objectURL = api.repo.objects.url(for: blob.oid)
        try Data("garbage not an object".utf8).write(to: objectURL)
        #expect(throws: SpacesError.self) { _ = try api.repo.objects.read(blob.oid) }
        let issues = try api.fsck()
        #expect(issues.contains { $0.severity == .error && $0.object == blob.oid.hex })
        try FileManager.default.removeItem(at: objectURL)
        _ = try api.repo.objects.write(type: .blob, payload: Data("recover me\n".utf8))
        #expect(try api.fsck().isEmpty)
        #expect(try api.repo.headCommit()?.tree == head.tree)
        #expect(try String(contentsOf: url.appendingPathComponent("data.txt"), encoding: .utf8) == "recover me\n")
    }

    @Test func recoveryBrokenIndexRebuilt() throws {
        let (_, api, url) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f": "1"], message: "base")
        let indexURL = api.repo.metaURL.appendingPathComponent("index")
        try Data("not json".utf8).write(to: indexURL)
        #expect(throws: SpacesError.self) { _ = try api.status() }
        let rebuiltDirect = try api.rebuildIndex()
        #expect(rebuiltDirect == 1)
        #expect(try api.status().isClean)
        try FileManager.default.removeItem(at: indexURL)
        let rebuilt = try api.rebuildIndex()
        #expect(rebuilt == 1)
        #expect(try api.status().isClean)
        #expect(try api.log().count == 1)
    }

    @Test func repairReportsRebuiltIndex() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f": "1"], message: "base")
        let actions = try api.repair()
        #expect(actions.contains { $0.contains("rebuilt index") })
        #expect(try api.fsck().isEmpty)
    }

    @Test func searchContentFindsLine() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, [
            "Main.swift": "import Foundation\nlet needleLine = \"find me\"\n",
            "Other.swift": "import Foundation\nlet plain = 1\n",
        ], message: "add sources")
        let results = try api.search(SearchOps.Query(text: "needleLine", kinds: [.content]))
        #expect(results.contains { $0.kind == .content && $0.path == "Main.swift" && $0.line == 2 })
        let files = try api.search(SearchOps.Query(text: "Main.swift", kinds: [.file]))
        #expect(files.contains { $0.kind == .file && $0.path == "Main.swift" })
        let none = try api.search(SearchOps.Query(text: "no-such-needle-zzz", kinds: [.content]))
        #expect(none.isEmpty)
    }

    @Test func searchHistoryFindsCommit() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        let first = try SpacesTestSupport.commitFiles(api, [
            "Main.swift": "import Foundation\nlet marker = \"alpha marker text\"\n",
        ], message: "first")
        _ = try SpacesTestSupport.commitFiles(api, [
            "Main.swift": "import Foundation\nlet marker = \"beta text\"\n",
        ], message: "second")
        let matches = try api.historySearch(query: "alpha marker")
        #expect(matches.contains { $0.commit == first && $0.path == "Main.swift" && $0.line == 2 })
    }

    @Test func cliPathEquivalenceSpotCheck() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, [
            "App.swift": "import Foundation\npublic struct Widget {\n    public func greet() -> String {\n        return \"hi\"\n    }\n}\n",
            "B.swift": "import Alamofire\npublic struct B {}\n",
        ], message: "add app")
        #expect(try api.refreshSymbolIndex() > 0)
        let functions = try api.semanticSearch(query: "greet")
        #expect(functions.contains { $0.name == "greet" && $0.kind == .function && $0.file == "App.swift" })
        let structs = try api.semanticSearch(query: "Widget", kind: .structType)
        #expect(structs.contains { $0.name == "Widget" })
        let graph = try api.refreshDependencyGraph()
        #expect(graph.edges.contains { $0.from == "App.swift" && $0.to == "Foundation" })
        #expect(graph.edges.contains { $0.from == "B.swift" && $0.to == "Alamofire" })
        try api.move("App.swift", "Application.swift")
        _ = try api.commit(message: "rename app")
        let steps = try api.fileEvolution(path: "Application.swift")
        #expect(steps.first?.change == .renamed)
        #expect(steps.first?.oldPath == "App.swift")
        try api.createBranch("feature")
        _ = try api.createBranchStack(name: "stack", branches: ["feature"], base: "HEAD")
        let stackStatus = try api.branchStackStatus(name: "stack")
        #expect(stackStatus.branches.count == 1)
        _ = try api.createBranchCheckpoint(branch: "main", name: "cp1")
        #expect(try api.branchCheckpoints(branch: "main").contains { $0.name == "cp1" })
        #expect(try api.secretHistory().isEmpty)
        let heatmap = try api.storageHeatmap()
        #expect(heatmap.totalObjects > 0)
        #expect(heatmap.reachableBytes > 0)
        let backupDir = try SpacesTestSupport.tempDir()
        let backupPath = backupDir.appendingPathComponent("backup.spbd").path
        let manifest = try api.createBackup(to: backupPath)
        #expect(!manifest.objects.isEmpty)
        #expect(try api.verifyBackup(url: backupPath).objectCount > 0)
        #expect(try api.backups().contains { $0.id == manifest.id })
        let head = try api.log().first?.oid
        let review = try api.createReview(title: "matrix review", base: "HEAD~1", head: "HEAD")
        #expect(try api.reviewStatus(id: review.id) == .open)
        #expect(try api.checkPolicy(operation: .commit).isEmpty)
        let sample = try api.profileOperation(.status)
        #expect(sample.operation == "status")
        #expect(sample.durationMs >= 0)
        let snap = try api.snapshot(message: "verify me", kind: .manual)
        let verification = try api.verifySnapshot(snap.hex)
        #expect(verification.valid)
        #expect(verification.checkedObjects > 0)
        _ = head
    }

    @Test func gitImportSmallRepo() throws {
        let (gitDir, _) = try SpacesValidationSupport.makeGitRepo(
            files: ["README.md": "hello\n", "src/main.swift": "print(\"hi\")\n"],
            message: "import one", secondMessage: "import two")
        let (_, api, url) = try SpacesTestSupport.makeRepo()
        let report = try api.importGit(at: gitDir.path)
        #expect(report.commits == 2)
        #expect(report.branches.contains("main"))
        let log = try api.log()
        #expect(log.count == 2)
        #expect(log[0].message.hasPrefix("import two"))
        #expect(log[1].message.hasPrefix("import one"))
        #expect(try FileManager.default.fileExists(
            atPath: url.appendingPathComponent("README.md").path))
        #expect(try String(contentsOf: url.appendingPathComponent("src/main.swift"), encoding: .utf8) == "print(\"hi\")\n")
    }

    @Test func gitExportRoundTrip() throws {
        let git = try SpacesValidationSupport.requireGit()
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f": "1"], message: "export one")
        _ = try SpacesTestSupport.commitFiles(api, ["f": "2"], message: "export two")
        try api.createTag("v1.0", annotated: false)
        let dest = try SpacesTestSupport.tempDir().appendingPathComponent("exported")
        let report = try api.exportGit(to: dest.path)
        #expect(report.objectsWritten > 0)
        #expect(report.gitDir == dest.appendingPathComponent(".git").path)
        let log = try SpacesValidationSupport.runGit(git, ["-C", dest.path, "log", "--format=%s"], cwd: dest)
        #expect(log.contains("export two"))
        #expect(log.contains("export one"))
        let tags = try SpacesValidationSupport.runGit(git, ["-C", dest.path, "tag", "--list"], cwd: dest)
        #expect(tags.contains("v1.0"))
        let status = try SpacesValidationSupport.runGit(git, ["-C", dest.path, "status", "--porcelain"], cwd: dest)
        #expect(status.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    @Test func remotePushPullOverLocalPath() throws {
        let (_, localAPI, _) = try SpacesTestSupport.makeRepo()
        let (_, remoteAPI, remoteURL) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(localAPI, ["f": "1"], message: "base")
        try localAPI.addRemote("origin", url: remoteURL.path)
        #expect(localAPI.remotes().contains { $0.name == "origin" })
        let push = try localAPI.push("origin", refspec: "main")
        #expect(push.refsUpdated.contains("refs/heads/main"))
        #expect(push.objectsSent > 0)
        #expect(try remoteAPI.log().count == 1)
        let cloneBase = try SpacesTestSupport.tempDir()
        let cloneURL = cloneBase.appendingPathComponent("cloned")
        let cloned = try CloneOps.clone(url: remoteURL.path, into: cloneURL)
        let clonedAPI = SpacesAPI(repo: cloned)
        #expect(try clonedAPI.log().count == 1)
        _ = try SpacesTestSupport.commitFiles(remoteAPI, ["later.txt": "from remote\n"], message: "later")
        #expect(try remoteAPI.log().count == 2)
        let outcome = try clonedAPI.pull("origin", branch: "main")
        #expect(outcome != nil)
        #expect(try String(contentsOf: cloneURL.appendingPathComponent("later.txt"), encoding: .utf8) == "from remote\n")
        #expect(try clonedAPI.log().count == 2)
        #expect(try clonedAPI.status().isClean)
    }

    @Test func remoteCloneMatchesLog() throws {
        let (_, localAPI, _) = try SpacesTestSupport.makeRepo()
        let (_, _, remoteURL) = try SpacesTestSupport.makeRepo()
        let c1 = try SpacesTestSupport.commitFiles(localAPI, ["f": "1"], message: "one")
        let c2 = try SpacesTestSupport.commitFiles(localAPI, ["g": "2"], message: "two")
        try localAPI.addRemote("origin", url: remoteURL.path)
        _ = try localAPI.push("origin", refspec: "main")
        let cloneBase = try SpacesTestSupport.tempDir()
        let cloneURL = cloneBase.appendingPathComponent("cloned")
        let cloned = try CloneOps.clone(url: remoteURL.path, into: cloneURL)
        let clonedLog = try SpacesAPI(repo: cloned).log()
        #expect(clonedLog.map(\.oid) == [c2, c1])
        #expect(try String(contentsOf: cloneURL.appendingPathComponent("f"), encoding: .utf8) == "1")
        #expect(try String(contentsOf: cloneURL.appendingPathComponent("g"), encoding: .utf8) == "2")
    }

    @Test func integrityFsckCleanOnHealthyRepo() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f": "1", "g": "2"], message: "base")
        _ = try api.snapshot(message: "healthy", kind: .manual)
        #expect(try api.fsck().isEmpty)
        #expect(try api.validate().isEmpty)
        #expect(try api.diagnose().allSatisfy { $0.level != .error })
        let (score, _) = try api.health()
        #expect(score > 0)
        let counts = try api.countObjects()
        #expect(counts.total >= 4)
        #expect(counts.commits == 1)
        #expect(try api.storage().total > 0)
    }

    @Test func restartPersistence() throws {
        let url = try SpacesTestSupport.tempDir()
        var firstOID: ObjectID
        var snapOID: ObjectID
        do {
            let repo = try Repository.create(
                at: url,
                user: SpacesConfig.User(name: "Test User", email: "test@example.com"))
            let api = SpacesAPI(repo: repo)
            firstOID = try SpacesTestSupport.commitFiles(api, ["f": "persisted"], message: "kept")
            snapOID = try api.snapshot(message: "kept snapshot", kind: .manual)
        }
        let reopened = try Repository.open(at: url)
        let reopenedAPI = SpacesAPI(repo: reopened)
        #expect(try reopened.refs.headOID(objects: reopened.objects) == firstOID)
        #expect(try reopenedAPI.log().count == 1)
        #expect(try reopenedAPI.log()[0].oid == firstOID)
        #expect(try reopenedAPI.snapshots().contains { $0.oid == snapOID })
        let second = try SpacesTestSupport.commitFiles(reopenedAPI, ["g": "more"], message: "after restart")
        #expect(try reopenedAPI.log().count == 2)
        #expect(try reopenedAPI.log()[0].oid == second)
    }

    @Test func concurrentReadsDoNotCorrupt() async throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f": "1", "g": "2"], message: "base")
        let expected = try api.log().count
        let counts = try await withThrowingTaskGroup(of: Int.self) { group in
            for _ in 0..<8 {
                group.addTask { try api.log().count }
            }
            var collected: [Int] = []
            for try await count in group { collected.append(count) }
            return collected
        }
        #expect(counts.count == 8)
        #expect(counts.allSatisfy { $0 == expected })
        #expect(try api.fsck().isEmpty)
        #expect(try api.log().count == expected)
    }

    @Test func lockContentionFailsCleanly() throws {
        let (_, api, url) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f": "1"], message: "base")
        let other = try Repository.open(at: url)
        var sawLocked = false
        var acquired = false
        try api.repo.withLock {
            do {
                try other.acquireLock()
                acquired = true
            } catch SpacesError.repositoryLocked {
                sawLocked = true
            }
        }
        if acquired { other.releaseLock() }
        #expect(sawLocked)
        #expect(!acquired)
        #expect(try api.status().isClean)
        #expect(try api.log().count == 1)
    }

    @Test func securitySecretScanFindsPlantedSecret() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        let commit = try SpacesTestSupport.commitFiles(api, [
            "secrets.txt": "aws_access_key_id = \"AKIA1234567890ABCDEF\"\n",
            "clean.txt": "nothing sensitive here\n",
        ], message: "add credentials")
        let findings = try api.secretHistory()
        #expect(findings.contains {
            $0.commit == commit.hex && $0.path == "secrets.txt" && $0.patternName == "aws-access-key"
        })
        #expect(findings.allSatisfy { $0.path != "clean.txt" })
        let report = try api.generateSecurityReport()
        #expect(report.secretFindingCount >= 1)
    }

    @Test func protectedHistoryBlocksForcePush() throws {
        let (_, localAPI, _) = try SpacesTestSupport.makeRepo()
        let (_, remoteAPI, remoteURL) = try SpacesTestSupport.makeRepo()
        let c1 = try SpacesTestSupport.commitFiles(localAPI, ["f": "1"], message: "one")
        _ = try SpacesTestSupport.commitFiles(localAPI, ["f": "2"], message: "two")
        try localAPI.addRemote("origin", url: remoteURL.path)
        _ = try localAPI.push("origin", refspec: "main")
        try localAPI.setProtectedHistoryRules(
            ProtectedHistoryOps.ProtectedHistoryRules(refs: [
                ProtectedHistoryOps.ProtectedRefRule(
                    pattern: "main", allowForcePush: false, allowDelete: false, requireReview: false),
            ]))
        let check = try localAPI.checkProtectedHistory(ref: "refs/heads/main", operation: "force-push")
        #expect(check.allowed == false)
        #expect(check.reasons.contains { $0.contains("force-push") })
        try localAPI.reset(to: c1.hex, mode: .hard)
        _ = try SpacesTestSupport.commitFiles(localAPI, ["f": "divergent"], message: "three divergent")
        #expect(throws: SpacesError.self) {
            _ = try localAPI.push("origin", refspec: "main", force: true)
        }
        #expect(try remoteAPI.log()[0].message.hasPrefix("two"))
    }

    @Test func policyCheckRejectsBadCommit() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        try api.setCommitPolicies([
            ValidationPolicyOps.PolicyRule(id: "jira", kind: .messagePattern, pattern: "^JIRA-[0-9]+"),
        ])
        _ = try api.stageAll()
        #expect(throws: SpacesError.self) { _ = try api.commit(message: "no ticket") }
        try SpacesTestSupport.write("work\n", to: api.repo.worktreeURL.appendingPathComponent("f"))
        _ = try api.stageAll()
        let violations = try api.validateCommit(message: "no ticket here")
        #expect(violations.contains { $0.ruleId == "jira" })
        #expect(throws: SpacesError.self) { _ = try api.commitValidated(message: "no ticket here") }
        let good = try api.commitValidated(message: "JIRA-42 implement feature")
        #expect(good.oid.hex.count == 64)
        #expect(try api.log()[0].message.hasPrefix("JIRA-42"))
    }

    @Test func renameStagingPreservesObjectID() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["Old.swift": "public struct Old {}\n"], message: "add old")
        try api.move("Old.swift", "New.swift")
        _ = try api.commit(message: "rename file")
        let diffs = try api.diff("HEAD~1", "HEAD")
        let diff = try #require(diffs.first { $0.newPath == "New.swift" })
        #expect(diff.status == .renamed)
        #expect(diff.oldPath == "Old.swift")
        #expect(diff.oldOID == diff.newOID)
        #expect(diff.oldOID != nil)
        let steps = try api.fileEvolution(path: "New.swift")
        #expect(steps.first?.change == .renamed)
        #expect(steps.first?.oldPath == "Old.swift")
        #expect(steps.last?.change == .added)
    }
}
