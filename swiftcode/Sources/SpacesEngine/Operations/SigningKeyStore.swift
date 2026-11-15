import Crypto
import Foundation

#if canImport(Security)
import Security
#endif

public struct SigningKeyStore {
    public let repo: Repository
    public let identityHash: String

    public struct KeyInfo: Sendable {
        public var fingerprint: String
        public var createdAt: Date?
    }

    public init(repo: Repository) {
        self.repo = repo
        self.identityHash = Self.identityHash(for: repo)
    }

    public static func fingerprint(of key: Data) -> String {
        let digest = SHA256.hash(data: key)
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return String(hex.prefix(16))
    }

    public static func canonicalMetaURL(for repo: Repository) -> URL {
        let commondirURL = repo.metaURL.appendingPathComponent("commondir")
        if let text = try? String(contentsOf: commondirURL, encoding: .utf8) {
            let candidate = URL(fileURLWithPath: text.trimmingCharacters(in: .whitespacesAndNewlines))
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: candidate.path, isDirectory: &isDir),
               isDir.boolValue {
                return candidate
            }
        }
        return repo.metaURL
    }

    private static func identityHash(for repo: Repository) -> String {
        let digest = SHA256.hash(data: Data(canonicalMetaURL(for: repo).path.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private var legacyKeyURL: URL {
        Self.canonicalMetaURL(for: repo).appendingPathComponent("signing.key")
    }

    private var service: String { "spaces-signing" }

    private var keyFileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/spaces/keys/\(identityHash).key")
    }

    public func loadOrCreate() throws -> Data {
        #if canImport(Security)
        if let existing = try loadFromKeychain() {
            try? FileManager.default.removeItem(at: legacyKeyURL)
            return existing
        }
        if let legacy = readLegacyKey() {
            try storeInKeychain(legacy)
            try? FileManager.default.removeItem(at: legacyKeyURL)
            return legacy
        }
        let fresh = generateKey()
        try storeInKeychain(fresh)
        try? FileManager.default.removeItem(at: legacyKeyURL)
        return fresh
        #else
        if let existing = try loadFromFile() {
            try? FileManager.default.removeItem(at: legacyKeyURL)
            return existing
        }
        if let legacy = readLegacyKey() {
            try storeToFile(legacy)
            try? FileManager.default.removeItem(at: legacyKeyURL)
            return legacy
        }
        let fresh = generateKey()
        try storeToFile(fresh)
        try? FileManager.default.removeItem(at: legacyKeyURL)
        return fresh
        #endif
    }

    public func keyInfo() throws -> KeyInfo {
        let key = try loadOrCreate()
        let fingerprint = Self.fingerprint(of: key)
        #if canImport(Security)
        if let date = try keychainCreationDate() {
            return KeyInfo(fingerprint: fingerprint, createdAt: date)
        }
        return KeyInfo(fingerprint: fingerprint, createdAt: nil)
        #else
        let attrs = try? FileManager.default.attributesOfItem(atPath: keyFileURL.path)
        let date = (attrs?[.creationDate] as? Date) ?? (attrs?[.modificationDate] as? Date)
        return KeyInfo(fingerprint: fingerprint, createdAt: date)
        #endif
    }

    public func existingKeyInfo() throws -> KeyInfo? {
        #if canImport(Security)
        if let key = try loadFromKeychain() {
            return KeyInfo(fingerprint: Self.fingerprint(of: key),
                           createdAt: try keychainCreationDate())
        }
        #else
        if let key = try loadFromFile() {
            let attrs = try? FileManager.default.attributesOfItem(atPath: keyFileURL.path)
            let date = (attrs?[.creationDate] as? Date) ?? (attrs?[.modificationDate] as? Date)
            return KeyInfo(fingerprint: Self.fingerprint(of: key), createdAt: date)
        }
        #endif
        if let legacy = readLegacyKey() {
            return KeyInfo(fingerprint: Self.fingerprint(of: legacy), createdAt: nil)
        }
        return nil
    }

    private func generateKey() -> Data {
        let symmetric = SymmetricKey(size: .bits256)
        return symmetric.withUnsafeBytes { Data($0) }
    }

    private func readLegacyKey() -> Data? {
        guard let data = try? Data(contentsOf: legacyKeyURL), data.count >= 32 else {
            return nil
        }
        return data
    }

    #if canImport(Security)
    private func loadFromKeychain() throws -> Data? {
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
        guard status == errSecSuccess, let data = result as? Data, data.count >= 32 else {
            throw SpacesError.ioError("cannot read signing key from Keychain (status \(status))")
        }
        return data
    }

    private func storeInKeychain(_ data: Data) throws {
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
                throw SpacesError.ioError("cannot update signing key in Keychain (status \(updateStatus))")
            }
            return
        }
        guard status == errSecSuccess else {
            throw SpacesError.ioError("cannot store signing key in Keychain (status \(status))")
        }
    }

    private func keychainCreationDate() throws -> Date? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: identityHash,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let attributes = result as? [String: Any] else {
            return nil
        }
        return attributes[kSecAttrCreationDate as String] as? Date
    }
    #endif

    private func loadFromFile() throws -> Data? {
        guard FileManager.default.fileExists(atPath: keyFileURL.path) else { return nil }
        let data = try Data(contentsOf: keyFileURL)
        guard data.count >= 32 else {
            throw SpacesError.ioError("signing key file is corrupt: \(keyFileURL.path)")
        }
        return data
    }

    private func storeToFile(_ data: Data) throws {
        let dir = keyFileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        try data.write(to: keyFileURL, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: keyFileURL.path)
    }
}
