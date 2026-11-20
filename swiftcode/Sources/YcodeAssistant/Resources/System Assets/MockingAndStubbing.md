<!-- system-index-depends: CleanArchitectureSwift.md, UnitTestingBestPractices.md -->
# Mocking, Stubbing & Test Doubles in Swift

Design patterns for authoring clean, compile-safe, and concurrency-compliant test doubles (stubs, spies, fakes, and mocks) in Swift without fragile reflection libraries.

---

## 1. The Test Double Spectrum
- **Dummy:** Passed to satisfy parameter signatures; never invoked.
- **Stub:** Returns preconfigured canned responses without recording call details.
- **Spy:** Records method calls, invocation arguments, and call counts for post-action verification.
- **Fake:** Fully functional in-memory implementation (e.g., in-memory key-value store, mock file coordinator).
- **Mock:** Pre-programmed with expectations on specific call sequences and fails fast on unexpected input.

---

## 2. Protocol-Driven Test Doubles with Concurrency Support
Always model test doubles using Swift protocols conforming to `Sendable`:

```swift
public protocol TerminalExecutionService: Sendable {
    func executeCommand(_ command: String) async throws -> TerminalExecutionResult
}

// Thread-safe Spy Implementation
public actor TerminalExecutionSpy: TerminalExecutionService {
    public private(set) var executedCommands: [String] = []
    public var stubbedResult: TerminalExecutionResult = .init(exitCode: 0, output: "OK")
    public var shouldThrowError: Error?

    public init() {}

    public func executeCommand(_ command: String) async throws -> TerminalExecutionResult {
        executedCommands.append(command)
        if let error = shouldThrowError {
            throw error
        }
        return stubbedResult
    }
}
```

---

## 3. Best Practices
- Prefer Fakes (e.g., in-memory file system) over overly rigid Mocks that assert implementation details.
- Use actors for test spies to ensure safe recording across asynchronous concurrent tasks.
- Keep test doubles in a dedicated `TestSupport` or `Testing` target to prevent test code leaking into production binaries.
