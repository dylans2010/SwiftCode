<!-- system-index-depends: SwiftUsage.md, ActorsAndIsolation.md -->
# Swift 6 Strict Concurrency & Data-Race Safety

Comprehensive reference for adhering to Swift 6 strict concurrency checking, compiler safety invariants, Sendable contracts, and asynchronous dispatch.

---

## 1. Concurrency Safety Model in Swift 6
Swift 6 enforces compile-time verification that memory is never concurrently accessed across execution contexts without synchronization. Complete concurrency checking is enabled via `-strict-concurrency=complete`.

Key Pillars:
1. **Sendable Types:** Types whose values can be safely transferred across concurrency domains.
2. **Actor Isolation:** Dedicated execution contexts that protect their mutable state via mutual exclusion.
3. **Structured Concurrency:** Hierarchical task lifecycles where child tasks are tied to their parent's scope (`async let`, `withTaskGroup`).

---

## 2. Sendable Conformance & Value Types
- Value types (structs, enums, tuples) are implicitly `Sendable` if all stored properties conform to `Sendable`.
- Classes must be `final`, contain only immutable (`let`) `Sendable` properties, or be protected by an internal lock / actor isolation.
- `@unchecked Sendable` must ONLY be used when manual locking (e.g. `os_unfair_lock`, dispatch queue) guarantees thread safety and cannot be proven to the compiler.

```swift
public final class ConfigurationPayload: Sendable {
    public let identifier: String
    public let timestamp: Date
    
    public init(identifier: String, timestamp: Date) {
        self.identifier = identifier
        self.timestamp = timestamp
    }
}
```

---

## 3. Structured Concurrency Patterns
Always prefer structured concurrency over unstructured `Task { }`:
- **Task Groups:** Use `withThrowingTaskGroup(of:returning:)` for bounded parallel fanning out.
- **Async Let:** Use `async let` for parallel evaluation of independent operations with known cardinality.
- **Cancellation Propagation:** Always check `Task.isCancelled` or call `try Task.checkCancellation()` within loops during long-running async routines.

```swift
func fetchAllModules(identifiers: [String]) async throws -> [ModuleData] {
    try await withThrowingTaskGroup(of: ModuleData.self) { group in
        for id in identifiers {
            group.addTask {
                try Task.checkCancellation()
                return try await loadModule(id: id)
            }
        }
        var results: [ModuleData] = []
        for try await module in group {
            results.append(module)
        }
        return results
    }
}
```

---

## 4. Common Concurrency Warnings & Fixes
- **Capturing non-sendable value in @Sendable closure:** Pass immutable copies or wrap the value in a Sendable container.
- **Passing mutable state across isolation domains:** Isolate mutation to an actor, or copy value types across boundaries.
- **Global mutable variable access:** Annotate global state with `@MainActor` or encapsulate within an actor.

---

## 5. Assist Operational Rules
- Never suppress concurrency warnings with arbitrary `@unchecked Sendable` without architectural necessity.
- Ensure all UI-bound completion handlers and observable state mutations are decorated with `@MainActor`.
- Verify graceful cooperative cancellation on all network, disk, and agent streaming loops.
