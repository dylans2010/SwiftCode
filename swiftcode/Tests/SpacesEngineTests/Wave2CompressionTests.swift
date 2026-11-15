import Foundation
import Testing
@testable import SpacesEngine

@Suite struct Wave2CompressionTests {
    private func pseudoRandomBytes(count: Int, seed: UInt32 = 0x12345678) -> Data {
        var state = seed
        var bytes = [UInt8]()
        bytes.reserveCapacity(count)
        for _ in 0..<count {
            state ^= state << 13
            state ^= state >> 17
            state ^= state << 5
            bytes.append(UInt8(state & 0xFF))
        }
        return Data(bytes)
    }

    private func rawFileBytes(_ repo: Repository, _ id: ObjectID) throws -> Data {
        try Data(contentsOf: repo.objects.url(for: id))
    }

    private func uint64BE(_ data: Data, _ range: Range<Int>) -> UInt64 {
        data[range].reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
    }

    private func writeLegacyFile(_ repo: Repository, type: ObjectType, payload: Data) throws -> ObjectID {
        let id = ObjectID.compute(type: type, payload: payload)
        let url = repo.objects.url(for: id)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try ObjectCoding.encode(StoredObject(type: type, payload: payload)).write(to: url)
        return id
    }

    @Test func textBlobRoundTrip() throws {
        let (repo, _, _) = try SpacesTestSupport.makeRepo()
        let payload = Data(String(repeating: "The quick brown fox jumps over the lazy dog. ", count: 200).utf8)
        let oid = try repo.objects.write(type: .blob, payload: payload)
        let stored = try repo.objects.read(oid, expectedType: .blob)
        #expect(stored.payload == payload)
        #expect(stored.type == .blob)
    }

    @Test func binaryBlobRoundTrip() throws {
        let (repo, _, _) = try SpacesTestSupport.makeRepo()
        var bytes = [UInt8]()
        for i in 0..<4096 { bytes.append(UInt8(i % 251)) }
        let payload = Data(bytes)
        let oid = try repo.objects.write(type: .blob, payload: payload)
        let stored = try repo.objects.read(oid, expectedType: .blob)
        #expect(stored.payload == payload)
    }

    @Test func largeObjectRoundTripAndSmallerOnDisk() throws {
        let (repo, _, _) = try SpacesTestSupport.makeRepo()
        let payload = Data(String(repeating: "abcdefgh", count: 131072).utf8)
        #expect(payload.count == 1024 * 1024)
        let oid = try repo.objects.write(type: .blob, payload: payload)
        let stored = try repo.objects.read(oid, expectedType: .blob)
        #expect(stored.payload == payload)
        if ObjectCompression.isAvailable {
            let onDisk = try rawFileBytes(repo, oid)
            #expect(onDisk.count < payload.count / 4)
        }
    }

    @Test func incompressibleDataStoredRaw() throws {
        let (repo, _, _) = try SpacesTestSupport.makeRepo()
        let payload = pseudoRandomBytes(count: 65536)
        let (stored, compressed) = ObjectCompression.encodeForStorage(payload)
        #expect(compressed == false)
        #expect(stored == payload)
        let oid = try repo.objects.write(type: .blob, payload: payload)
        let back = try repo.objects.read(oid, expectedType: .blob)
        #expect(back.payload == payload)
        let onDisk = try rawFileBytes(repo, oid)
        #expect(onDisk.count >= 21)
        #expect(Array(onDisk.prefix(4)) == [0x53, 0x50, 0x43, 0x32])
        #expect(onDisk[4] == 0)
    }

