<!-- system-index-depends: SwiftUIArchitecture.md -->
# Localization with String Catalogs (.xcstrings)

Technical reference for modern Apple platform localization using String Catalogs (`.xcstrings`), compiler-extracted keys, and pluralization.

---

## 1. The Modern String Catalog (.xcstrings)
Xcode 15+ deprecates legacy `.strings` and `.stringsdict` files in favor of unified, compiler-validated JSON-based `.xcstrings` catalogs.

### Key Benefits:
- Automatic string extraction from SwiftUI `Text("Key")` and `String(localized: "Key")`.
- Real-time translation progress tracking directly inside Xcode.
- Integrated pluralization rules and device-specific variations.

---

## 2. Authoring Localizable Code
In SwiftUI:
```swift
// Implicitly extracted as LocalizedStringKey
Text("project.navigator.title")

// Interpolated strings with pluralization rules
Text("files.count \(fileCount)")
```

In pure Swift:
```swift
let message = String(localized: "build.status.success", defaultValue: "Build completed successfully.")
```

---

## 3. Assist Operational Rules
- Never hand-code ad-hoc string replacement routines when `.xcstrings` is available.
- Validate that all user-facing strings are wrapped in localization primitives.
- Verify that format specifiers (e.g. `%@`, `%d`) match across all translated locales.
