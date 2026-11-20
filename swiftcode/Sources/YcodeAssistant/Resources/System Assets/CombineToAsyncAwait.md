<!-- system-index-depends: Swift6Concurrency.md, MVVMAndStateManagement.md -->
# Migration from Combine to Async/Await & AsyncSequence

Actionable patterns and strategies for refactoring legacy Combine pipelines, `AnyCancellable` stores, and `@Published` publishers to native Swift async/await and AsyncSequence.

---

## 1. Paradigm Mapping
| Combine Primitive | Modern Swift Concurrency Equivalent |
|---|---|
| `Future<Output, Failure>` | `async throws -> Output` |
| `AnyPublisher<Element, Never>` | `AsyncStream<Element>` |
| `AnyPublisher<Element, Error>` | `AsyncThrowingStream<Element, Error>` |
| `Set<AnyCancellable>` | `Task<Void, Never>` cancellation handle |
| `@Published var value` | `@Observable` stored property |
| `.sink { value in }` | `for await value in stream { }` |
| `.debounce(for:scheduler:)` | Async sleep loop or AsyncSequence debouncing |

---

## 2. Bridging Delegate Callbacks with AsyncStream
Replace callback-based or Combine-based notification hooks using `AsyncStream`:

```swift
// Modern AsyncStream Bridge
func monitorFileSystemEvents(at path: String) -> AsyncStream<FileSystemEvent> {
    AsyncStream { continuation in
        let monitor = InternalFileMonitor(path: path) { event in
            continuation.yield(event)
        }
        monitor.start()
        
        continuation.onTermination = { _ in
            monitor.stop()
        }
    }
}

// Consumption via for-await loop
Task {
    for await event in monitorFileSystemEvents(at: workspaceRoot) {
        handleFileChange(event)
    }
}
```

---

## 3. Retiring AnyCancellable in ViewModels
Replace `var cancellables = Set<AnyCancellable>()` with managed `Task` instances that cancel on deinit or view dismissal:

```swift
@Observable
@MainActor
final class SearchEngineViewModel {
    private var activeSearchTask: Task<Void, Never>?
    var results: [SearchResult] = []
    
    func queryDidChange(_ query: String) {
        activeSearchTask?.cancel()
        activeSearchTask = Task {
            try? await Task.sleep(nanoseconds: 200_000_000) // 200ms debounce
            guard !Task.isCancelled else { return }
            self.results = await searchDatabase(query: query)
        }
    }
    
    deinit {
        activeSearchTask?.cancel()
    }
}
```

---

## 4. Assist Verification Checklist
- [ ] Are all `import Combine` imports audited for replacement with structured concurrency?
- [ ] Are publishers wrapped in `AsyncStream` or `AsyncThrowingStream`?
- [ ] Are task lifecycles cooperatively cancelled without leaking background threads?