    @Test func corruptCompressedPayloadDetected() throws {
        let (repo, _, _) = try SpacesTestSupport.makeRepo()
        let payload = Data(String(repeating: "0123456789abcdef", count: 4096).utf8)
        let oid = try repo.objects.write(type: .blob, payload: payload)
        var file = try rawFileBytes(repo, oid)
        #expect(file.count > 40)
        file[30] ^= 0xFF
        try file.write(to: repo.objects.url(for: oid))
        #expect(throws: SpacesError.self) {
            _ = try repo.objects.read(oid)
        }
    }

    @Test func corruptEnvelopeLengthDetected() throws {
        let (repo, _, _) = try SpacesTestSupport.makeRepo()
        let payload = Data(String(repeating: "envelope check ", count: 512).utf8)
        let oid = try repo.objects.write(type: .blob, payload: payload)
        var file = try rawFileBytes(repo, oid)
        #expect(file.count > 21)
        file[20] ^= 0x01
        try file.write(to: repo.objects.url(for: oid))
        #expect(throws: SpacesError.self) {
            _ = try repo.objects.read(oid)
        }
    }

    @Test func objectIDStableAcrossCompressedAndLegacyFormats() throws {
        let payload = Data(String(repeating: "stable identity ", count: 256).utf8)
        let expected = ObjectID.compute(type: .blob, payload: payload)
        let (repo, _, _) = try SpacesTestSupport.makeRepo()
        let compressedID = try repo.objects.write(type: .blob, payload: payload)
        #expect(compressedID == expected)
        let (repo2, _, _) = try SpacesTestSupport.makeRepo()
        let legacyID = try writeLegacyFile(repo2, type: .blob, payload: payload)
        #expect(legacyID == expected)
        let legacyBack = try repo2.objects.read(legacyID, expectedType: .blob)
        #expect(legacyBack.payload == payload)
        #expect(compressedID == legacyID)
    }

    @Test func legacyRawObjectStillReadable() throws {
        let (repo, _, _) = try SpacesTestSupport.makeRepo()
        let payload = Data("written before compression existed".utf8)
        let oid = try writeLegacyFile(repo, type: .blob, payload: payload)
        let stored = try repo.objects.read(oid, expectedType: .blob)
        #expect(stored.payload == payload)
        #expect(stored.type == .blob)
        let raw = try rawFileBytes(repo, oid)
        #expect(Array(raw.prefix(4)) == [0x53, 0x50, 0x43, 0x4F])
    }

    @Test func emptyPayloadRoundTrip() throws {
        let (repo, _, _) = try SpacesTestSupport.makeRepo()
        let oid = try repo.objects.write(type: .blob, payload: Data())
        let stored = try repo.objects.read(oid, expectedType: .blob)
        #expect(stored.payload == Data())
    }

    @Test func compressedFileHeaderDescribesContent() throws {
        let (repo, _, _) = try SpacesTestSupport.makeRepo()
        let payload = Data(String(repeating: "header check ", count: 1024).utf8)
        let oid = try repo.objects.write(type: .blob, payload: payload)
        let file = try rawFileBytes(repo, oid)
        #expect(file.count > 21)
        #expect(Array(file.prefix(4)) == [0x53, 0x50, 0x43, 0x32])
        let encodedLength = ObjectCoding.encode(StoredObject(type: .blob, payload: payload)).count
        #expect(uint64BE(file, 5..<13) == UInt64(encodedLength))
        #expect(uint64BE(file, 13..<21) == UInt64(file.count - 21))
        if ObjectCompression.isAvailable {
            #expect(file[4] == 1)
            #expect(uint64BE(file, 13..<21) < UInt64(encodedLength))
        } else {
            #expect(file[4] == 0)
        }
    }

    @Test func jsonPayloadRoundTripThroughCompression() throws {
        let (repo, _, _) = try SpacesTestSupport.makeRepo()
        let blobOID = try repo.objects.write(type: .blob, payload: Data("content".utf8))
        let tree = TreePayload(entries: [
            TreeEntry(name: "a.txt", mode: .regular, oid: blobOID),
            TreeEntry(name: "b.txt", mode: .regular, oid: blobOID),
        ])
        let treeOID = try repo.objects.write(.tree, value: tree)
        let decoded: TreePayload = try repo.objects.readPayload(treeOID, expected: .tree)
        #expect(decoded.entries.count == 2)
        #expect(decoded.entries[0].name == "a.txt")
        #expect(decoded.entries[1].name == "b.txt")
    }

    @Test func directCompressionRoundTripOrHonestFallback() throws {
        let payload = Data(String(repeating: "direct api ", count: 512).utf8)
        if ObjectCompression.isAvailable {
            let compressed = try #require(ObjectCompression.compress(payload))
            #expect(compressed.count < payload.count)
            let back = try ObjectCompression.decompress(compressed, expectedLength: payload.count)
            #expect(back == payload)
            #expect(ObjectCompression.algorithmName == "zlib")
        } else {
            #expect(ObjectCompression.compress(payload) == nil)
        }
    }

    @Test func writeReturnsHashOfUncompressedContent() throws {
        let (repo, _, _) = try SpacesTestSupport.makeRepo()
        let payload = Data(String(repeating: "id rule ", count: 128).utf8)
        let oid = try repo.objects.write(type: .blob, payload: payload)
        #expect(oid == ObjectID.compute(type: .blob, payload: payload))
        #expect(oid == ObjectID.blob(payload))
        let again = try repo.objects.write(type: .blob, payload: payload)
        #expect(again == oid)
    }
}
