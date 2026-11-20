<!-- system-index-depends: AppSandboxSecurity.md -->
# File Encryption at Rest & Secure Document Vaults

Techniques for encrypting local file storage using CryptoKit and Apple Data Protection (`NSFileProtectionComplete`).

---

## 1. Hardware Data Protection
On macOS and iOS, specify `NSFileProtectionType` when creating sensitive files:
```swift
try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
```

---

## 2. Custom File Encryption with CryptoKit (AES-GCM)
```swift
import CryptoKit

public struct EncryptedFileStorage {
    public static func encryptAndSave(data: Data, key: SymmetricKey, to url: URL) throws {
        let sealedBox = try AES.GCM.seal(data, using: key)
        guard let combined = sealedBox.combined else {
            throw EncryptionError.sealFailed
        }
        try combined.write(to: url, options: .atomic)
    }

    public static func loadAndDecrypt(from url: URL, key: SymmetricKey) throws -> Data {
        let combined = try Data(contentsOf: url)
        let sealedBox = try AES.GCM.SealedBox(combined: combined)
        return try AES.GCM.open(sealedBox, using: key)
    }
}
```
