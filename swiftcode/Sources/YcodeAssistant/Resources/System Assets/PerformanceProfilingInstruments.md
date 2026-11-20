<!-- system-index-depends: BuildAndTesting.md -->
# Performance Profiling with Xcode Instruments & Signposts

Methodology for measuring CPU utilization, memory allocations, UI hang rate, and thermal throttling using Xcode Instruments and `os_signpost`.

---

## 1. Key Xcode Instruments
- **Time Profiler:** Identifies high-CPU call trees, thread starvation, and synchronization bottlenecks.
- **Allocations:** Tracks heap allocations, peak memory footprint, and anonymous VM allocations.
- **Leaks:** Identifies unreferenced memory allocations and retain cycles.
- **Swift Concurrency:** Visualizes Task lifecycles, actor contention, task queues, and continuation delays.
- **App Launch:** Measures pre-main dyld linking overhead and initial window draw latency.

---

## 2. Instrumenting Code with `OSSignpost`
Use the unified logging system to inject custom performance markers visible directly in Time Profiler:

```swift
import os

private let poiLogger = Logger(subsystem: "com.swiftcode.app", category: .pointsOfInterest)

func indexWorkspaceDirectory(path: String) async {
    let signpostID = OSSignpostID(log: poiLogger)
    os_signpost(.begin, log: poiLogger, name: "WorkspaceIndexing", signpostID: signpostID, "Root: %{public}@", path)
    defer {
        os_signpost(.end, log: poiLogger, name: "WorkspaceIndexing", signpostID: signpostID)
    }

    // Heavy indexing logic
}
```

---

## 3. Diagnostic Rules for Assist
- Profile in Release configuration (`-c release`) with optimizations enabled (`-O`).
- Eliminate synchronous file I/O or JSON decoding on the main thread.
- Ensure all long-running loops yield periodically or check cancellation.
