<!-- system-index-depends: FileOperations.md -->
# File Coordination (NSFileCoordinator) & Cross-Process Locking

Techniques for atomic file writing, avoiding file race conditions, and synchronizing file access across multiple processes on macOS.

---

## 1. Why `NSFileCoordinator`?
When multiple tools, IDE editors, or background processes access the same file simultaneously:
- Standard POSIX file writes can corrupt data or produce torn reads.
- `NSFileCoordinator` coordinates operations with other processes and the operating system (Finder, iCloud).

---

## 2. Atomic Writing with Coordination
```swift
import Foundation

public final class AtomicFileWriter: Sendable {
    public static func write(content: Data, to url: URL) throws {
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        var writeError: Error?

        coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError) { writeURL in
            do {
                try content.write(to: writeURL, options: [.atomic])
            } catch {
                writeError = error
            }
        }

        if let error = coordinationError ?? writeError {
            throw error
        }
    }
}
```
