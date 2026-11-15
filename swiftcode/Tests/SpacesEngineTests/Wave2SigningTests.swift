import Foundation
import Testing
@testable import SpacesEngine

struct Wave2SigningTests {
#if canImport(CryptoKit)
    private func signHeadWithEd25519(_ api: SpacesAPI) throws -> ObjectID {
        let repo = api.repo
        let oldOID = try repo.resolveRevision("HEAD")
        let payload = try repo.commitObject(oldOID)
        let signature = try Ed25519Signing(repo: repo).sign(
            canonical: Ed25519Signing.canonicalCommitString(payload))
        var rewritten = payload
        rewritten.metadata.signature = signature
        let newOID = try repo.objects.write(.commit, value: rewritten)
        for ref in try repo.refs.allRefs() where ref.oid == oldOID {
            _ = try repo.refs.updateRef(ref.name, to: newOID)
        }
        return newOID
    }

    private func rewriteHeadMessage(_ api: SpacesAPI, message: String) throws -> ObjectID {
        let repo = api.repo
        let oldOID = try repo.resolveRevision("HEAD")
        var payload = try repo.commitObject(oldOID)
        payload.message = message
        let newOID = try repo.objects.write(.commit, value: payload)
        for ref in try repo.refs.allRefs() where ref.oid == oldOID {
            _ = try repo.refs.updateRef(ref.name, to: newOID)
        }
        return newOID
    }
#endif

#if canImport(CryptoKit)
    @Test func ed25519SignAndVerifyRoundTrip() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        let oid = try SpacesTestSupport.commitFiles(api, ["f.txt": "1"], message: "base")
        let payload = try api.repo.commitObject(oid)
        let canonical = Ed25519Signing.canonicalCommitString(payload)
        let signature = try Ed25519Signing(repo: api.repo).sign(canonical: canonical)
        #expect(signature.hasPrefix("ed25519."))
        let result = try Ed25519Signing(repo: api.repo).verify(canonical: canonical, signature: signature)
        #expect(result.valid)
        #expect(result.method == "ed25519")
        #expect(result.fingerprint != nil)
    }

    @Test func tamperedCommitPayloadFailsVerification() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        let oid = try SpacesTestSupport.commitFiles(api, ["f.txt": "1"], message: "base")
        let payload = try api.repo.commitObject(oid)
        let canonical = Ed25519Signing.canonicalCommitString(payload)
        let signature = try Ed25519Signing(repo: api.repo).sign(canonical: canonical)
        var tampered = payload
        tampered.message = "tampered message"
        let tamperedCanonical = Ed25519Signing.canonicalCommitString(tampered)
        let result = try Ed25519Signing(repo: api.repo).verify(canonical: tamperedCanonical, signature: signature)
        #expect(!result.valid)
        #expect(result.method == "ed25519")
        let good = try Ed25519Signing(repo: api.repo).verify(canonical: canonical, signature: signature)
        #expect(good.valid)
    }

    @Test func keyFingerprintMatchesStoredPublicKey() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        let oid = try SpacesTestSupport.commitFiles(api, ["f.txt": "1"], message: "base")
        let payload = try api.repo.commitObject(oid)
        let canonical = Ed25519Signing.canonicalCommitString(payload)
        let signature = try Ed25519Signing(repo: api.repo).sign(canonical: canonical)
        let result = try Ed25519Signing(repo: api.repo).verify(canonical: canonical, signature: signature)
        let record = try Ed25519Signing(repo: api.repo).publishedPublicKey()
        #expect(record != nil)
        #expect(record?.algorithm == "ed25519")
        #expect(record?.fingerprint == result.fingerprint)
        let keyData = try #require(Data(base64Encoded: record?.publicKey ?? ""))
        #expect(keyData.count == 32)
        #expect(SigningKeyStore.fingerprint(of: keyData) == record?.fingerprint)
    }

    @Test func privateKeyNeverEntersRepository() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        let oid = try SpacesTestSupport.commitFiles(api, ["f.txt": "1"], message: "base")
        let payload = try api.repo.commitObject(oid)
        _ = try Ed25519Signing(repo: api.repo).sign(canonical: Ed25519Signing.canonicalCommitString(payload))
        let recordURL = api.repo.metaURL.appendingPathComponent(Ed25519Signing.publicKeyRelativePath)
        #expect(FileManager.default.fileExists(atPath: recordURL.path))
        var leaked: [String] = []
        let enumerator = FileManager.default.enumerator(atPath: api.repo.metaURL.path)
        while let path = enumerator?.nextObject() as? String {
            if path.hasSuffix(".ed25519") || path.hasSuffix("signing.key") {
                leaked.append(path)
            }
        }
        #expect(leaked.isEmpty)
    }

    @Test func provenanceAcceptsEd25519SignedCommit() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f.txt": "1"], message: "base")
        _ = try signHeadWithEd25519(api)
        let checks = try api.verifyProvenance(rev: "HEAD")
        #expect(checks.contains { $0.name == "signature" && $0.passed })
        #expect(checks.contains { $0.name == "signature" && $0.detail.contains("ed25519") })
        _ = try rewriteHeadMessage(api, message: "tampered message")
        let tamperedChecks = try api.verifyProvenance(rev: "HEAD")
        #expect(tamperedChecks.contains { $0.name == "signature" && !$0.passed })
    }

    @Test func publishedPublicKeyFromAnotherRepoDoesNotVerify() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        let oid = try SpacesTestSupport.commitFiles(api, ["f.txt": "1"], message: "base")
        let payload = try api.repo.commitObject(oid)
        let canonical = Ed25519Signing.canonicalCommitString(payload)
        let signature = try Ed25519Signing(repo: api.repo).sign(canonical: canonical)
        let (_, otherAPI, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(otherAPI, ["g.txt": "2"], message: "other")
        _ = try Ed25519Signing(repo: otherAPI.repo).sign(canonical: "other-canonical")
        let otherRecord = try #require(try Ed25519Signing(repo: otherAPI.repo).publishedPublicKey())
        let recordURL = api.repo.metaURL.appendingPathComponent(Ed25519Signing.publicKeyRelativePath)
        try JSONEncoder().encode(otherRecord).write(to: recordURL, options: .atomic)
        let result = try Ed25519Signing(repo: api.repo).verify(canonical: canonical, signature: signature)
        #expect(!result.valid)
        #expect(result.reason.contains("fingerprint"))
    }

    @Test func tamperedSignatureBytesFailVerification() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        let oid = try SpacesTestSupport.commitFiles(api, ["f.txt": "1"], message: "base")
        let payload = try api.repo.commitObject(oid)
        let canonical = Ed25519Signing.canonicalCommitString(payload)
        let signature = try Ed25519Signing(repo: api.repo).sign(canonical: canonical)
        var chars = Array(signature)
        let lastIndex = chars.count - 1
        chars[lastIndex] = chars[lastIndex] == "A" ? "B" : "A"
        let tampered = String(chars)
        let result = try Ed25519Signing(repo: api.repo).verify(canonical: canonical, signature: tampered)
        #expect(!result.valid)
    }
