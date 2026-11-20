<!-- system-index-depends: XcodebuildMastery.md, AppSandboxSecurity.md -->
# Code Signing, Entitlements & macOS Notarization

Complete workflow for code signing binaries, provisioning profiles, hardened runtimes, and automating Apple notarization via `notarytool`.

---

## 1. Code Signing Architecture
Apple platforms require every executable binary and dynamic framework to possess a valid cryptographic signature.
- **Ad-Hoc Signing (Development):** Signs the binary locally without an Apple Developer certificate:
  ```bash
  codesign --force --deep --sign - "/path/to/App.app"
  ```
- **Developer ID Application (Distribution):** Signs macOS apps for distribution outside the Mac App Store:
  ```bash
  codesign --force --options runtime --sign "Developer ID Application: Team Name (TEAMID)" --entitlements App.entitlements "/path/to/App.app"
  ```

---

## 2. Hardened Runtime & Entitlements
To pass Apple notarization, apps must enable Hardened Runtime (`--options runtime`).
Entitlements specify explicit security exemptions:
- `com.apple.security.app-sandbox`: Enables App Sandbox.
- `com.apple.security.network.client`: Allows outbound TCP/UDP connections.
- `com.apple.security.cs.allow-jit`: Allows JIT compilation.

---

## 3. Automating Notarization with `notarytool`
Submit packaged zip or DMG to Apple Notary Service:
```bash
xcrun notarytool submit \
  "AppBundle.zip" \
  --keychain-profile "AC_NOTARY_PROFILE" \
  --wait
```
Staple ticket to the application bundle:
```bash
xcrun stapler staple "App.app"
```
