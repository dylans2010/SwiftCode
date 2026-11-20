<!-- system-index-depends: UnitTestingBestPractices.md, SwiftUIArchitecture.md -->
# Snapshot Testing Strategies & Visual Regression Gates

Guidelines for implementing snapshot testing to prevent unintended visual, structural, and semantic UI regressions across Apple platforms.

---

## 1. The Value of Snapshot Testing
Snapshot tests capture a serialized representation of a component (image pixel bitmap, accessibility hierarchy, or view inspect AST) and compare it against a verified baseline stored in the repository.

### Use Cases:
- Preventing visual layout bugs during theme or design system updates.
- Verifying multi-device, multi-locale, and dynamic type configurations.
- Documenting visual states across dark mode, light mode, and high contrast.

---

## 2. Implementing View Snapshots
Using standard snapshot techniques on macOS:
```swift
import XCTest
import SwiftUI
@testable import YcodeUI

final class ComponentSnapshotTests: XCTestCase {
    @MainActor
    func testAssistantBadgeRendering() throws {
        let view = AssistantModeBadge(mode: .autopilot)
            .frame(width: 120, height: 32)
        
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = CGRect(x: 0, y: 0, width: 120, height: 32)
        
        let bitmap = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds)!
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
        
        // Compare bitmap data against reference baseline artifact
    }
}
```

---

## 3. Managing Reference Artifacts
- Store baseline images in a designated `__Snapshots__` directory co-located with the test suite.
- Regenerate snapshots explicitly via an environment flag (e.g. `RECORD_SNAPSHOTS=1`).
- Avoid storing multi-megabyte uncompressed TIFFs; use PNG optimization to minimize Git LFS overhead.
