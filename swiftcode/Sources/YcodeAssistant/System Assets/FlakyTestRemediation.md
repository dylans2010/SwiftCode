<!-- system-index-depends: UnitTestingBestPractices.md -->
# Flaky Test Remediation & Deterministic Testing

Root-cause analysis and architectural strategies for eliminating flaky, non-deterministic test suites in Swift and XCTest.

---

## 1. Common Causes of Test Flakiness
- **Time Dependencies:** Assertions relying on wall-clock time (`Date()`, `Task.sleep`, fixed delays).
- **Shared State & Leaked Singletons:** Tests mutating global singletons without resetting state between runs.
- **Race Conditions:** Asserting state before concurrent background tasks have completed.
- **Filesystem Collisions:** Multiple parallel tests writing to the same fixed temporary directory.

---

## 2. Remediation Strategies
1. **Virtual Time Injection:** Inject a mock clock (`TestClock` or custom time provider) instead of sleeping:
```swift
public protocol ClockProtocol: Sendable {
    func now() -> Date
    func sleep(seconds: TimeInterval) async throws
}
```

2. **Isolated Per-Test Workspaces:** Generate a unique UUID-based directory for every test run:
```swift
func withTemporaryDirectory<T>(perform: (URL) async throws -> T) async throws -> T {
    let tempURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("TestRun-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: tempURL)
    }
    return try await perform(tempURL)
}
```

3. **Explicit State Reset:** Implement `tearDown()` hooks that clear caches, resets registries, and drains pending queues.

---

## 3. Running Stress Testing for Flakes
Use `xcodebuild` with the `-test-iterations` flag to detect intermittent failures:
```bash
xcodebuild test -scheme SwiftCode -test-iterations 10 -run-tests-until-failure
```
