<!-- system-index-depends: SwiftUsage.md -->
# Swift Macro Development & SwiftSyntax Integration

Architecture and design guidelines for authoring freestanding and attached Swift macros using `SwiftSyntax`.

---

## 1. Macro Categories
- **Freestanding Macros:** Expression (`#stringify(...)`) or Declaration (`#warning(...)`).
- **Attached Macros:** Peer, Member, MemberAttribute, Extension, and Accessor macros (e.g. `@Observable`, `@Model`).

---

## 2. Best Practices
- Keep macro implementations purely functional and deterministic without filesystem or network access.
- Write thorough unit tests using `assertMacroExpansion` from `SwiftSyntaxMacrosTestSupport`.
