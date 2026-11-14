import Crypto
import Foundation

/// Tag operations: lightweight and annotated (optionally signed) tags.
public struct TagOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public struct TagInfo: Sendable, Encodable {
        public var name: String
        public var oid: ObjectID          // ref target
        public var peeled: ObjectID?      // commit for annotated tags
        public var isAnnotated: Bool
        public var tagger: Signature?
        public var message: String
        public var signature: String?
    }

    public func list() throws -> [TagInfo] {
        var result: [TagInfo] = []
        for ref in try repo.refs.tags() {
            var info = TagInfo(name: ref.shortName, oid: ref.oid, peeled: nil,
                               isAnnotated: false, tagger: nil, message: "", signature: nil)
            if let tag = try? repo.objects.read(ref.oid, expectedType: .tag),
               let payload = try? JSONDecoder().decode(TagPayload.self, from: tag.payload) {
                info.isAnnotated = true
                info.peeled = payload.object
                info.tagger = payload.tagger
                info.message = payload.message
                info.signature = payload.signature
            } else {
                info.peeled = ref.oid
            }
            result.append(info)
        }
        return result.sorted { $0.name < $1.name }
    }

    /// `spaces tag <name> [rev]` — lightweight; `spaces tag-create -a` annotated.
    @discardableResult
    public func create(_ name: String, at rev: String = "HEAD",
                       annotated: Bool = false, message: String = "",
                       sign: Bool = false) throws -> ObjectID { return try repo.withLock {
        guard RefDatabase.isValidRefName("refs/tags/" + name) else {
            throw SpacesError.invalidRef(name)
        }
        let full = "refs/tags/\(name)"
        if try repo.refs.readRef(full) != nil { throw SpacesError.invalidArgument("tag exists: \(name)") }
        let target = try repo.resolveRevision(rev)

        let refOID: ObjectID
        if annotated {
            let tagger = repo.identity()
            let signature = sign ? try signPayload(type: .tag, object: target.hex + message) : nil
            let payload = TagPayload(object: target, objectType: .commit, name: name,
                                     tagger: tagger, message: message, signature: signature)
            refOID = try repo.objects.write(.tag, value: payload)
        } else {
            refOID = target
        }
        let old = try repo.refs.updateRef(full, to: refOID)
        try repo.appendReflog(refName: full, old: old, new: refOID,
                              message: "tag \(annotated ? "annotated " : "")\(name)")
        return refOID
        }
    }

    public func delete(_ name: String) throws { return try repo.withLock {
        let full = "refs/tags/\(name)"
        guard try repo.refs.readRef(full) != nil else { throw SpacesError.refNotFound(name) }
        // Recoverable: archive like branches.
        if let oid = try repo.refs.readRef(full) {
            let stamp = Int64(Date().timeIntervalSince1970)
            _ = try repo.refs.updateRef("refs/archive/tags/\(name)-\(stamp)", to: oid)
        }
        try repo.refs.deleteRef(full)
        }
    }

    /// `spaces tag-verify` — verifies an annotated tag's signature if present.
    /// Signature scheme: HMAC-SHA256 with the repo's signing key (see Signing).
    public func verify(_ name: String) throws -> Bool {
        guard let ref = try repo.refs.tags().first(where: { $0.shortName == name }) else {
            throw SpacesError.refNotFound(name)
        }
        guard let tag = try? repo.objects.read(ref.oid, expectedType: .tag),
              let payload = try? JSONDecoder().decode(TagPayload.self, from: tag.payload) else {
            throw SpacesError.invalidArgument("not an annotated tag: \(name)")
        }
        guard let sig = payload.signature else {
            return false
        }
        return try SigningOps(repo: repo).verify(type: .tag, object: payload.object.hex + payload.message,
                                                 signature: sig)
    }

    /// Signs arbitrary content with the repository signing key.
    func signPayload(type: ObjectType, object: String) throws -> String {
        try SigningOps(repo: repo).sign(type: type, object: object)
    }
}

/// Signing: HMAC-SHA256 based detached signatures using a per-repo key stored
/// in `.spaces/signing.key` (created on demand, mode 0600). This is a real,
/// verifiable signature scheme; it is symmetric (repo-local) rather than
/// asymmetric — suitable for integrity attestation. Asymmetric signing can be
/// layered via `extensions` later.
public struct SigningOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    private var keyURL: URL { repo.metaURL.appendingPathComponent("signing.key") }

    /// Returns the repo signing key, generating one if absent.
    public func signingKey() throws -> Data { return try repo.withLock {
        if let data = try? Data(contentsOf: keyURL), data.count >= 32 { return data }
        // Generate via Crypto's CSPRNG-backed SymmetricKey (portable).
        let symmetric = SymmetricKey(size: .bits256)
        let data = symmetric.withUnsafeBytes { Data($0) }
        try data.write(to: keyURL, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: keyURL.path)
        return data
        }
    }

    /// Produces a detached signature: hex HMAC-SHA256 over
    /// "spaces-sign-v1\n<type>\n<object>".
    public func sign(type: ObjectType, object: String) throws -> String {
        let key = try signingKey()
        let symmetricKey = SymmetricKey(data: key)
        let mac = HMAC<SHA256>.authenticationCode(
            for: Data("spaces-sign-v1\n\(type.rawValue)\n\(object)".utf8),
            using: symmetricKey)
        return mac.map { String(format: "%02x", $0) }.joined()
    }

    public func verify(type: ObjectType, object: String, signature: String) throws -> Bool {
        let expected = try sign(type: type, object: object)
        return expected == signature
    }
}
