<!-- system-index-depends: Swift6Concurrency.md, MVVMAndStateManagement.md -->
# Memory Leak Detection & Retain Cycle Remediation

Comprehensive guide to identifying, diagnosing, and repairing memory leaks, retain cycles, and abandoned memory in Swift applications.

---

## 1. Root Causes of Memory Leaks in Swift
1. **Strong Reference Cycles in Closures:** Capturing `self` strongly inside long-lived escaping closures, notification observers, or timer blocks.
2. **Delegate Retain Cycles:** Declaring delegate properties as `strong` instead of `weak`.
3. **Task & Actor Capture Cycles:** Long-running unstructured `Task` holding strong references to ViewModels.
4. **Combine Subscription Leaks:** Storing `AnyCancellable` sets on classes where subscribers capture `self` without `[weak self]`.

---

## 2. Capture Lists & Weak References
Always break potential retain cycles using `[weak self]`:

```swift
final class ProcessWatcher {
    private var process: Process?

    func startMonitoring() {
        process?.terminationHandler = { [weak self] proc in
            guard let self else { return }
            self.handleTermination(proc.terminationStatus)
        }
    }

    private func handleTermination(_ status: Int32) {
        // Handle termination
    }
}
```

---

## 3. Automated Deinit Verification Tests
Write automated unit tests verifying that instances deallocate cleanly:

```swift
import Testing

@Suite("Deallocation Verification")
struct MemoryDeallocTests {
    @Test("ViewModel deallocates without retain cycle")
    func verifyViewModelDeinit() async {
        weak var weakRef: ProjectNavigatorViewModel?
        
        do {
            let vm = ProjectNavigatorViewModel()
            weakRef = vm
            vm.performSearch()
        }
        
        #expect(weakRef == nil, "Instance must deallocate immediately when out of scope")
    }
}
```

---

## 4. Assist Diagnostic Checklist
- [ ] Are all delegate protocols declared as `AnyObject` and referenced with `weak`?
- [ ] Are closure capture lists using `[weak self]` in escaping closures?
- [ ] Are timers and observers invalidated on teardown?
