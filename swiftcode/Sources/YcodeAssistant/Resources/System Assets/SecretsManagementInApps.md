<!-- system-index-depends: KeychainSecurityArchitecture.md, Safeguards.md -->
# Secrets Management, API Key Protection & Source Sanitization

Strict security controls to prevent leaking API keys, private tokens, passwords, and sensitive credentials in source code or build artifacts.

---

## 1. Absolute Invariants
- **NEVER hardcode API keys or secrets in source code.** No strings like `let apiKey = "sk-ant-..."` or `let geminiKey = "AIzaSy..."`.
- **Exclude local credential files from git:** Ensure `.env`, `keys.plist`, and `GoogleService-Info.plist` are included in `.gitignore`.
- Assist must proactively scan file diffs and reject attempts to write known API key patterns to tracked repositories.

---

## 2. Secure Configuration Loading Patterns
1. **Process Environment Variables:**
   ```swift
   let apiKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"]
   ```
2. **System Keychain:**
   Retrieve user-configured keys dynamically from `KeychainService.shared`.
3. **Build-Time Obfuscation / XCConfig:**
   Inject credentials via user-specific `Local.xcconfig` never checked into version control.
