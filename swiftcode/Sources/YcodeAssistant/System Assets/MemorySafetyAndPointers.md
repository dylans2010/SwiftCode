<!-- system-index-depends: SwiftUsage.md -->
# Memory Safety, Unsafe Pointers & Undefined Behavior Prevention

Best practices for interacting with C APIs, raw memory buffers (`UnsafeBufferPointer`), and avoiding memory corruption in Swift.

---

## 1. Safe vs Unsafe Pointer Hierarchy
- Prefer safe Swift collections (`[UInt8]`, `Data`) over raw memory pointers.
- When interfacing with POSIX or C libraries, scope pointer lifetimes using `withUnsafeBytes` and `withUnsafeBufferPointer`.
- Never return an unsafe pointer outside the closure block of a `withUnsafe...` method.
