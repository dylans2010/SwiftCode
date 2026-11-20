import Foundation
import Testing
@testable import SpacesEngine

@Suite(.serialized) struct Wave2ApiGapsTests {
    @Test func apiGcPruneDaysHonorsAge() throws {
        let (repo, api, _) = try SpacesTestSupport.makeRepo()
        let oldUnreachable = try repo.objects.write(type: .blob, payload: Data("old orphan".utf8))
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(-40 * 86400)],
            ofItemAtPath: repo.objects.url(for: oldUnreachable).path)
        let freshUnreachable = try repo.objects.write(type: .blob, payload: Data("fresh orphan".utf8))
        let first = try api.gc(pruneDays: 30)
        #expect(first.pruned == 1)
        #expect(!repo.objects.exists(oldUnreachable))
        #expect(repo.objects.exists(freshUnreachable))
        let second = try api.gc()
        #expect(second.pruned >= 1)
        #expect(!repo.objects.exists(freshUnreachable))
    }

    @Test func apiGcRejectsNegativePruneDays() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        #expect(throws: SpacesError.self) {
            _ = try api.gc(pruneDays: -1)
        }
    }

    @Test func taggerTimezoneRoundTripsThroughExport() throws {
        let git = try SpacesValidationSupport.requireGit()
        let (gitDir, _) = try SpacesValidationSupport.makeGitRepo(
            git: git, files: ["hello.txt": "hello\n"], message: "base")
        _ = try runGitWithEnvironment(
            git, ["tag", "-a", "v1", "-m", "release one"], cwd: gitDir,
            environment: ["GIT_COMMITTER_DATE": "2000-01-01T00:00:00 +0530"])
        let rawTag = try SpacesValidationSupport.runGit(git, ["cat-file", "tag", "v1"], cwd: gitDir)
        #expect(rawTag.contains("+0530"))
        let (_, spacesAPI, _) = try SpacesTestSupport.makeRepo()
        let report = try spacesAPI.importGit(at: gitDir.path)
        #expect(report.tags.contains("v1"))
        let tagOID = try #require(try spacesAPI.repo.refs.readRef("refs/tags/v1"))
        let stored = try spacesAPI.repo.objects.read(tagOID)
        #expect(stored.type == .tag)
        let payload = try JSONDecoder().decode(TagPayload.self, from: stored.payload)
        #expect(payload.taggerTimezone == 19800)
        let dest = try SpacesTestSupport.tempDir().appendingPathComponent("exported")
        _ = try spacesAPI.exportGit(to: dest.path)
        let exported = try SpacesValidationSupport.runGit(
            git, ["-C", dest.path, "cat-file", "tag", "v1"], cwd: dest)
        #expect(exported.contains("+0530"))
        #expect(exported.contains("tagger Test User <test@example.com>"))
    }

    @Test func paxPathOverrideHonored() throws {
        let dir = try SpacesTestSupport.tempDir()
        let archive = dir.appendingPathComponent("bundle.tar")
        var tar = Data()
        tar.append(tarEntry(name: "pax-header",
                            contents: paxRecord(key: "path", value: "nested/renamed.txt"),
                            typeflag: 0x78))
        tar.append(tarEntry(name: "old.txt", contents: Data("renamed content\n".utf8)))
        tar.append(tarEntry(name: "plain.txt", contents: Data("plain\n".utf8)))
        tar.append(Data(repeating: 0, count: 1024))
        try tar.write(to: archive)
        let dest = dir.appendingPathComponent("out")
        let extracted = try ArchiveOps.extract(archive: archive.path, to: dest.path)
        #expect(extracted.contains("nested/renamed.txt"))
        #expect(!extracted.contains("old.txt"))
        #expect(!FileManager.default.fileExists(atPath: dest.appendingPathComponent("old.txt").path))
        #expect(try String(contentsOf: dest.appendingPathComponent("nested/renamed.txt"),
                           encoding: .utf8) == "renamed content\n")
        #expect(extracted.contains("plain.txt"))
        #expect(try String(contentsOf: dest.appendingPathComponent("plain.txt"),
                           encoding: .utf8) == "plain\n")
    }

    @Test func paxGlobalPathOverrideAppliesToLaterEntries() throws {
        let dir = try SpacesTestSupport.tempDir()
        let archive = dir.appendingPathComponent("bundle.tar")
        var tar = Data()
        tar.append(tarEntry(name: "global-header",
                            contents: paxRecord(key: "path", value: "global/renamed.txt"),
                            typeflag: 0x67))
        tar.append(tarEntry(name: "a.txt", contents: Data("global content\n".utf8)))
        tar.append(Data(repeating: 0, count: 1024))
        try tar.write(to: archive)
        let dest = dir.appendingPathComponent("out")
        let extracted = try ArchiveOps.extract(archive: archive.path, to: dest.path)
        #expect(extracted.contains("global/renamed.txt"))
        #expect(!FileManager.default.fileExists(atPath: dest.appendingPathComponent("a.txt").path))
        #expect(try String(contentsOf: dest.appendingPathComponent("global/renamed.txt"),
                           encoding: .utf8) == "global content\n")
    }

    @Test func graphNodesCarryRealBranchTipTimestamps() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["a.txt": "a\n"], message: "base")
        _ = try api.createBranch("feature")
        try api.switchTo("feature")
        let featureOID = try SpacesTestSupport.commitFiles(
            api, ["b.txt": "b\n"], message: "feature work")
        let featureLog = try #require(try api.log(limit: 1).first)
        #expect(featureLog.oid == featureOID)
        let nodes = try api.graph(limit: 100, all: true)
        let featureNode = try #require(nodes.first { $0.refs.contains("feature") })
        #expect(featureNode.oid == featureOID)
        #expect(featureNode.timestamp == featureLog.timestamp)
        let mainNode = try #require(nodes.first { $0.refs.contains("main") })
        #expect(featureNode.timestamp >= mainNode.timestamp)
        #expect(mainNode.oid != featureOID)
    }

    @Test func namedIdentityKeyLivesOutsideRepo() throws {
        let (repo, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["a.txt": "a\n"], message: "base")
        let signed = try api.signCommit(rev: "HEAD", identity: "release")
        let metaContents = try FileManager.default.contentsOfDirectory(atPath: repo.metaURL.path)
        #expect(!metaContents.contains("signing-release.key"))
        #expect(try api.signingIdentities().contains("release"))
        #expect(try api.verifyCommitSignature(rev: "HEAD"))
        let again = try api.signCommit(rev: signed.oid.hex, identity: "release")
        #expect(try api.verifyCommitSignature(rev: again.oid.hex))
        #expect(try api.signingIdentities().contains("release"))
    }

    @Test func legacyNamedKeyMigratesOnFirstUse() throws {
        let (repo, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["a.txt": "a\n"], message: "base")
        let legacyURL = repo.metaURL.appendingPathComponent("signing-legacy.key")
        try Data(repeating: 7, count: 32).write(to: legacyURL, options: .atomic)
        _ = try api.signCommit(rev: "HEAD", identity: "legacy")
        #expect(!FileManager.default.fileExists(atPath: legacyURL.path))
        #expect(try api.signingIdentities().contains("legacy"))
        #expect(try api.verifyCommitSignature(rev: "HEAD"))
    }

    private func runGitWithEnvironment(_ git: String, _ args: [String], cwd: URL,
                                       environment: [String: String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: git)
        process.arguments = args
        process.currentDirectoryURL = cwd
        var env = ProcessInfo.processInfo.environment
        for (key, value) in environment { env[key] = value }
        process.environment = env
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        try process.run()
        process.waitUntilExit()
        let out = String(decoding: outPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        guard process.terminationStatus == 0 else {
            throw SpacesError.invalidArgument("git \(args.joined(separator: " ")) failed")
        }
        return out
    }

    private func paxRecord(key: String, value: String) -> Data {
        var count = key.utf8.count + value.utf8.count + 3
        while true {
            let record = "\(count) \(key)=\(value)\n"
            if record.utf8.count == count { return Data(record.utf8) }
            count = record.utf8.count
        }
    }

    private func tarEntry(name: String, contents: Data, typeflag: UInt8 = 0x30) -> Data {
        var out = ustarHeader(name: name, size: contents.count, typeflag: typeflag)
        out.append(contents)
        let pad = (512 - (contents.count % 512)) % 512
        out.append(Data(repeating: 0, count: pad))
        return out
    }

    private func ustarHeader(name: String, size: Int, typeflag: UInt8) -> Data {
        var header = Data(repeating: 0, count: 512)
        func put(_ string: String, at offset: Int) {
            let bytes = Array(string.utf8)
            header.replaceSubrange(offset..<(offset + bytes.count), with: bytes)
        }
        put(name, at: 0)
        put("0000644", at: 100)
        put("0000000", at: 108)
        put("0000000", at: 116)
        put(String(format: "%011o", size), at: 124)
        put(String(format: "%011o", 0), at: 136)
        put("ustar", at: 257)
        put("00", at: 263)
        header[156] = typeflag
        var sum = 0
        for i in 0..<512 {
            sum += i >= 148 && i < 156 ? 0x20 : Int(header[i])
        }
        put(String(format: "%06o", sum), at: 148)
        header[154] = 0
        header[155] = 0x20
        return header
    }
}
