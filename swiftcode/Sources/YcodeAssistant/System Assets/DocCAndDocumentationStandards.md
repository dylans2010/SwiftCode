<!-- system-index-depends: DocumentationWithGitHub.md -->
# DocC Documentation Standards & Symbol Catalogs

Standards for writing structured Swift DocC comments, markdown documentation catalogs, and tutorial tables.

---

## 1. DocC Symbol Comments
Use triple-slash `///` comments with Markdown formatting and structured callouts:
```swift
/// Compiles the specified Xcode target and collects diagnostic outputs.
///
/// - Parameters:
///   - targetName: The name of the target inside the active workspace.
///   - configuration: Build configuration (Debug or Release).
/// - Returns: A ``BuildResult`` containing exit code, duration, and parsed compiler diagnostics.
/// - Throws: ``BuildExecutionError`` if xcodebuild cannot be spawned.
public func compileTarget(_ targetName: String, configuration: BuildConfiguration) async throws -> BuildResult
```
