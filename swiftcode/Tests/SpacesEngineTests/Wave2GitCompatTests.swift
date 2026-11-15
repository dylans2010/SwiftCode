import Foundation
import Testing
@testable import SpacesEngine

enum Wave2GitCompatSupport {
    static func runGitWithStdin(_ git: String, _ args: [String], input: String, cwd: URL) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: git)
        process.arguments = args
        process.currentDirectoryURL = cwd
        let inPipe = Pipe(), outPipe = Pipe(), errPipe = Pipe()
        process.standardInput = inPipe
        process.standardOutput = outPipe
        process.standardError = errPipe
        try process.run()
        inPipe.fileHandleForWriting.write(Data(input.utf8))
        try? inPipe.fileHandleForWriting.close()
        process.waitUntilExit()
        let out = String(decoding: outPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        let err = String(decoding: errPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        guard process.terminationStatus == 0 else {
            throw SpacesError.invalidArgument("git \(args.joined(separator: " ")) failed: \(err)")
        }
        return out
    }

    static func makeGitRepoWithGitlink(git: String) throws -> URL {
        let (dir, _) = try SpacesValidationSupport.makeGitRepo(
            git: git, files: ["README.md": "hello\n"], message: "base", secondMessage: "second")
        _ = try SpacesValidationSupport.runGit(git, ["update-index", "--add", "--cacheinfo",
            "160000,2222222222222222222222222222222222222222,vendor/lib"], cwd: dir)
        _ = try SpacesValidationSupport.runGit(git, ["commit", "-q", "-m", "add gitlink"], cwd: dir)
        return dir
    }

    static func makeGitRepoWithLfsPointer(git: String, oid: String) throws -> URL {
        let slash = "/"
        let pointer = "version https:\(slash)\(slash)git-lfs.github.com/spec/v1\noid sha256:\(oid)\nsize 5\n"
        let (dir, _) = try SpacesValidationSupport.makeGitRepo(
            git: git, files: ["big.bin": pointer], message: "add lfs pointer")
        return dir
    }
}

@Suite struct Wave2GitCompatTests {
    @Test func importGitlinkRecordedAsTrackedEntry() throws {
        let git = try SpacesValidationSupport.requireGit()
        let gitDir = try Wave2GitCompatSupport.makeGitRepoWithGitlink(git: git)
        let (_, api, url) = try SpacesTestSupport.makeRepo()
        let report = try api.importGit(at: gitDir.path)
        #expect(report.gitlinks.count == 1)
        #expect(report.gitlinks[0].path == "vendor/lib")
        #expect(report.gitlinks[0].target == "2222222222222222222222222222222222222222")
        #expect(report.warnings.contains { $0.contains("gitlink") })
        #expect(report.warnings.contains { $0.contains("not present in the source repository") })
        #expect(!report.warnings.contains { $0.contains("unconvertible tree") })
        let manifestURL = url.appendingPathComponent(".spaces/migration/gitlinks.json")
        #expect(FileManager.default.fileExists(atPath: manifestURL.path))
        let markerURL = url.appendingPathComponent("vendor/lib")
        #expect(FileManager.default.fileExists(atPath: markerURL.path))
        let marker = try String(contentsOf: markerURL, encoding: .utf8)
        #expect(marker.hasPrefix("spaces-gitlink:2222222222222222222222222222222222222222"))
        #expect(report.branches.contains("main"))
    }

    @Test func importGitlinkDryRunWritesNoManifest() throws {
        let git = try SpacesValidationSupport.requireGit()
        let gitDir = try Wave2GitCompatSupport.makeGitRepoWithGitlink(git: git)
        let (_, api, url) = try SpacesTestSupport.makeRepo()
        let report = try GitMigration(repo: api.repo).importGit(at: gitDir.path, dryRun: true)
        #expect(report.gitlinks.count == 1)
        #expect(report.gitlinks[0].path == "vendor/lib")
        let manifestURL = url.appendingPathComponent(".spaces/migration/gitlinks.json")
        #expect(!FileManager.default.fileExists(atPath: manifestURL.path))
        #expect(!FileManager.default.fileExists(atPath: url.appendingPathComponent("vendor/lib").path))
    }

