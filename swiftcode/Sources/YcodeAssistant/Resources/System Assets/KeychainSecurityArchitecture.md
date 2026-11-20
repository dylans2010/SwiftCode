<!-- system-index-depends: AppSandboxSecurity.md, Safeguards.md -->
# Keychain Security & Biometric Access Control

Technical standard for securely storing API keys, OAuth tokens, private certificates, and sensitive credentials in the Apple Keychain Services API.

---

## 1. The Keychain Services Architecture
Keychain Services provides hardware-accelerated, encrypted storage managed by the macOS `securityd` daemon and the Secure Enclave.
- Sensitive items are stored using `SecItemAdd`, `SecItemCopyMatching`, `SecItemUpdate`, and `SecItemDelete`.
- Items are isolated by access group entitlements (`kSecAttrAccessGroup`).

---

## 2. Production Keychain Wrapper Implementation
```swift
import Foundation
import Security

public final class SecureCredentialStorage: Sendable {
    public static let shared = SecureCredentialStorage()
    private let serviceName = "com.swiftcode.credentials"

    public func store(key: String, data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.status(status)
        }
    }

    public func retrieve(key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            throw KeychainError.status(status)
        }
        return data
    }
}
```

---

## 3. Biometric Protection with `SecAccessControl`
For high-security operations (e.g. signing release binaries), attach biometric Touch ID requirements using `SecAccessControlCreateWithFlags` with `.biometryCurrentSet`.
