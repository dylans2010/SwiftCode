import Foundation
import Testing
@testable import SwiftCodeSDK

@Suite(.serialized)
struct Wave2SdkTests {
    private static let gitKey = "git_executable_path"

    private func tempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("Wave2SdkTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func makeFakeGit(in dir: URL, exitCode: Int32) throws -> (script: URL, log: URL) {
        let script = dir.appendingPathComponent("fake-git")
        let log = dir.appendingPathComponent("argv.log")
        let body = "#!/bin/sh\nprintf '%s\\n' \"$@\" >> '\(log.path)'\nexit \(exitCode)\n"
        try body.write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
        return (script, log)
    }

    private func installFakeGit(exitCode: Int32, in dir: URL) throws -> (script: URL, log: URL) {
        let pair = try makeFakeGit(in: dir, exitCode: exitCode)
        UserDefaults.standard.set(pair.script.path, forKey: Self.gitKey)
        return pair
    }

    private func loggedArgv(_ log: URL) throws -> [String] {
        let text = try String(contentsOf: log, encoding: .utf8)
        return text.split(separator: "\n").map(String.init)
    }

    private func makeRepo(in dir: URL) async throws -> URL {
        let repoURL = dir.appendingPathComponent("repo")
        _ = try await SpacesService.shared.initialize(at: repoURL)
        return repoURL
    }

    private func commitFile(_ name: String, contents: String, message: String, repoURL: URL) async throws {
        let file = repoURL.appendingPathComponent(name)
        try Data(contents.utf8).write(to: file)
        try await SpacesService.shared.stage(path: file, repositoryURL: repoURL)
        try await SpacesService.shared.commit(message: message, repositoryURL: repoURL)
    }

    @Test func cloneWithTokenPassesExtraHeaderToFakeGit() async throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let (_, log) = try installFakeGit(exitCode: 0, in: dir)
        defer { UserDefaults.standard.removeObject(forKey: Self.gitKey) }
        let dest = dir.appendingPathComponent("cloned")
        try await GitService.shared.clone(
            remoteURL: URL(string: "https://example.com/repo.git")!,
            destinationURL: dest,
            token: "tok-123")
        let argv = try loggedArgv(log)
        #expect(argv.first == "clone")
        #expect(argv.contains("-c"))
        #expect(argv.contains("http.https://example.com/.extraHeader=Authorization: Bearer tok-123"))
        #expect(argv.contains("https://example.com/repo.git"))
        #expect(argv.contains(dest.path))
    }

    @Test func cloneWithoutTokenPassesNoExtraHeader() async throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let (_, log) = try installFakeGit(exitCode: 0, in: dir)
        defer { UserDefaults.standard.removeObject(forKey: Self.gitKey) }
        let dest = dir.appendingPathComponent("cloned")
        try await GitService.shared.clone(
            remoteURL: URL(string: "https://example.com/repo.git")!,
            destinationURL: dest,
            token: nil)
        let argv = try loggedArgv(log)
        #expect(argv.first == "clone")
        #expect(!argv.contains(where: { $0.contains("extraHeader") }))
        #expect(!argv.contains(where: { $0.contains("Authorization") }))
        #expect(argv.contains("https://example.com/repo.git"))
        #expect(argv.contains(dest.path))
    }

    @Test func cloneTokenWithControlCharacterThrowsInvalidBranch() async throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let dest = dir.appendingPathComponent("cloned")
        var thrown = ""
        do {
            try await GitService.shared.clone(
                remoteURL: URL(string: "https://example.com/repo.git")!,
                destinationURL: dest,
                token: "bad\ntoken")
        } catch let error as GitError {
            if case .invalidBranch = error {
                thrown = "invalidBranch"
            } else {
                thrown = "otherGitError"
            }
        } catch {
            thrown = "nonGitError"
        }
        #expect(thrown == "invalidBranch")
    }

    @Test func cloneTokenOnNonHttpRemoteThrowsInvalidBranch() async throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let dest = dir.appendingPathComponent("cloned")
        var thrown = ""
        do {
            try await GitService.shared.clone(
                remoteURL: URL(string: "spaces://example.com/repo")!,
                destinationURL: dest,
                token: "tok-123")
        } catch let error as GitError {
            if case .invalidBranch = error {
                thrown = "invalidBranch"
            } else {
                thrown = "otherGitError"
            }
        } catch {
            thrown = "nonGitError"
        }
        #expect(thrown == "invalidBranch")
    }

    @Test func cloneFailureSurfacesCommandFailed() async throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        _ = try installFakeGit(exitCode: 3, in: dir)
        defer { UserDefaults.standard.removeObject(forKey: Self.gitKey) }
        let dest = dir.appendingPathComponent("cloned")
        var failed = false
        var code: Int32 = -1
        do {
            try await GitService.shared.clone(
                remoteURL: URL(string: "https://example.com/repo.git")!,
                destinationURL: dest,
                token: nil)
        } catch let error as GitError {
            if case .commandFailed(_, let exitCode, _) = error {
                code = exitCode
                failed = true
            }
        }
        #expect(failed)
        #expect(code == 3)
    }

    @Test func graphReturnsBranchTipNodeWithRealTimestamp() async throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let repoURL = try await makeRepo(in: dir)
        let before = Int64(Date().timeIntervalSince1970)
        try await commitFile("hello.txt", contents: "hello\n", message: "Wave 2 SDK graph check", repoURL: repoURL)
        let nodes = try await SpacesService.shared.graph(repositoryURL: repoURL)
        let after = Int64(Date().timeIntervalSince1970)
        #expect(nodes.count == 1)
        let node = try #require(nodes.first)
        #expect(node.summary == "Wave 2 SDK graph check")
        #expect(node.parents.isEmpty)
        #expect(node.refs.contains("main"))
        #expect(node.timestamp >= before)
        #expect(node.timestamp <= after)
        #expect(node.oid.hex.count == 64)
    }

    @Test func graphOnEmptyRepoReturnsNoNodes() async throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let repoURL = try await makeRepo(in: dir)
        let nodes = try await SpacesService.shared.graph(repositoryURL: repoURL)
        #expect(nodes.isEmpty)
    }

    @Test func graphAfterSecondCommitListsNewestFirst() async throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let repoURL = try await makeRepo(in: dir)
        try await commitFile("a.txt", contents: "a\n", message: "first", repoURL: repoURL)
        try await commitFile("b.txt", contents: "b\n", message: "second", repoURL: repoURL)
        let nodes = try await SpacesService.shared.graph(repositoryURL: repoURL)
        #expect(nodes.count == 2)
        #expect(nodes[0].summary == "second")
        #expect(nodes[1].summary == "first")
        #expect(nodes[0].parents == [nodes[1].oid])
    }
}