    @Test func importGpgSignedCommitPreservesPayload() throws {
        let git = try SpacesValidationSupport.requireGit()
        let (gitDir, _) = try SpacesValidationSupport.makeGitRepo(
            git: git, files: ["f": "1\n"], message: "base")
        let tree = try SpacesValidationSupport.runGit(git, ["rev-parse", "HEAD^{tree}"], cwd: gitDir)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let head = try SpacesValidationSupport.runGit(git, ["rev-parse", "HEAD"], cwd: gitDir)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let raw = "tree \(tree)\nparent \(head)\nauthor Test User <test@example.com> 1700000000 +0000\ncommitter Test User <test@example.com> 1700000000 +0000\ngpgsig -----BEGIN PGP SIGNATURE-----\n \n -----END PGP SIGNATURE-----\n\nsigned commit\n"
        let signed = try Wave2GitCompatSupport.runGitWithStdin(
            git, ["hash-object", "-t", "commit", "-w", "--stdin"], input: raw, cwd: gitDir)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        _ = try SpacesValidationSupport.runGit(git, ["update-ref", "refs/heads/main", signed], cwd: gitDir)
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        let report = try api.importGit(at: gitDir.path)
        #expect(report.gpgSignatures.contains(signed))
        let log = try api.log()
        #expect(log[0].message.hasPrefix("signed commit"))
        let stored = try api.repo.commitObject(log[0].oid)
        #expect(stored.metadata.signature?.contains("-----BEGIN PGP SIGNATURE-----") == true)
        let dest = try SpacesTestSupport.tempDir().appendingPathComponent("exported")
        _ = try api.exportGit(to: dest.path)
        let exported = try SpacesValidationSupport.runGit(git, ["cat-file", "commit", "HEAD"], cwd: dest)
        #expect(exported.contains("gpgsig -----BEGIN PGP SIGNATURE-----"))
        #expect(exported.contains("signed commit"))
    }

    @Test func importGpgSignedTagRoundTrip() throws {
        let git = try SpacesValidationSupport.requireGit()
        let (gitDir, _) = try SpacesValidationSupport.makeGitRepo(
            git: git, files: ["f": "1\n"], message: "base")
        let head = try SpacesValidationSupport.runGit(git, ["rev-parse", "HEAD"], cwd: gitDir)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let rawTag = "object \(head)\ntype commit\ntag v2.0\ntagger Test User <test@example.com> 1700000000 +0000\n\nsigned tag message\n-----BEGIN PGP SIGNATURE-----\n\n-----END PGP SIGNATURE-----\n"
        let tagOID = try Wave2GitCompatSupport.runGitWithStdin(
            git, ["hash-object", "-t", "tag", "-w", "--stdin"], input: rawTag, cwd: gitDir)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        _ = try SpacesValidationSupport.runGit(git, ["update-ref", "refs/tags/v2.0", tagOID], cwd: gitDir)
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        let report = try api.importGit(at: gitDir.path)
        #expect(report.tags.contains("v2.0"))
        let dest = try SpacesTestSupport.tempDir().appendingPathComponent("exported")
        _ = try api.exportGit(to: dest.path)
        let exported = try SpacesValidationSupport.runGit(git, ["cat-file", "tag", "v2.0"], cwd: dest)
        #expect(exported.contains("signed tag message"))
        #expect(exported.contains("-----BEGIN PGP SIGNATURE-----"))
    }

    @Test func importGitNotesMappedToCommits() throws {
        let git = try SpacesValidationSupport.requireGit()
        let (gitDir, _) = try SpacesValidationSupport.makeGitRepo(
            git: git, files: ["f": "1\n"], message: "first", secondMessage: "second")
        _ = try SpacesValidationSupport.runGit(git, ["notes", "add", "-m", "reviewed ok", "HEAD"], cwd: gitDir)
        _ = try SpacesValidationSupport.runGit(git, ["notes", "add", "-m", "first note", "HEAD~1"], cwd: gitDir)
        let (_, api, url) = try SpacesTestSupport.makeRepo()
        let report = try api.importGit(at: gitDir.path)
        #expect(report.notesImported == 2)
        #expect(report.notesRefs.contains("refs/notes/commits"))
        let notesURL = url.appendingPathComponent(".spaces/notes.json")
        let notes = try JSONDecoder().decode([String: [String]].self, from: Data(contentsOf: notesURL))
        let log = try api.log()
        #expect(log.count == 2)
        #expect(notes[log[0].oid.hex] == ["reviewed ok"])
        #expect(notes[log[1].oid.hex] == ["first note"])
    }

