<!-- system-index-depends: Swift6Concurrency.md -->
# Actors, Isolation Domains & Global Actors

Architectural standards for designing actors, preventing actor reentrancy bugs, managing `@MainActor` boundaries, and configuring custom global actors in Swift.

---

## 1. Actor Isolation Model
Actors protect their internal mutable state by ensuring that only one task can execute on their instance at any given time.
- All member access from outside the actor must be asynchronous (`await actorInstance.method()`).
- Value parameters and return values crossing the actor isolation boundary must conform to `Sendable`.

---

## 2. Preventing Actor Reentrancy Bugs
Actor execution is reentrant across suspension points (`await`). When a method suspends, other tasks can execute on the actor and mutate state before the original method resumes.

### Reentrancy Safeguard Pattern:
Validate state assumptions immediately after EVERY suspension point (`await`).

```swift
actor SessionCacheManager {
    private var cachedSessions: [String: SessionData] = [:]
    private var inFlightLoads: Set<String> = []
    
    func session(for id: String) async throws -> SessionData {
        if let cached = cachedSessions[id] {
            return cached
        }
        
        guard !inFlightLoads.contains(id) else {
            return try await awaitExistingLoad(id: id)
        }
        
        inFlightLoads.insert(id)
        defer { inFlightLoads.remove(id) }
        
        let loaded = try await fetchFromNetwork(id: id)
        
        // Re-validate state after suspension point!
        cachedSessions[id] = loaded
        return loaded
    }
}
```

---

## 3. MainActor Guidelines
- `@MainActor` represents the main thread execution context.
- UI components (SwiftUI Views, ViewModels, NSViewController, UIViewController) must be annotated with `@MainActor`.
- Non-UI work (parsing, hashing, compression, heavy regex) must NOT run on `@MainActor`. Offload to standard actors or non-isolated async functions.

---

## 4. Custom Global Actors
For shared background subsystems that require global serialization without blocking the main thread (e.g. database transactions, logging, hardware sync):

```swift
@globalActor
public actor DatabaseActor {
    public static let shared = DatabaseActor()
}

@DatabaseActor
func performDatabaseMigration() async throws {
    // Isolated to DatabaseActor background queue
}
```

---

## 5. Assist Operational Rules
- Inspect all actor methods containing `await` for state invalidation across suspension.
- Never block actor threads with synchronous `sleep()` or semaphore `.wait()`; always use `Task.sleep()`.
