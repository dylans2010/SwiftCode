#if canImport(CryptoKit)
import CryptoKit
#endif
import Crypto
import Foundation

#if canImport(Security)
import Security
#endif

public struct Ed25519Signing {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public static let ed25519Method = "ed25519"
    public static let hmacMethod = "hmac-sha256"
    public static let publicKeyRelativePath = "security/signing-public-key.json"

    public struct PublicKeyRecord: Codable, Sendable {
        public var algorithm: String
        public var publicKey: String
        public var fingerprint: String
        public var createdAt: Int64

        public init(algorithm: String, publicKey: String, fingerprint: String, createdAt: Int64) {
            self.algorithm = algorithm
            self.publicKey = publicKey
            self.fingerprint = fingerprint
            self.createdAt = createdAt
        }
    }

    public struct Verification: Sendable {
        public var valid: Bool
        public var method: String
        public var fingerprint: String?
        public var reason: String

        public init(valid: Bool, method: String, fingerprint: String?, reason: String) {
            self.valid = valid
            self.method = method
            self.fingerprint = fingerprint
            self.reason = reason
        }
    }

    public static func canonicalCommitString(_ payload: CommitPayload) -> String {
        let parents = payload.parents.map { $0.hex }.joined(separator: ",")
        return "\(payload.tree.hex)\n\(parents)\n\(payload.author.name) <\(payload.author.email)> \(payload.author.timestamp)\n\(payload.committer.name) <\(payload.committer.email)> \(payload.committer.timestamp)\n\(payload.message)"
    }

    public func publishedPublicKey() throws -> PublicKeyRecord? {
        try SecurityFileStore.load(repo: repo, relativePath: Self.publicKeyRelativePath)
    }

    public func sign(canonical: String) throws -> String {
        migrateLegacyKeyIfPresent()
        #if canImport(CryptoKit)
        let seed = try loadOrCreateSeed()
        let privateKey = try CryptoKit.Curve25519.Signing.PrivateKey(rawRepresentation: seed)
        let publicKeyData = privateKey.publicKey.rawRepresentation
        let fingerprint = SigningKeyStore.fingerprint(of: publicKeyData)
        let record = try ensurePublishedPublicKey(publicKeyData: publicKeyData, fingerprint: fingerprint)
        let signature = try privateKey.signature(for: Data(canonical.utf8))
        return "ed25519.\(fingerprint).\(record.createdAt).\(signature.rawRepresentation.base64EncodedString())"
        #else
        return try SigningOps(repo: repo).sign(type: .commit, object: canonical)
        #endif
    }

    public func verify(canonical: String, signature: String) throws -> Verification {
        if signature.hasPrefix("ed25519.") {
            #if canImport(CryptoKit)
            return try verifyEd25519(canonical: canonical, signature: signature)
            #else
            return Verification(valid: false, method: Self.ed25519Method, fingerprint: nil,
                                reason: "ed25519 signature cannot be verified on this platform: CryptoKit is unavailable")
            #endif
        }
        let detailed = try SigningOps(repo: repo).verifyDetailed(type: .commit, object: canonical, signature: signature)
        if detailed.valid {
            return Verification(valid: true, method: Self.hmacMethod, fingerprint: detailed.fingerprint,
                                reason: "hmac-sha256 signature verifies against the repository signing key")
        }
        return Verification(valid: false, method: Self.hmacMethod, fingerprint: detailed.fingerprint,
                            reason: "hmac-sha256 signature does not match the canonical commit payload")
    }

    public func verifyCommit(oid: ObjectID, payload: CommitPayload) throws -> Verification {
        guard let signature = payload.metadata.signature else {
            return Verification(valid: false, method: "", fingerprint: nil,
                                reason: "commit carries no signature")
        }
        let canonical = Self.canonicalCommitString(payload)
        if signature.hasPrefix("ed25519.") {
            return try verify(canonical: canonical, signature: signature)
        }
        let canonicalResult = try verify(canonical: canonical, signature: signature)
        if canonicalResult.valid {
            return canonicalResult
        }
        let legacy = try SigningOps(repo: repo).verifyDetailed(
            type: .commit, object: oid.hex + payload.message, signature: signature)
        if legacy.valid {
            return Verification(valid: true, method: Self.hmacMethod, fingerprint: legacy.fingerprint,
                                reason: "hmac-sha256 signature verifies against the legacy commit object")
        }
        return canonicalResult
    }

    private func migrateLegacyKeyIfPresent() {
        guard FileManager.default.fileExists(atPath: legacyKeyURL.path) else { return }
        _ = try? SigningKeyStore(repo: repo).loadOrCreate()
    }

    private var legacyKeyURL: URL {
        SigningKeyStore.canonicalMetaURL(for: repo).appendingPathComponent("signing.key")
    }

    private var identityHash: String {
        SigningKeyStore(repo: repo).identityHash
    }