    @Test func importLfsPointerWithLocalObject() throws {
        let git = try SpacesValidationSupport.requireGit()
        let oid = String(repeating: "ab", count: 32)
        let gitDir = try Wave2GitCompatSupport.makeGitRepoWithLfsPointer(git: git, oid: oid)
        let objectDir = gitDir.appendingPathComponent(".git/lfs/objects/ab/ab")
        try FileManager.default.createDirectory(at: objectDir, withIntermediateDirectories: true)
        try Data("hello".utf8).write(to: objectDir.appendingPathComponent(oid))
        let (_, api, url) = try SpacesTestSupport.makeRepo()
        let report = try api.importGit(at: gitDir.path)
        #expect(report.lfsPointers.count == 1)
        #expect(report.lfsPointers[0].path == "big.bin")
        #expect(report.lfsPointers[0].oid == oid)
        #expect(report.lfsPointers[0].size == 5)
        #expect(report.lfsPointers[0].objectImported == true)
        let stored = url.appendingPathComponent(".spaces/lfs/objects/\(oid)")
        #expect(FileManager.default.fileExists(atPath: stored.path))
        #expect(try String(contentsOf: stored, encoding: .utf8) == "hello")
        let manifestURL = url.appendingPathComponent(".spaces/migration/lfs-pointers.json")
        #expect(FileManager.default.fileExists(atPath: manifestURL.path))
    }

    @Test func importLfsPointerWithoutLocalObjectWarns() throws {
        let git = try SpacesValidationSupport.requireGit()
        let oid = String(repeating: "cd", count: 32)
        let gitDir = try Wave2GitCompatSupport.makeGitRepoWithLfsPointer(git: git, oid: oid)
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        let report = try api.importGit(at: gitDir.path)
        #expect(report.lfsPointers.count == 1)
        #expect(report.lfsPointers[0].objectImported == false)
        #expect(report.warnings.contains { $0.contains("not present in the source repository") && $0.contains(oid) })
        #expect(report.warnings.contains { $0.contains("remote LFS transfer is not implemented") })
    }

    @Test func importWarnsAboutLossySourceState() throws {
        let git = try SpacesValidationSupport.requireGit()
        let (gitDir, _) = try SpacesValidationSupport.makeGitRepo(
            git: git, files: ["f": "1\n"], message: "base")
        _ = try SpacesValidationSupport.runGit(git, ["remote", "add", "origin", "/tmp/spaces-wave2-remote"], cwd: gitDir)
        try SpacesTestSupport.write("#!/bin/sh\nexit 0\n", to: gitDir.appendingPathComponent(".git/hooks/pre-commit"))
        try FileManager.default.setAttributes([.posixPermissions: 0o755],
                                              ofItemAtPath: gitDir.appendingPathComponent(".git/hooks/pre-commit").path)
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        let report = try api.importGit(at: gitDir.path)
        let joined = report.warnings.joined(separator: "\n")
        #expect(joined.contains("remotes (origin) were not imported"))
        #expect(joined.contains("configuration") && joined.contains("was not imported"))
        #expect(joined.contains("hooks (pre-commit) were not imported"))
        #expect(joined.contains("reflogs were not imported"))
    }

