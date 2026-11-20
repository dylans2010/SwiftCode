<!-- system-index-depends: Safeguards.md, CodeSigningAndNotarization.md -->
# macOS App Sandbox Security Architecture & Entitlements

Security architecture, isolation boundaries, and entitlement configurations for sandboxed macOS applications.

---

## 1. App Sandbox Security Boundary
The macOS App Sandbox confines an application to its dedicated container directory (`~/Library/Containers/<BundleID>/Data/`), restricting access to the user's filesystem, network, hardware, and inter-process communication.

### Container Layout:
- `Data/Documents`: Sandboxed user documents.
- `Data/Library/Application Support`: App-private persistent storage.
- `Data/Library/Caches`: Disposable cache directories.

---

## 2. Powerbox & Security-Scoped Bookmarks
To access files outside the sandbox container (such as user-selected project workspaces):
1. **Powerbox Open Panel:** Present `NSOpenPanel`. User selection implicitly grants temporary sandbox access.
2. **Security-Scoped Bookmarks:** Persist file access permissions across application restarts by generating security-scoped bookmark data:

```swift
// Creating a security-scoped bookmark
func persistWorkspaceAccess(url: URL) throws -> Data {
    try url.bookmarkData(
        options: .withSecurityScope,
        includingResourceValuesForKeys: nil,
        relativeTo: nil
    )
}

// Resolving a security-scoped bookmark
func accessWorkspace(bookmarkData: Data) throws -> URL {
    var isStale = false
    let url = try URL(
        resolvingBookmarkData: bookmarkData,
        options: .withSecurityScope,
        relativeTo: nil,
        bookmarkDataIsStale: &isStale
    )
    guard url.startAccessingSecurityScopedResource() else {
        throw SecurityError.accessDenied
    }
    return url
}
```

---

## 3. Assist Operational Rules
- Always call `url.stopAccessingSecurityScopedResource()` when finished with a security-scoped URL.
- Never hardcode absolute host paths outside the sandbox.
