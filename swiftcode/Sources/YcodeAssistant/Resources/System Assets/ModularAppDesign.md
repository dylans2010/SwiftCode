<!-- system-index-depends: CleanArchitectureSwift.md, SPMConfigurationDeepDive.md -->
# Modular App Design & Local Package Architecture

Guidelines for decomposing monolithic Apple platform applications into decoupled, modular Swift Package Manager (SPM) libraries and local feature modules.

---

## 1. Benefits of Modular Architecture
- **Compile Time Optimization:** Clean module boundaries allow SPM and xcodebuild to build independent modules in parallel and maximize cache reuse.
- **Strict Boundary Enforcement:** Internal types within a feature module are inaccessible to other modules unless explicitly declared `public` or `package`.
- **Targeted Unit Testing:** Unit tests link only to the module under test, drastically reducing test build overhead.

---

## 2. Recommended Module Taxonomy
1. **Core / Foundation Modules:** Foundational primitives, logging, extensions, cryptography. Zero feature dependencies.
2. **Domain Modules:** Entities, repository protocols, use cases. Depend only on Core.
3. **Infrastructure Modules:** Concrete database implementations (SwiftData/SQLite), network clients. Depend on Domain protocols.
4. **Feature Modules:** Individual user-facing screens and workflows. Depend on Domain and UI primitives.
5. **App Shell Module:** Target containing the `@main` entrypoint, scene configuration, and top-level dependency wiring.

```
+-----------------------------------------------------------+
|                        App Shell                          |
+-----------------------------+-----------------------------+
                              |
       +----------------------+----------------------+
       |                                             |
       v                                             v
+--------------+                              +--------------+
| Feature: Auth|                              |Feature:Editor|
+------+-------+                              +------+-------+
       |                                             |
       +----------------------+----------------------+
                              |
                              v
+-----------------------------------------------------------+
|                       Domain Layer                        |
|             (Entities, Protocols, Use Cases)              |
+-----------------------------+-----------------------------+
                              |
                              v
+-----------------------------------------------------------+
|                     Core & Utilities                      |
+-----------------------------------------------------------+
```

---

## 3. Access Control Strategy: `package` Visibility
Swift 5.9 introduces `package` access level:
- Allows symbols to be shared across targets in the same Swift package without making them `public` to external clients.
- Use `package` for inter-module integration contracts within local SPM packages.

---

## 4. Assist Verification Checklist
- [ ] Does every feature module have its own standalone test target?
- [ ] Are cyclic module dependencies completely eliminated?
- [ ] Is interface separated from implementation using protocols in shared domain targets?
