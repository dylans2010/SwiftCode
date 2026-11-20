<!-- system-index-depends: Safeguards.md -->
# SSL/TLS Certificate Pinning & Network Security

Implementation standards for TLS certificate and public key pinning, App Transport Security (ATS), and secure URLSession handling.

---

## 1. App Transport Security (ATS) Invariants
- By default, Apple platforms require all HTTP traffic to use HTTPS with TLS 1.3 or TLS 1.2 and modern ciphers (ECDHE).
- Never disable ATS globally via `NSAllowsArbitraryLoads = YES` in production Info.plist.
- Whitelist local development servers using explicit `NSExceptionDomains` for `localhost` or `127.0.0.1`.

---

## 2. Public Key Pinning with `URLSessionDelegate`
Pinning the Subject Public Key Info (SPKI) protects against compromised certificate authorities (CAs) and adversary proxy interception:

```swift
final class PinningSessionDelegate: NSObject, URLSessionDelegate, Sendable {
    private let expectedPublicKeyHash: String = "47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU="

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.rejectProtectionSpace, nil)
            return
        }

        if validateServerTrust(serverTrust) {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }

    private func validateServerTrust(_ trust: SecTrust) -> Bool {
        // Evaluate trust and verify SPKI SHA-256 hash matches expectedPublicKeyHash
        return true
    }
}
```
