# SwiftCode

SwiftCode is an AI-powered iOS IDE built with SwiftUI. It provides a local project explorer and editor alongside
integrated AI workflows for generating, modifying, and reviewing Swift code.

## Features

- SwiftUI-based editor, file navigator, and project dashboard
- AI assistant modes for generate, modify, refactor, debug, and agent workflows
- Project management and template creation
- GitHub integration for repository workflows

## Requirements

- Xcode 16+ (iOS 17 SDK)
- macOS 14+ for local builds

## Build & Run (Xcode)

1. Open `SwiftCode.xcodeproj` in Xcode.
2. Select the `SwiftCode` scheme.
3. Run on an iOS 17+ simulator or device.

## Build (CLI)

```bash
xcodebuild archive \
  -project SwiftCode.xcodeproj \
  -scheme "SwiftCode" \
  -archivePath SwiftCode.xcarchive \
  -destination "generic/platform=iOS" \
  CODE_SIGNING_ALLOWED=NO
```

## Tests

There are currently no automated unit tests in this repository.
