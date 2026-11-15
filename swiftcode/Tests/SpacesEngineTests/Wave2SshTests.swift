import Foundation
import Testing
@testable import SpacesEngine

struct Wave2SshTests {

    @Test func sshURLParsesFullForm() throws {
        let parsed = try SshRemoteURL.parse("ssh://git@example.com:2222/repos/app.spaces")
        #expect(parsed.user == "git")
        #expect(parsed.host == "example.com")
        #expect(parsed.port == 2222)
        #expect(parsed.path == "repos/app.spaces")
        #expect(parsed.destination == "git@example.com")
        #expect(parsed.remoteCommand == "spaces serve 'repos/app.spaces'")
    }

    @Test func sshURLParsesWithoutUserOrPort() throws {
        let parsed = try SshRemoteURL.parse("ssh://example.com/repos/app.spaces")
        #expect(parsed.user == nil)
        #expect(parsed.host == "example.com")
        #expect(parsed.port == nil)
        #expect(parsed.path == "repos/app.spaces")
        #expect(parsed.destination == "example.com")
    }

    @Test func scpLikeFormParses() throws {
        let parsed = try SshRemoteURL.parse("git@example.com:repos/app.spaces")
        #expect(parsed.user == "git")
        #expect(parsed.host == "example.com")
        #expect(parsed.port == nil)
        #expect(parsed.path == "repos/app.spaces")
        #expect(parsed.remoteCommand == "spaces serve 'repos/app.spaces'")
    }

    @Test func scpLikeFormWithoutUserStaysLocalPath() throws {
        #expect(SshRemoteURL.isSSHURL("example.com:repos/app.spaces") == false)
        #expect(throws: SpacesError.self) {
            _ = try SshRemoteURL.parse("example.com:repos/app.spaces")
        }
    }

    @Test func sshURLRejectsMissingHost() throws {
        #expect(throws: SpacesError.self) {
            _ = try SshRemoteURL.parse("ssh:///repos/app.spaces")
        }
    }

    @Test func sshURLRejectsMissingPath() throws {
        #expect(throws: SpacesError.self) {
            _ = try SshRemoteURL.parse("ssh://example.com")
        }
        #expect(throws: SpacesError.self) {
            _ = try SshRemoteURL.parse("ssh://example.com/")
        }
    }

    @Test func sshURLRejectsBadPort() throws {
        #expect(throws: SpacesError.self) {
            _ = try SshRemoteURL.parse("ssh://example.com:99999/repos/app.spaces")
        }
    }

    @Test func scpLikeFormRejectsEmptyPath() throws {
        #expect(throws: SpacesError.self) {
            _ = try SshRemoteURL.parse("git@example.com:")
        }
    }

    @Test func shellQuoteEscapesSingleQuotes() throws {
        #expect(SshTransport.shellQuote("plain/path") == "'plain/path'")
        #expect(SshTransport.shellQuote("o'brien/repo") == "'o'\\''brien/repo'")
        let parsed = try SshRemoteURL.parse("ssh://example.com/o'brien/repo")
        #expect(parsed.remoteCommand == "spaces serve 'o'\\''brien/repo'")
    }

    @Test func framingRoundTripPreservesPackMessage() throws {
        let message: [String: Any] = [
            "v": 1,
            "op": "pack",
            "objects": [["id": "abc", "type": "blob", "data": "aGVsbG8="]]
        ]
        let data = try SshTransport.encodeMessage(message)
        #expect(data.last == 10)
        let decoded = try SshTransport.decodeMessage(data)
        #expect(decoded["op"] as? String == "pack")
        #expect(decoded["v"] as? Int == 1)
        let objects = decoded["objects"] as? [[String: Any]]
        #expect(objects?.count == 1)
        #expect(objects?.first?["id"] as? String == "abc")
        #expect(objects?.first?["type"] as? String == "blob")
        #expect(objects?.first?["data"] as? String == "aGVsbG8=")
    }

    @Test func framingRejectsInvalidJSON() throws {
        #expect(throws: SpacesError.self) {
            _ = try SshTransport.decodeMessage(Data("not json".utf8))
        }
    }

    @Test func locateSshBinaryFindsSystemBinary() throws {
        let found = try SshTransport.locateSshBinary()
        #expect(found.hasSuffix("/ssh"))
        #expect(FileManager.default.isExecutableFile(atPath: found))
    }

    @Test func missingSshBinaryErrorNamesConfiguredPath() throws {
        let remoteURL = try SshRemoteURL.parse("ssh://example.com/repos/app.spaces")
        let transport = SshTransport(remoteURL: remoteURL, sshBinaryPath: "/nonexistent/ssh")
        do {
            _ = try transport.connect()
            Issue.record("expected connect to throw with a missing ssh binary")
        } catch let error as SpacesError {
            #expect(error.localizedDescription.contains("/nonexistent/ssh"))
            #expect(error.localizedDescription.contains("ssh binary not found"))
        }
    }

    @Test func transportDispatchesSSHURLs() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        let ops = RemoteOps(repo: api.repo)
        try ops.add("origin", url: "ssh://git@example.com:2222/repos/app.spaces")
        #expect(try ops.transport(for: "origin") is SshTransport)
        try ops.add("scp", url: "git@example.com:repos/app.spaces")
        #expect(try ops.transport(for: "scp") is SshTransport)
        try ops.add("local", url: api.repo.worktreeURL.path)
        #expect(try ops.transport(for: "local") is LocalTransport)
        #expect(try ops.transport(forURL: "https://example.com/repo") is HTTPTransport)
    }

    @Test func remoteHealthReportsUnreachableSSHHost() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        let ops = RemoteOps(repo: api.repo)
        try ops.add("origin", url: "ssh://git@nonexistent.invalid/repos/app.spaces")
        let health = try ops.remoteHealth("origin")
        #expect(health.reachable == false)
    }

    @Test func fetchOverSSHToUnreachableHostThrowsHonestly() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f.txt": "1"], message: "base")
        let ops = RemoteOps(repo: api.repo)
        try ops.add("origin", url: "ssh://git@nonexistent.invalid/repos/app.spaces")
        do {
            _ = try ops.fetch("origin")
            Issue.record("expected fetch over ssh to an unresolvable host to throw")
        } catch let error as SpacesError {
            #expect(error.localizedDescription.contains("ssh"))
        }
    }

    @Test func localhostWithoutCredentialsFailsHonestly() throws {
        let remoteURL = try SshRemoteURL.parse("ssh://spaces-test-nonexistent@localhost/tmp/app.spaces")
        let transport = SshTransport(remoteURL: remoteURL, connectTimeout: 5, operationTimeout: 5)
        let conn = try transport.connect()
        defer { conn.close() }
        do {
            try conn.send(["v": RepositoryFormat.protocolVersion, "op": "hello",
                           "caps": ["objects-v1", "refs-v1"]])
            let response = try conn.receive()
            Issue.record("expected localhost ssh without credentials to fail, got \(response)")
        } catch let error as SpacesError {
            switch error {
            case .authenticationRequired, .remoteError:
                break
            default:
                Issue.record("unexpected ssh failure kind: \(error)")
            }
        }
    }
}