#endif

    @Test func legacyInRepoKeyIsMigratedOnSigning() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f.txt": "1"], message: "base")
        let legacyURL = api.repo.metaURL.appendingPathComponent("signing.key")
        try Data(repeating: 0x41, count: 32).write(to: legacyURL, options: .atomic)
        let oid = try api.repo.resolveRevision("HEAD")
        let payload = try api.repo.commitObject(oid)
        _ = try Ed25519Signing(repo: api.repo).sign(canonical: Ed25519Signing.canonicalCommitString(payload))
        #expect(!FileManager.default.fileExists(atPath: legacyURL.path))
    }

    @Test func signingMethodIsReportedHonestly() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        let oid = try SpacesTestSupport.commitFiles(api, ["f.txt": "1"], message: "base")
        let payload = try api.repo.commitObject(oid)
        let canonical = Ed25519Signing.canonicalCommitString(payload)
        let signature = try Ed25519Signing(repo: api.repo).sign(canonical: canonical)
        let result = try Ed25519Signing(repo: api.repo).verify(canonical: canonical, signature: signature)
        #expect(result.valid)
        #if canImport(CryptoKit)
        #expect(result.method == "ed25519")
        #expect(signature.hasPrefix("ed25519."))
        #else
        #expect(result.method == "hmac-sha256")
        #expect(signature.hasPrefix("v2."))
        #endif
    }

    @Test func legacyHmacSignatureStillVerifies() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        let oid = try SpacesTestSupport.commitFiles(api, ["f.txt": "1"], message: "base")
        let payload = try api.repo.commitObject(oid)
        let canonical = Ed25519Signing.canonicalCommitString(payload)
        let signature = try SigningOps(repo: api.repo).sign(type: .commit, object: canonical)
        let result = try Ed25519Signing(repo: api.repo).verify(canonical: canonical, signature: signature)
        #expect(result.valid)
        #expect(result.method == "hmac-sha256")
        let tampered = try Ed25519Signing(repo: api.repo).verify(canonical: canonical + "x", signature: signature)
        #expect(!tampered.valid)
        #expect(tampered.method == "hmac-sha256")
    }
}
