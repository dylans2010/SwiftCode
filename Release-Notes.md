# SwiftCode Release Notes

Public releases, `.dmg` builds, and issue tracking live on [github.com/dylans2010/SwiftCode](https://github.com/dylans2010/SwiftCode).  
The internal codebase lives on [github.com/dylans2010/SwiftCode-Internal](https://github.com/dylans2010/SwiftCode-Internal).

---

## Highlights

This release focuses on **Liquid Glass UI modernization**, a **full-featured Markdown editor** (with Source, Split, and Reading modes, native tables, image/link popovers, and a DOM bridge), **StoreKit JWS signing verification**, and **macOS/SwiftPM build and layout stability fixes**.

---

## New Features

### Markdown Editor
- **Editing Modes & Smart Typing:** Added Source, Split, and Reading modes alongside a smart-typing engine, trailing-newline preservation, and dedicated Markdown settings keys in Settings.
- **Native Tables:** Added table management, a native grid editor, an insert-table popover, a contextual table toolbar, and an **Editor ▸ Delete Table** app-menu command wired through the responder chain.
- **Images & Links:** Added native image and link popovers with link validation and proper popover anchoring, replacing legacy `JS prompt()` dialogs.
- **Rich Rendering & Slash Commands:** Added a DOM bridge (replacing 20 of 22 `execCommand` calls), a glass formatting toolbar, 19 slash commands, a floating selection toolbar, and deterministic Notes block IDs.

### StoreKit
- **JWS Verification:** Wired `StoreKitSigningJWSVerifier` as the server model's default verifier and registered it in the Xcode project.

---

## App Improvements

### Liquid Glass UI Modernization
- **Design System & Shared Components:** Introduced Liquid Glass design-system tokens, unified StoreKit button styling, `BuildBezel`, and shared components (removing `SharedErrorState`).
- **Accessibility & Contrast:** Centralized Reduce Transparency handling and fixed Light-mode readability issues across diff views, conflict resolvers, dev-tool hubs, inspectors, and `LocalBuildDemoView`.
- **Application-Wide Chrome:** Updated primary editor chrome (`JumpBar`, `CodeReviewBar`, diff badges, minimap separator), navigators, sidebars, inspectors, settings cards, welcome/onboarding screens, terminal/console chrome, Git/Spaces, SDK Studio/UI Builder/Preview, Decompiler, Extensions, Cloud/Accounts/Collaboration, Assist, and secondary micro-surfaces (merge sheets/alerts, debug filter pills, new-item sheets).
- **Assist & Onboarding:** Removed raw model IDs from the Assist model picker, removed the fake fallback plan, and added keyboard navigation and missing-project recovery to Welcome/Onboarding.

---

## Bug Fixes

- **Window, Sidebar & Layout Bounds:** Fixed Bookmarks sidebar sizing, editor/navigator overlaps, and window/fullscreen bounds clamping.
- **Build & Compilation:**
  - Fixed Release `xcodebuild` errors across `YcodeAssistant`, `YcodeIDECore`, and `YcodeUI`.
  - Fixed `ycode-ide` SwiftPM baseline build.
  - Repaired test-target compilation so Markdown test suites compile and reduced StoreKit bitrot.
  - Registered 12 new source files in `.xcodeproj`.
- **Markdown & UI Polish:** Fixed `JS prompt()` defect for links/images, fixed Light-mode dark-background regressions in dev tools and conflict resolvers, and fixed Extensions UI typo.
