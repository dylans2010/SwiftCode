<!-- system-index-depends: BuildAndTesting.md, Swift6Concurrency.md -->
# Unit Testing Best Practices & Swift Testing Suite

Comprehensive engineering standards for authoring fast, deterministic, and maintainable unit tests using both the modern Swift Testing framework (`import Testing`) and `XCTest`.

---

## 1. Modern Swift Testing (`package:swift-testing`)
Swift Testing provides declarative, expressive macro-based testing natively integrated into Swift 6.

### Key Primitives:
- `@Suite`: Declares a test suite struct or actor grouping related tests.
- `@Test`: Declares an asynchronous or synchronous test function.
- `#expect(...)`: Non-terminating expectation macro. Inspects expression syntax on failure.
- `#require(...)`: Terminating assertion macro that unwraps optionals or halts test execution on failure.
- `@Test(arguments: ...)`: Native parameterized testing across input datasets.

```swift
import Testing
@testable import YcodeAssistant

@Suite("Tool Registry Verification")
struct ToolRegistryTests {
    let registry = AssistToolRegistry.shared

    @Test("Verify essential tools are registered")
    func verifyCoreTools() async throws {
        let tools = await MainActor.run { registry.allTools }
        #expect(!tools.isEmpty, "Registry must contain registered tools")
        
        let fileRead = await MainActor.run { registry.getTool("file_read") }
        let tool = try #require(fileRead, "file_read tool must be registered")
        #expect(tool.id == "file_read")
    }

    @Test("Parameterized alias resolution", arguments: [
        ("read_file", "file_read"),
        ("write_file", "file_write"),
        ("git", "version_control_operator")
    ])
    func verifyAliases(alias: String, expectedID: String) async throws {
        let resolved = await MainActor.run { registry.getTool(alias) }
        let tool = try #require(resolved)
        #expect(tool.id == expectedID)
    }
}
```

---

## 2. Test Structuring: Arrange-Act-Assert (AAA)
Every test should strictly follow the AAA pattern with clear separation:
1. **Arrange:** Set up test dependencies, in-memory repositories, and mock data.
2. **Act:** Execute the specific method under test.
3. **Assert:** Validate output values, side effects, and state invariants using `#expect` or `XCTAssertEqual`.

---

## 3. Testing Asynchronous & Actor-Isolated Code
- Write test functions as `async` without callback closures or expectation polling.
- Ensure actor-isolated state is awaited cleanly.
- Never use `sleep()` to wait for asynchronous side effects; use custom test clocks or deterministic event streams.

---

## 4. Test Suite Hygiene & Speed
- **Fast Execution:** Individual unit tests must execute in under 100 milliseconds.
- **Hermetic Isolation:** Never depend on external network services, shared disk caches, or execution order.
- **Clean Teardown:** Tear down temporary file paths using `FileManager` in defer blocks or suite deinitializers.
