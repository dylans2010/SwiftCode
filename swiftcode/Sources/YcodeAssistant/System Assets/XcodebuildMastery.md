<!-- system-index-depends: BuildAndTesting.md, XcodeBuildSettingsReference.md -->
# Xcodebuild CLI Mastery & Build Automation

Authoritative reference for executing, scripting, and optimizing `xcodebuild` invocations for macOS, iOS, and multi-platform targets.

---

## 1. Anatomy of an `xcodebuild` Invocation
Basic syntax:
```bash
xcodebuild \
  -scheme <SchemeName> \
  -configuration <Debug|Release> \
  -destination '<DestinationSpecifier>' \
  -derivedDataPath ./build/DerivedData \
  build
```

### Essential Flags:
- `-workspace <Path.xcworkspace>`: Required when building CocoaPods or multi-project workspaces.
- `-project <Path.xcodeproj>`: Used for single-project builds.
- `-derivedDataPath <Path>`: Isolates compilation artifacts, module caches, and logs into a predictable workspace-relative directory.
- `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""`: Disables code signing for rapid local testing and CI verification.
- `-resultBundlePath <Path.xcresult>`: Emits structured build and test results for parsing via `xcresulttool`.

---

## 2. Common Destinations
- **macOS Native:** `-destination 'platform=macOS,arch=arm64'`
- **iOS Simulator:** `-destination 'platform=iOS Simulator,name=iPhone 16,OS=latest'`
- **Generic iOS (Archive):** `-destination 'generic/platform=iOS'`

---

## 3. Parsing Build Logs & Diagnostic Filtering
Use modern build log formatters such as `xcbeautify` or `xcpretty` to filter verbose logs:
```bash
set -o pipefail && xcodebuild -scheme SwiftCode build | xcbeautify
```
Assist parses compiler error lines matching the standard format:
`/path/to/File.swift:<line>:<col>: error: <message>`

---

## 4. Assist Operational Rules
- Always specify `-derivedDataPath` to prevent dirtying global `~/Library/Developer/Xcode/DerivedData`.
- Use `CODE_SIGNING_ALLOWED=NO` during intermediate agent test compilation loops.
- Check exit codes: exit code `0` indicates success; any non-zero indicates build failure.
