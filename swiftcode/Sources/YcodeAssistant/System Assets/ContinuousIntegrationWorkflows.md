<!-- system-index-depends: XcodebuildMastery.md -->
# Continuous Integration (CI) Workflows & GitHub Actions for macOS

Configuration templates and optimization strategies for running macOS builds, tests, and release packaging in GitHub Actions.

---

## 1. Recommended GitHub Actions Workflow
```yaml
name: CI Build & Test
on: [push, pull_request]

jobs:
  build:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_16.app
      - name: Build & Test
        run: |
          xcodebuild test \
            -scheme SwiftCode \
            -destination 'platform=macOS,arch=arm64' \
            -derivedDataPath ./build/DerivedData \
            CODE_SIGNING_ALLOWED=NO
```
