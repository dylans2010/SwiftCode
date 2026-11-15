import Crypto
import Foundation


public struct TagOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public struct TagInfo: Sendable, Encodable {
        public var name: String
        public var oid: ObjectID          
        public var peeled: ObjectID?      
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
        
        if let oid = try repo.refs.readRef(full) {
            let stamp = Int64(Date().timeIntervalSince1970)
            _ = try repo.refs.updateRef("refs/archive/tags/\(name)-\(stamp)", to: oid)
        }
        try repo.refs.deleteRef(full)
        }
    }

    
    
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

    
    func signPayload(type: ObjectType, object: String) throws -> String {
        try SigningOps(repo: repo).sign(type: type, object: object)
    }
}






public struct SigningOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public struct SignatureVerification: Sendable {
        public var valid: Bool
        public var fingerprint: String?
        public var createdAt: Date?
    }

    public func signingKey() throws -> Data { return try repo.withLock {
        try SigningKeyStore(repo: repo).loadOrCreate()
        }
    }

    public func signingKeyInfo() throws -> SigningKeyStore.KeyInfo {
        try SigningKeyStore(repo: repo).keyInfo()
    }

    private func macHex(type: ObjectType, object: String, key: Data) -> String {
        let symmetricKey = SymmetricKey(data: key)
        let mac = HMAC<SHA256>.authenticationCode(
            for: Data("spaces-sign-v1\n\(type.rawValue)\n\(object)".utf8),
            using: symmetricKey)
        return mac.map { String(format: "%02x", $0) }.joined()
    }

    public func sign(type: ObjectType, object: String) throws -> String {
        let store = SigningKeyStore(repo: repo)
        let key = try store.loadOrCreate()
        let info = try store.keyInfo()
        let createdAt = Int64(info.createdAt?.timeIntervalSince1970 ?? 0)
        return "v2.\(info.fingerprint).\(createdAt).\(macHex(type: type, object: object, key: key))"
    }

    public func verify(type: ObjectType, object: String, signature: String) throws -> Bool {
        try verifyDetailed(type: type, object: object, signature: signature).valid
    }

    public func verifyDetailed(type: ObjectType, object: String,
                               signature: String) throws -> SignatureVerification {
        let parts = signature.split(separator: ".")
        if parts.count == 4, parts[0] == "v2" {
            let store = SigningKeyStore(repo: repo)
            let key = try store.loadOrCreate()
            let valid = macHex(type: type, object: object, key: key) == String(parts[3])
            let createdAt = Int64(String(parts[2])).map { Date(timeIntervalSince1970: TimeInterval($0)) }
            return SignatureVerification(valid: valid, fingerprint: String(parts[1]),
                                         createdAt: createdAt)
        }
        let store = SigningKeyStore(repo: repo)
        let key = try store.loadOrCreate()
        let info = try store.keyInfo()
        return SignatureVerification(valid: macHex(type: type, object: object, key: key) == signature,
                                     fingerprint: info.fingerprint, createdAt: info.createdAt)
    }
}
