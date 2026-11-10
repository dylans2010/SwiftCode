# YcodeDecompiler — Dependencies

No new external Swift package dependencies were added. Dependencies are
in-repo targets, Apple system frameworks/libraries, or optional
user-installed tools resolved at run time.

| Dependency | Version / source | License | Purpose | Integration | Packaging |
|---|---|---|---|---|---|
| `YcodeAssistant` | in-repo (`swiftcode/Sources/YcodeAssistant`) | project-internal | Decompile Assist: `GoogleCloudSDKRuntime`/`GoogleCloudSDKConfiguration`/`GoogleCloudSDKSession`, `GoogleAccountAuthService`, `AssistModelRouter`, `APIKeyManager`, `AntigravitySDKModelFetcher`, SDK event stream | SwiftPM + XcodeGen target dependency | linked into app |
| `YcodeSubprocess` | in-repo (`swiftcode/Sources/YcodeSubprocess`) | project-internal | Engine processes: `Subprocess.run` (objdump version probe, demangler tools use `Process` directly), `StreamingSubprocess.lines` (analyzeHeadless), `MainThreadGuard` | SwiftPM + XcodeGen target dependency | linked into app |
| `CSQLite` → system `sqlite3` | system library (`module.modulemap` links `sqlite3`) | SQLite public domain | `.scdecomp` `Analysis.sqlite` persistence | `#if canImport(CSQLite)` — SwiftPM only | system library |
| `llvm-objdump` | Xcode toolchain / PATH | Apache-2.0 w/ LLVM exceptions | `ObjDumpDisassembler` disassembly backend | `SWIFTCODE_LLVM_OBJDUMP` env → `xcrun -f` → `which`/PATH; `ToolCache` | not bundled |
| Ghidra (`support/analyzeHeadless`) | user-installed, optional | Apache-2.0 | `GhidraDecompiler` pseudocode backend + `DecompileDump.py` Jython bridge | `SWIFTCODE_GHIDRA_HOME` → `GHIDRA_INSTALL_DIR` → bundle dirs → `ghidra*` scan of `~`, `/opt`, `/usr/local`, `/Applications`; requires Java 21+ on PATH | not bundled; `DecompileDump.py` ships as a bundle resource |
| `xcrun swift-demangle`, `c++filt` | Xcode toolchain / system | toolchain/system | `SymbolDemangler` | run-time `Process` invocation, short timeout, graceful fallback | not bundled |
| SwiftUI / AppKit / Observation | Apple SDK | Apple SDK license | Workspace UI (`Interface/`, `App/`), `@Observable` state | `import SwiftUI`, `AppKit` | system frameworks |
| Foundation / CryptoKit / UniformTypeIdentifiers | Apple SDK / Swift | — | File I/O, JSON, SHA-256, open/save panels | imports | system |

## Notes

- **Dual build divergence is intentional.** `CSQLite` exists only in the
  SwiftPM graph, so `AnalysisPersistence` uses SQLite under
  `#if canImport(CSQLite)` and an `Analysis.json` snapshot otherwise
  (XcodeGen app build). Same logical data either way.
- **`Bundle.module` is SwiftPM-only.** Asset/script lookup therefore
  probes `Bundle.module`, then `Bundle.main` (both flat and
  `Decompiler/`-prefixed subpaths), then a `#filePath`-relative source
  fallback — covering SwiftPM, XcodeGen app resources, and unbundled dev
  trees.
- **Bundled resource**: `Resources/EngineScripts/DecompileDump.py` (the
  Ghidra bridge script) ships via `.copy("Resources")` in SwiftPM and the
  `SwiftCode` app target's resources phase in `project.yml`.
- **Licensing**: Ghidra (Apache-2.0) and llvm-objdump are *not* vendored —
  they run from the user's own installations. No copyleft or proprietary
  binaries ship with SwiftCode.

## Evidence

| Claim | Level |
|---|---|
| Dependency list, licenses, integration, packaging | 1 — `Package.swift`, `project.yml`, `module.modulemap`, source imports, backend discovery code |
| "No new external package dependencies" | 1 — target deps are only `YcodeAssistant` + `YcodeSubprocess` |