    private var service: String { "spaces-signing-ed25519" }

    private var keyFileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/spaces/keys/\(identityHash).ed25519")
    }

#if canImport(CryptoKit)
    private func loadOrCreateSeed() throws -> Data {
        #if canImport(Security)
        if let existing = try loadSeedFromKeychain() {
            return existing
        }
        let fresh = freshSeed()
        try storeSeedInKeychain(fresh)
        return fresh
        #else
        if let existing = try loadSeedFromFile() {
            return existing
        }
        let fresh = freshSeed()
        try storeSeedToFile(fresh)
        return fresh
        #endif
    }

    private func freshSeed() -> Data {
        let symmetric = Crypto.SymmetricKey(size: .bits256)
        return symmetric.withUnsafeBytes { Data($0) }
    }

    private func ensurePublishedPublicKey(publicKeyData: Data, fingerprint: String) throws -> PublicKeyRecord {
        if let existing = try publishedPublicKey(), existing.fingerprint == fingerprint,
           existing.algorithm == Self.ed25519Method {
            return existing
        }
        let record = PublicKeyRecord(algorithm: Self.ed25519Method,
                                     publicKey: publicKeyData.base64EncodedString(),
                                     fingerprint: fingerprint,
                                     createdAt: Int64(Date().timeIntervalSince1970))
        try repo.withLock {
            try SecurityFileStore.save(repo: repo, relativePath: Self.publicKeyRelativePath, value: record)
        }
        return record
    }

    private func verifyEd25519(canonical: String, signature: String) throws -> Verification {
        let parts = signature.split(separator: ".")
        guard parts.count == 4, parts[0] == "ed25519" else {
            return Verification(valid: false, method: Self.ed25519Method, fingerprint: nil,
                                reason: "malformed ed25519 signature")
        }
        let fingerprint = String(parts[1])
        guard let record = try publishedPublicKey() else {
            return Verification(valid: false, method: Self.ed25519Method, fingerprint: fingerprint,
                                reason: "no published ed25519 public key in this repository")
        }
        guard record.algorithm == Self.ed25519Method else {
            return Verification(valid: false, method: Self.ed25519Method, fingerprint: fingerprint,
                                reason: "published public key record names an unsupported algorithm: \(record.algorithm)")
        }
        guard record.fingerprint == fingerprint else {
            return Verification(valid: false, method: Self.ed25519Method, fingerprint: fingerprint,
                                reason: "signature fingerprint does not match the published public key")
        }
        guard let publicKeyData = Data(base64Encoded: record.publicKey),
              publicKeyData.count == 32,
              SigningKeyStore.fingerprint(of: publicKeyData) == record.fingerprint,
              let signatureData = Data(base64Encoded: String(parts[3])),
              signatureData.count == 64 else {
            return Verification(valid: false, method: Self.ed25519Method, fingerprint: fingerprint,
                                reason: "published public key record or signature encoding is malformed")
        }
        do {
            let publicKey = try CryptoKit.Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData)
            let rawSignature = try CryptoKit.Curve25519.Signing.Signature(rawRepresentation: signatureData)
            let valid = publicKey.isValidSignature(rawSignature, for: Data(canonical.utf8))
            return Verification(valid: valid, method: Self.ed25519Method, fingerprint: fingerprint,
                                reason: valid ? "ed25519 signature verifies against the published public key"
                                    : "ed25519 signature does not match the canonical commit payload")
        } catch {
            return Verification(valid: false, method: Self.ed25519Method, fingerprint: fingerprint,
                                reason: "ed25519 public key or signature is not usable: \(error.localizedDescription)")
        }
    }

    #if canImport(Security)
    private func loadSeedFromKeychain() throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: identityHash,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data, data.count == 32 else {
            throw SpacesError.ioError("cannot read ed25519 signing key from Keychain (status \(status))")
        }
        return data
    }

    private func storeSeedInKeychain(_ data: Data) throws {
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: identityHash,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        let status = SecItemAdd(attributes as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: identityHash
            ]
            let updateStatus = SecItemUpdate(query as CFDictionary,
                                             [kSecValueData as String: data] as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw SpacesError.ioError("cannot update ed25519 signing key in Keychain (status \(updateStatus))")
            }
            return
        }
        guard status == errSecSuccess else {
            throw SpacesError.ioError("cannot store ed25519 signing key in Keychain (status \(status))")
        }
    }
    #endif

    private func loadSeedFromFile() throws -> Data? {
        guard FileManager.default.fileExists(atPath: keyFileURL.path) else { return nil }
        let data = try Data(contentsOf: keyFileURL)
        guard data.count == 32 else {
            throw SpacesError.ioError("ed25519 signing key file is corrupt: \(keyFileURL.path)")
        }
        return data
    }

    private func storeSeedToFile(_ data: Data) throws {
        let dir = keyFileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        try data.write(to: keyFileURL, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: keyFileURL.path)
    }
#endif
}
