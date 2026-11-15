import Crypto
import Foundation

public struct SignedSnapshotOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public static let signingMethod = "hmac-sha256 (symmetric, repo-local key)"

    public struct SnapshotSignatureInfo: Sendable {
        public var snapshot: String
        public var signature: String
        public var signer: String
        public var timestamp: Int64
        public var keyFingerprint: String?
        public var method: String
        public var verified: Bool

        public init(snapshot: String, signature: String, signer: String, timestamp: Int64,
                    keyFingerprint: String?, method: String, verified: Bool) {
            self.snapshot = snapshot
            self.signature = signature
            self.signer = signer
            self.timestamp = timestamp
            self.keyFingerprint = keyFingerprint
            self.method = method
            self.verified = verified
        }
    }

    public struct SnapshotSignatureRecord: Codable, Sendable {
        public var snapshot: String
        public var signature: String
        public var signer: String
        public var timestamp: Int64

        public init(snapshot: String, signature: String, signer: String, timestamp: Int64) {
            self.snapshot = snapshot
            self.signature = signature
            self.signer = signer
            self.timestamp = timestamp
        }
    }

    static func signatureRelativePath(for oid: ObjectID) -> String {
        "snapshots/signatures/\(oid.hex).json"
    }

    static func signedObject(for oid: ObjectID, payload: SnapshotPayload) -> String {
        oid.hex + payload.message
    }

    @discardableResult
    public func signSnapshot(rev: String) throws -> String {
        let oid = try repo.resolveRevision(rev)
        let payload: SnapshotPayload = try repo.objects.readPayload(oid, expected: .snapshot)
        let signature = try SigningOps(repo: repo).sign(
            type: .snapshot, object: Self.signedObject(for: oid, payload: payload))
        let identity = repo.identity()
        let record = SnapshotSignatureRecord(
            snapshot: oid.hex,
            signature: signature,
            signer: "\(identity.name) <\(identity.email)>",
            timestamp: Int64(Date().timeIntervalSince1970))
        try repo.withLock {
            try SecurityFileStore.save(
                repo: repo, relativePath: Self.signatureRelativePath(for: oid), value: record)
        }
        return signature
    }

    public func snapshotSignatureInfo(rev: String) throws -> SnapshotSignatureInfo {
        let oid = try repo.resolveRevision(rev)
        guard let record: SnapshotSignatureRecord = try? SecurityFileStore.load(
            repo: repo, relativePath: Self.signatureRelativePath(for: oid)) else {
            throw SpacesError.refNotFound("no signature recorded for snapshot \(oid.hex)")
        }
        let fingerprint = try? SigningKeyStore(repo: repo).existingKeyInfo()?.fingerprint
        return SnapshotSignatureInfo(
            snapshot: record.snapshot,
            signature: record.signature,
            signer: record.signer,
            timestamp: record.timestamp,
            keyFingerprint: fingerprint,
            method: Self.signingMethod,
            verified: (try? verifySnapshotSignature(rev: rev)) ?? false)
    }

    public func verifySnapshotSignature(rev: String) throws -> Bool {
        let oid = try repo.resolveRevision(rev)
        let payload: SnapshotPayload? = try? repo.objects.readPayload(oid, expected: .snapshot)
        guard let payload = payload,
              let record: SnapshotSignatureRecord = try? SecurityFileStore.load(
                repo: repo, relativePath: Self.signatureRelativePath(for: oid)) else {
            return false
        }
        guard record.snapshot == oid.hex else { return false }
        do {
            return try SigningOps(repo: repo).verify(
                type: .snapshot, object: Self.signedObject(for: oid, payload: payload),
                signature: record.signature)
        } catch {
            return false
        }
    }
}
