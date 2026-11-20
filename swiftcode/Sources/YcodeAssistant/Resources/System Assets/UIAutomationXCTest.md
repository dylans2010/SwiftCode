<!-- system-index-depends: UnitTestingBestPractices.md -->
# UI Automation with XCUITest & Accessibility Anchoring

Authoritative guidelines for building resilient macOS and iOS UI automation test suites using `XCUIApplication`, accessibility identifiers, and asynchronous UI waits.

---

## 1. Principles of Robust UI Testing
- **Accessibility Identifiers as Test Anchors:** Always query UI elements by `accessibilityIdentifier`. Never rely on dynamic localization strings or volatile view positions.
- **Explicit Asynchronous Waiting:** Never use hardcoded delays (`sleep`). Use `waitForExistence(timeout:)` to accommodate render cycles.
- **Hermetic App Launch Arguments:** Pass launch arguments (e.g., `-UITestsRunning`, `-ResetDatabase`) to configure the target app into a known deterministic state.

---

## 2. Setting Up UI Test Targets
In SwiftUI:
```swift
Text("Project Files")
    .accessibilityIdentifier("project_navigator_header")

Button("Build Scheme") {
    // build action
}
.accessibilityIdentifier("toolbar_build_button")
```

In XCUITest:
```swift
import XCTest

final class WorkspaceUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-MockServices"]
        app.launch()
    }

    func testProjectBuildTrigger() throws {
        let buildButton = app.buttons["toolbar_build_button"]
        XCTAssertTrue(buildButton.waitForExistence(timeout: 5.0), "Build button must be visible in toolbar")
        buildButton.click()

        let statusIndicator = app.staticTexts["build_status_indicator"]
        XCTAssertTrue(statusIndicator.waitForExistence(timeout: 10.0), "Status indicator must appear upon build start")
    }
}
```

---

## 3. Avoiding UI Test Flakiness
- Ensure windows are active and focused before clicking (`app.windows.firstMatch.activate()`).
- Handle modal system permission dialogs by setting up `addUIInterruptionMonitor`.
- Run UI tests against fixed simulator configurations or clean macOS test users.
