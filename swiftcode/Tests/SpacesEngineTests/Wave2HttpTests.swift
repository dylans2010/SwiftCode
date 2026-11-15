import Foundation
import Testing
@testable import SpacesEngine

final class StdioPipeHarness: @unchecked Sendable {
    let server: SpacesStdioServer
    let input: Pipe
    let output: Pipe

    init(server: SpacesStdioServer) {
        self.server = server
        self.input = Pipe()
        self.output = Pipe()
    }

    func run() {
        server.run(input: input.fileHandleForReading, output: output.fileHandleForWriting)
    }
}

struct Wave2HttpTests {

    private func placeLfsObject(in repo: Repository, contents: Data) throws -> String {
        let oid = LfsLocalStore.sha256Hex(of: contents)
        let url = LfsLocalStore.objectURL(repo: repo, oid: oid)
        try contents.write(to: url)
        return oid
    }

    private func readLine(from handle: FileHandle) throws -> Data {
        var buffer = Data()
        while true {
            let chunk = handle.availableData
            if chunk.isEmpty {
                return buffer
            }
            buffer.append(chunk)
            if let newline = buffer.firstIndex(of: 10) {
                return Data(buffer.prefix(upTo: newline))
            }
        }
    }

    private func decode(_ data: Data) throws -> [String: Any] {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            Issue.record("expected a JSON object response")
            throw SpacesError.protocolError("bad test response")
        }
        return object
    }

    @Test func protocolHandlerAnswersHello() throws {
        let (repo, _, _) = try SpacesTestSupport.makeRepo()
        let handler = SpacesProtocolHandler(repo: repo)
        let response = try handler.handle(["v": 1, "op": "hello", "caps": ["objects-v1", "refs-v1"]])
        #expect(response["op"] as? String == "hello")
        let caps = response["caps"] as? [String] ?? []
        #expect(caps.contains("objects-v1"))
        #expect(caps.contains("refs-v1"))
        #expect(caps.contains("lfs-v1"))
    }

    @Test func protocolHandlerRejectsUnknownOp() throws {
        let (repo, _, _) = try SpacesTestSupport.makeRepo()
        let handler = SpacesProtocolHandler(repo: repo)
        #expect(throws: SpacesError.self) {
            _ = try handler.handle(["v": 1, "op": "no-such-op"])
        }
    }

    @Test func httpServerBindsOnEphemeralPort() throws {
        let (repo, _, _) = try SpacesTestSupport.makeRepo()
        let server = SpacesHttpServer(repo: repo, port: 0)
        try server.start()
        #expect(server.isRunning == true)
        #expect(server.boundPort != 0)
        #expect(server.baseURL.absoluteString.contains("127.0.0.1"))
        server.stop()
        #expect(server.isRunning == false)
    }

    @Test func httpServerBindConflictErrorsHonestly() throws {
        let (repo, _, _) = try SpacesTestSupport.makeRepo()
        let first = SpacesHttpServer(repo: repo, port: 0)
        try first.start()
        defer { first.stop() }
        let second = SpacesHttpServer(repo: repo, port: first.boundPort)
        do {
            try second.start()
            Issue.record("expected a bind conflict to throw")
            second.stop()
        } catch let error as SpacesError {
            #expect(error.localizedDescription.contains("bind"))
        }
    }

    @Test func httpHelloExchangeSucceeds() throws {
        let (remote, _, _) = try SpacesTestSupport.makeRepo()
        let server = SpacesHttpServer(repo: remote, port: 0)
        try server.start()
        defer { server.stop() }
        let transport = HTTPTransport(url: server.baseURL)
        let conn = try transport.connect()
        defer { conn.close() }
        try conn.send(["v": RepositoryFormat.protocolVersion, "op": "hello",
                       "caps": ["objects-v1", "refs-v1", "lfs-v1"]])
        let response = try conn.receive()
        #expect(response["op"] as? String == "hello")
        #expect(response["v"] as? Int == RepositoryFormat.protocolVersion)
        let caps = response["caps"] as? [String] ?? []
        #expect(caps.contains("lfs-v1"))
    }

    @Test func httpPushThenFetchRoundTripsObjects() throws {
        let (remote, _, _) = try SpacesTestSupport.makeRepo()
        let (source, sourceAPI, _) = try SpacesTestSupport.makeRepo()
        let head = try SpacesTestSupport.commitFiles(sourceAPI, ["a.txt": "hello spaces"], message: "base")
        let server = SpacesHttpServer(repo: remote, port: 0)
        try server.start()
        defer { server.stop() }
        let pushOps = RemoteOps(repo: source)
        try pushOps.add("origin", url: server.baseURL.absoluteString)
        let pushReport = try pushOps.push("origin", refspec: "refs/heads/main:refs/heads/main")
        #expect(pushReport.refsUpdated == ["refs/heads/main"])
        #expect(pushReport.objectsSent > 0)
        #expect(try remote.refs.readRef("refs/heads/main") == head)
        let stored = try remote.objects.read(head)
        #expect(stored.type == .commit)

        let (dest, _, _) = try SpacesTestSupport.makeRepo()
        let fetchOps = RemoteOps(repo: dest)
        try fetchOps.add("origin", url: server.baseURL.absoluteString)
        let fetchReport = try fetchOps.fetch("origin")
        #expect(fetchReport.newObjects > 0)
        #expect(try dest.refs.readRef("refs/remotes/origin/main") == head)
        let blob = try dest.objects.read(ObjectID.blob(Data("hello spaces".utf8)))
        #expect(blob.payload == Data("hello spaces".utf8))
        #expect(ObjectID.compute(type: .blob, payload: blob.payload) == ObjectID.blob(Data("hello spaces".utf8)))
    }

    @Test func httpServerHandlesConcurrentConnections() async throws {
        let (remote, _, _) = try SpacesTestSupport.makeRepo()
        let server = SpacesHttpServer(repo: remote, port: 0)
        try server.start()
        defer { server.stop() }
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<5 {
                group.addTask {
                    let transport = HTTPTransport(url: server.baseURL)
                    let conn = try transport.connect()
                    defer { conn.close() }
                    try conn.send(["v": RepositoryFormat.protocolVersion, "op": "hello",
                                   "caps": ["objects-v1", "refs-v1"]])
                    let response = try conn.receive()
                    guard response["op"] as? String == "hello" else {
                        throw SpacesError.protocolError("bad hello response")
                    }
                }
            }
            try await group.waitForAll()
        }
    }

    @Test func httpServerReturnsErrorEnvelopeForUnknownOp() throws {
        let (remote, _, _) = try SpacesTestSupport.makeRepo()
        let server = SpacesHttpServer(repo: remote, port: 0)
        try server.start()
        defer { server.stop() }
        let conn = try HTTPTransport(url: server.baseURL).connect()
        defer { conn.close() }
        try conn.send(["v": 1, "op": "no-such-op"])
        let response = try conn.receive()
        #expect(response["op"] as? String == "error")
        #expect((response["error"] as? String ?? "").contains("unknown op"))
    }

    @Test func stdioServerAnswersHelloAndRefsOverPipes() async throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        let head = try SpacesTestSupport.commitFiles(api, ["f.txt": "x"], message: "base")
        let server = SpacesStdioServer(repo: api.repo)
        let harness = StdioPipeHarness(server: server)
        let task = Task { harness.run() }
        let writer = harness.input.fileHandleForWriting
        let reader = harness.output.fileHandleForReading
        writer.write(Data("{\"v\": 1, \"op\": \"hello\", \"caps\": [\"objects-v1\", \"refs-v1\"]}\n".utf8))
        let hello = try decode(try readLine(from: reader))
        #expect(hello["op"] as? String == "hello")
        #expect((hello["caps"] as? [String] ?? []).contains("lfs-v1"))
        writer.write(Data("{\"v\": 1, \"op\": \"advertise-refs\"}\n".utf8))
        let refs = try decode(try readLine(from: reader))
        #expect(refs["op"] as? String == "refs")
        let advertised = refs["refs"] as? [[String: Any]] ?? []
        #expect(advertised.contains { ($0["name"] as? String) == "refs/heads/main" && ($0["oid"] as? String) == head.hex })
        try? writer.close()
        await task.value
    }

    @Test func stdioHandlerReturnsErrorEnvelopeForBadJSON() throws {
        let (repo, _, _) = try SpacesTestSupport.makeRepo()
        let server = SpacesStdioServer(repo: repo)
        let response = try decode(server.handleLine(Data("not json".utf8)))
        #expect(response["op"] as? String == "error")
    }

    @Test func stdioHandlerServesWantPack() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        let head = try SpacesTestSupport.commitFiles(api, ["f.txt": "pack me"], message: "base")
        let server = SpacesStdioServer(repo: api.repo)
        let pack = try decode(server.handleLine(
            Data("{\"v\": 1, \"op\": \"want\", \"oids\": [\"\(head.hex)\"], \"haves\": []}\n".utf8)))
        #expect(pack["op"] as? String == "pack")
        let objects = pack["objects"] as? [[String: Any]] ?? []
        #expect(objects.contains { ($0["id"] as? String) == head.hex })
        let blob = try decode(server.handleLine(
            Data("{\"v\": 1, \"op\": \"have\", \"oids\": [\"\(head.hex)\"]}\n".utf8)))
        #expect(blob["op"] as? String == "ack")
        #expect(((blob["oids"] as? [String]) ?? []).contains(head.hex))
    }

    @Test func deleteRefRemovesRemoteBranchOverLocalTransport() throws {
        let (remote, remoteAPI, _) = try SpacesTestSupport.makeRepo()
        let head = try SpacesTestSupport.commitFiles(remoteAPI, ["f.txt": "1"], message: "base")
        try remote.refs.updateRef("refs/heads/feature", to: head)
        let (local, _, _) = try SpacesTestSupport.makeRepo()
        let ops = RemoteOps(repo: local)
        try ops.add("origin", url: remote.worktreeURL.path)
        let fetched = try ops.fetch("origin")
        #expect(fetched.remoteRefs.contains { $0.name == "refs/heads/feature" })
        #expect(try local.refs.readRef("refs/remotes/origin/feature") == head)
        let report = try ops.deleteRemoteRef("origin", ref: "refs/heads/feature")
        #expect(report.deleted == true)
        #expect(try remote.refs.readRef("refs/heads/feature") == nil)
        #expect(try local.refs.readRef("refs/remotes/origin/feature") == nil)
        #expect(try remote.refs.readRef("refs/heads/main") == head)
    }

    @Test func deleteRefMissingBranchThrowsAndLeavesStateUntouched() throws {
        let (remote, remoteAPI, _) = try SpacesTestSupport.makeRepo()
        let head = try SpacesTestSupport.commitFiles(remoteAPI, ["f.txt": "1"], message: "base")
        let (local, _, _) = try SpacesTestSupport.makeRepo()
        let ops = RemoteOps(repo: local)
        try ops.add("origin", url: remote.worktreeURL.path)
        do {
            _ = try ops.deleteRemoteRef("origin", ref: "refs/heads/nope")
            Issue.record("expected delete of a missing remote branch to throw")
        } catch let error as SpacesError {
            #expect(error.localizedDescription.contains("refs/heads/nope"))
        }
        #expect(try remote.refs.readRef("refs/heads/main") == head)
        #expect(try local.refs.readRef("refs/remotes/origin/nope") == nil)
    }

    @Test func deleteRefRefusesCheckedOutBranch() throws {
        let (remote, remoteAPI, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(remoteAPI, ["f.txt": "1"], message: "base")
        let (local, _, _) = try SpacesTestSupport.makeRepo()
        let ops = RemoteOps(repo: local)
        try ops.add("origin", url: remote.worktreeURL.path)
        do {
            _ = try ops.deleteRemoteRef("origin", ref: "refs/heads/main")
            Issue.record("expected delete of the checked-out branch to throw")
        } catch let error as SpacesError {
            #expect(error.localizedDescription.contains("checked-out"))
        }
        #expect(try remote.refs.readRef("refs/heads/main") != nil)
    }

    @Test func deleteRefRemovesRemoteBranchOverHttp() throws {
        let (remote, remoteAPI, _) = try SpacesTestSupport.makeRepo()
        let head = try SpacesTestSupport.commitFiles(remoteAPI, ["f.txt": "1"], message: "base")
        try remote.refs.updateRef("refs/heads/feature", to: head)
        let server = SpacesHttpServer(repo: remote, port: 0)
        try server.start()
        defer { server.stop() }
        let (local, _, _) = try SpacesTestSupport.makeRepo()
        let ops = RemoteOps(repo: local)
        try ops.add("origin", url: server.baseURL.absoluteString)
        let report = try ops.deleteRemoteRef("origin", ref: "refs/heads/feature")
        #expect(report.deleted == true)
        #expect(try remote.refs.readRef("refs/heads/feature") == nil)
    }

    @Test func lfsPushPullOverLocalRemoteMovesObjectAndVerifiesHash() throws {
        let (remote, _, _) = try SpacesTestSupport.makeRepo()
        let (local, _, _) = try SpacesTestSupport.makeRepo()
        let contents = Data("large file contents for lfs transfer".utf8)
        let oid = try placeLfsObject(in: local, contents: contents)
        let ops = LfsTransferOps(repo: local)
        try RemoteOps(repo: local).add("origin", url: remote.worktreeURL.path)
        let pushed = try ops.push("origin")
        #expect(pushed.transferred == 1)
        #expect(pushed.failed.isEmpty)
        #expect(try LfsLocalStore.verifyFile(
            at: LfsLocalStore.objectURL(repo: remote, oid: oid), oid: oid, size: Int64(contents.count)))
        let pushedAgain = try ops.push("origin")
        #expect(pushedAgain.transferred == 0)
        #expect(pushedAgain.alreadyPresent == 1)
        try FileManager.default.removeItem(at: LfsLocalStore.objectURL(repo: local, oid: oid))
        let fetched = try ops.fetch("origin")
        #expect(fetched.transferred == 1)
        #expect(fetched.failed.isEmpty)
        #expect(try LfsLocalStore.verifyFile(
            at: LfsLocalStore.objectURL(repo: local, oid: oid), oid: oid, size: Int64(contents.count)))
        let fetchedAgain = try ops.fetch("origin")
        #expect(fetchedAgain.transferred == 0)
        #expect(fetchedAgain.alreadyPresent == 1)
    }

    @Test func lfsPushPullOverHttpMovesObjectAndVerifiesHash() throws {
        let (remote, _, _) = try SpacesTestSupport.makeRepo()
        let server = SpacesHttpServer(repo: remote, port: 0)
        try server.start()
        defer { server.stop() }
        let (local, _, _) = try SpacesTestSupport.makeRepo()
        let contents = Data((0..<5000).map { UInt8($0 % 251) })
        let oid = try placeLfsObject(in: local, contents: contents)
        let ops = LfsTransferOps(repo: local)
        try RemoteOps(repo: local).add("origin", url: server.baseURL.absoluteString)
        let pushed = try ops.push("origin")
        #expect(pushed.transferred == 1)
        #expect(pushed.failed.isEmpty)
        #expect(try LfsLocalStore.verifyFile(
            at: LfsLocalStore.objectURL(repo: remote, oid: oid), oid: oid, size: Int64(contents.count)))
        try FileManager.default.removeItem(at: LfsLocalStore.objectURL(repo: local, oid: oid))
        let pulled = try ops.pull("origin")
        #expect(pulled.direction == "pull")
        #expect(pulled.transferred == 1)
        #expect(pulled.failed.isEmpty)
        #expect(try LfsLocalStore.verifyFile(
            at: LfsLocalStore.objectURL(repo: local, oid: oid), oid: oid, size: Int64(contents.count)))
    }

    @Test func lfsFetchResumesFromPartialPartFile() throws {
        let (remote, _, _) = try SpacesTestSupport.makeRepo()
        let contents = Data((0..<700000).map { UInt8($0 % 251) })
        let oid = try placeLfsObject(in: remote, contents: contents)
        let (local, _, _) = try SpacesTestSupport.makeRepo()
        let partURL = LfsLocalStore.partURL(repo: local, oid: oid)
        try FileManager.default.createDirectory(at: partURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try Data(contents.prefix(300000)).write(to: partURL)
        let ops = LfsTransferOps(repo: local)
        try RemoteOps(repo: local).add("origin", url: remote.worktreeURL.path)
        let fetched = try ops.fetch("origin")
        #expect(fetched.transferred == 1)
        #expect(fetched.failed.isEmpty)
        #expect(try LfsLocalStore.verifyFile(
            at: LfsLocalStore.objectURL(repo: local, oid: oid), oid: oid, size: Int64(contents.count)))
        #expect(FileManager.default.fileExists(atPath: partURL.path) == false)
    }

    @Test func lfsPushResumesAfterPartialUpload() throws {
        let (remote, _, _) = try SpacesTestSupport.makeRepo()
        let (local, _, _) = try SpacesTestSupport.makeRepo()
        let contents = Data((0..<700000).map { UInt8($0 % 251) })
        let oid = try placeLfsObject(in: local, contents: contents)
        let partURL = LfsLocalStore.partURL(repo: remote, oid: oid)
        try FileManager.default.createDirectory(at: partURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try Data(contents.prefix(300000)).write(to: partURL)
        let ops = LfsTransferOps(repo: local)
        try RemoteOps(repo: local).add("origin", url: remote.worktreeURL.path)
        let pushed = try ops.push("origin")
        #expect(pushed.transferred == 1)
        #expect(pushed.failed.isEmpty)
        #expect(try LfsLocalStore.verifyFile(
            at: LfsLocalStore.objectURL(repo: remote, oid: oid), oid: oid, size: Int64(contents.count)))
    }

    @Test func lfsFetchFailsHonestlyOnCorruptRemoteObject() throws {
        let (remote, _, _) = try SpacesTestSupport.makeRepo()
        let good = Data("the real contents".utf8)
        let oid = LfsLocalStore.sha256Hex(of: good)
        let corrupt = Data("tampered contents, same name".utf8)
        try corrupt.write(to: LfsLocalStore.objectURL(repo: remote, oid: oid))
        let (local, _, _) = try SpacesTestSupport.makeRepo()
        let ops = LfsTransferOps(repo: local)
        try RemoteOps(repo: local).add("origin", url: remote.worktreeURL.path)
        let fetched = try ops.fetch("origin")
        #expect(fetched.transferred == 0)
        #expect(fetched.failed == [oid])
        #expect(FileManager.default.fileExists(
            atPath: LfsLocalStore.objectURL(repo: local, oid: oid).path) == false)
        #expect(FileManager.default.fileExists(
            atPath: LfsLocalStore.partURL(repo: local, oid: oid).path) == false)
    }

    @Test func lfsFetchRestartsCleanlyFromZeroOnOffsetMismatch() throws {
        let (remote, _, _) = try SpacesTestSupport.makeRepo()
        let contents = Data((0..<600000).map { UInt8($0 % 251) })
        let oid = try placeLfsObject(in: remote, contents: contents)
        let (local, _, _) = try SpacesTestSupport.makeRepo()
        let partURL = LfsLocalStore.partURL(repo: local, oid: oid)
        try FileManager.default.createDirectory(at: partURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try Data("garbage prefix that is not part of the real object".utf8).write(to: partURL)
        let ops = LfsTransferOps(repo: local)
        try RemoteOps(repo: local).add("origin", url: remote.worktreeURL.path)
        let fetched = try ops.fetch("origin")
        #expect(fetched.transferred == 1)
        #expect(fetched.failed.isEmpty)
        #expect(try LfsLocalStore.verifyFile(
            at: LfsLocalStore.objectURL(repo: local, oid: oid), oid: oid, size: Int64(contents.count)))
    }

    @Test func localTransportStillSpeaksDeleteRefAndLfs() throws {
        let (remote, remoteAPI, _) = try SpacesTestSupport.makeRepo()
        let head = try SpacesTestSupport.commitFiles(remoteAPI, ["f.txt": "1"], message: "base")
        try remote.refs.updateRef("refs/heads/old", to: head)
        let contents = Data("local transport lfs".utf8)
        let oid = try placeLfsObject(in: remote, contents: contents)
        let transport = LocalTransport(path: remote.worktreeURL.path)
        let conn = try transport.connect()
        defer { conn.close() }
        try conn.send(["v": 1, "op": "hello", "caps": ["objects-v1", "refs-v1", "lfs-v1"]])
        #expect((try conn.receive())["op"] as? String == "hello")
        try conn.send(["v": 1, "op": "lfs-list"])
        let listed = try conn.receive()
        let objects = listed["objects"] as? [[String: Any]] ?? []
        #expect(objects.contains { ($0["oid"] as? String) == oid })
        try conn.send(["v": 1, "op": "delete-ref", "refs": ["refs/heads/old"]])
        let deleted = try conn.receive()
        #expect(deleted["op"] as? String == "ok")
        #expect(try remote.refs.readRef("refs/heads/old") == nil)
    }
}