    @Test func exportWritesConfigHooksAndReflogs() throws {
        let git = try SpacesValidationSupport.requireGit()
        let (_, api, url) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f": "1"], message: "export one")
        _ = try SpacesTestSupport.commitFiles(api, ["f": "2"], message: "export two")
        try api.addRemote("origin", url: "/tmp/spaces-wave2-remote")
        api.repo.config.branchTracking["main"] = "origin/main"
        try api.repo.saveConfig()
        let hookURL = url.appendingPathComponent(".spaces/hooks/pre-commit")
        try SpacesTestSupport.write("#!/bin/sh\nexit 0\n", to: hookURL)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: hookURL.path)
        let dest = try SpacesTestSupport.tempDir().appendingPathComponent("exported")
        let report = try api.exportGit(to: dest.path)
        #expect(report.configKeysWritten.contains("remote.origin.url"))
        #expect(report.configKeysWritten.contains("user.name"))
        #expect(report.configKeysWritten.contains("branch.main.remote"))
        #expect(report.hooksExported == ["pre-commit"])
        #expect(report.reflogsExported.contains("HEAD"))
        let remoteURL = try SpacesValidationSupport.runGit(git, ["config", "--get", "remote.origin.url"], cwd: dest)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(remoteURL == "/tmp/spaces-wave2-remote")
        let userName = try SpacesValidationSupport.runGit(git, ["config", "--get", "user.name"], cwd: dest)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(userName == "Test User")
        let merge = try SpacesValidationSupport.runGit(git, ["config", "--get", "branch.main.merge"], cwd: dest)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(merge == "refs/heads/main")
        let exportedHook = dest.appendingPathComponent(".git/hooks/pre-commit")
        #expect(FileManager.default.fileExists(atPath: exportedHook.path))
        let perms = (try FileManager.default.attributesOfItem(atPath: exportedHook.path))[.posixPermissions] as? Int
        #expect((perms ?? 0) & 0o111 != 0)
        let headLog = try String(contentsOf: dest.appendingPathComponent(".git/logs/HEAD"), encoding: .utf8)
        #expect(headLog.contains("export two"))
        #expect(headLog.contains("export one"))
    }

    @Test func exportIntoExistingGitUpdatesInPlace() throws {
        let git = try SpacesValidationSupport.requireGit()
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f": "1"], message: "v1")
        let dest = try SpacesTestSupport.tempDir().appendingPathComponent("exported")
        let first = try api.exportGit(to: dest.path)
        #expect(first.updatedExisting == false)
        _ = try SpacesValidationSupport.runGit(git, ["branch", "keepme"], cwd: dest)
        _ = try SpacesTestSupport.commitFiles(api, ["f": "2"], message: "v2")
        let second = try api.exportGit(to: dest.path)
        #expect(second.updatedExisting == true)
        let log = try SpacesValidationSupport.runGit(git, ["log", "--format=%s"], cwd: dest)
        #expect(log.contains("v2"))
        #expect(log.contains("v1"))
        let branches = try SpacesValidationSupport.runGit(git, ["branch", "--list", "keepme"], cwd: dest)
        #expect(branches.contains("keepme"))
    }

    @Test func exportIntoBareGitDirUpdatesInPlace() throws {
        let git = try SpacesValidationSupport.requireGit()
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f": "1"], message: "bare one")
        let bare = try SpacesTestSupport.tempDir().appendingPathComponent("bare.git")
        _ = try SpacesValidationSupport.runGit(git, ["init", "-q", "--bare", bare.path], cwd: bare.deletingLastPathComponent())
        let report = try api.exportGit(to: bare.path)
        #expect(report.updatedExisting == true)
        #expect(report.gitDir == bare.path)
        let log = try SpacesValidationSupport.runGit(git, ["--git-dir", bare.path, "log", "--format=%s"], cwd: bare.deletingLastPathComponent())
        #expect(log.contains("bare one"))
    }

    @Test func exportGitlinkRoundTrip() throws {
        let git = try SpacesValidationSupport.requireGit()
        let gitDir = try Wave2GitCompatSupport.makeGitRepoWithGitlink(git: git)
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try api.importGit(at: gitDir.path)
        let dest = try SpacesTestSupport.tempDir().appendingPathComponent("exported")
        _ = try api.exportGit(to: dest.path)
        let listing = try SpacesValidationSupport.runGit(git, ["ls-tree", "-r", "HEAD"], cwd: dest)
        #expect(listing.contains("160000 commit 2222222222222222222222222222222222222222\tvendor/lib"))
    }
}
