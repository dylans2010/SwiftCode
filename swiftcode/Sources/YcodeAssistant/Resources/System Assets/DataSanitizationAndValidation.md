<!-- system-index-depends: Safeguards.md -->
# Data Sanitization, Path Traversal Defense & Input Validation

Defense-in-depth guidelines for sanitizing user inputs, preventing path traversal attacks, and validating untrusted external data.

---

## 1. Path Traversal Prevention
Never construct file URLs by directly concatenating raw user strings with a base directory:
- Reject any path containing `..` or leading `/`.
- Canonicalize paths using `resolvingSymlinksInPath()`.
- Validate that the canonical path strictly starts with the workspace root:

```swift
public func validateSafeWorkspacePath(_ relativePath: String, workspaceRoot: URL) throws -> URL {
    if relativePath.contains("..") {
        throw SecurityError.pathTraversalAttempt
    }
    let targetURL = workspaceRoot.appendingPathComponent(relativePath).standardizedFileURL
    let rootPath = workspaceRoot.standardizedFileURL.path
    guard targetURL.path.hasPrefix(rootPath) else {
        throw SecurityError.outOfBoundsPath
    }
    return targetURL
}
```

---

## 2. String & Terminal Command Sanitization
- When spawning child processes, pass arguments as discrete argv elements (`[String]`), never formatted shell strings (`"sh -c \"...\""`).
- Reject command injection payloads containing `;`, `&&`, `||`, `|`, or backticks.
