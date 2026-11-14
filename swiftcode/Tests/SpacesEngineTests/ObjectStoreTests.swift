import Foundation
import Testing
@testable import SpacesEngine

@Suite struct ObjectStoreTests {
    @Test func writeReadRoundTrip() throws {
        let (repo, _, _) = try SpacesTestSupport.makeRepo()
        let payload = Data("hello spaces".utf8)
        let oid = try repo.objects.write(type: .blob, payload: payload)
        let stored = try repo.objects.read(oid, expectedType: .blob)
        #expect(stored.payload == payload)
        #expect(stored.type == .blob)
    }

    @Test func objectIDIsDeterministicAndContentAddressed() throws {
        let a = ObjectID.blob(Data("same".utf8))
        let b = ObjectID.blob(Data("same".utf8))
        let c = ObjectID.blob(Data("different".utf8))
        #expect(a == b)
        #expect(a != c)
        #expect(a.hex.count == 64)
    }

    @Test func readDetectsCorruption() throws {
        let (repo, _, url) = try SpacesTestSupport.makeRepo()
        let oid = try repo.objects.write(type: .blob, payload: Data("x".utf8))
        let file = repo.objects.url(for: oid)
        try Data("tampered".utf8).write(to: file)
        #expect(throws: SpacesError.self) {
            _ = try repo.objects.read(oid)
        }
        _ = url
    }

    @Test func missingObjectThrows() throws {
        let (repo, _, _) = try SpacesTestSupport.makeRepo()
        #expect(throws: SpacesError.self) {
            _ = try repo.objects.read(ObjectID.blob(Data("nope".utf8)))
        }
    }

    @Test func treeSerializationRoundTrip() throws {
        let (repo, _, _) = try SpacesTestSupport.makeRepo()
        let blobOID = try repo.objects.write(type: .blob, payload: Data("content".utf8))
        let tree = TreePayload(entries: [
            TreeEntry(name: "a.txt", mode: .regular, oid: blobOID),
            TreeEntry(name: "run.sh", mode: .executable, oid: blobOID),
        ])
        let treeOID = try repo.objects.write(.tree, value: tree)
        let decoded: TreePayload = try repo.objects.readPayload(treeOID, expected: .tree)
        #expect(decoded.entries.count == 2)
        #expect(decoded.entries[0].name == "a.txt")
        #expect(decoded.entries[1].mode == .executable)
    }

    @Test func reachableIncludesSubtrees() throws {
        let (repo, _, url) = try SpacesTestSupport.makeRepo()
        let api = SpacesAPI(repo: repo)
        try SpacesTestSupport.write("x", to: url.appendingPathComponent("d/e/f.txt"))
        _ = try api.stageAll()
        let result = try api.commit(message: "nested")
        let commit = try repo.commitObject(result.oid)
        let reachable = try repo.objects.reachable(from: [commit.tree])
        
        #expect(reachable.count >= 4)
    }
}
