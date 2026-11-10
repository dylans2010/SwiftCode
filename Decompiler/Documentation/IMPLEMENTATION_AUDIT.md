# YcodeDecompiler — Implementation Audit

Audit of the YcodeDecompiler module (`swiftcode/Sources/YcodeDecompiler`,
89 Swift files + resources) and its integration surface in the
production SwiftCode application; this documentation lives under
`Decompiler/Documentation/`. All paths below are relative to the repo
root; the module compiles as the `YcodeDecompiler` target of the `swiftcode`
SwiftPM package (`swiftcode/Package.swift`) and as a static library in the
XcodeGen project (`project.yml`).

## 1. What exists (89 Swift files + resources)

| Area | Files | Status |
|---|---|---|
| Core model | `Core/` — `BinaryFormat`, `BinaryImage`, `DecompilerAddress`, `Function`, `Instruction`, `Symbols`, `DecompilerSupport` | Implemented |
| Session/state | `Core/AnalysisStore`, `DecompilerSession`, `DecompilerSessionManager`, `AnalysisCoordinator` | Implemented |
| Format parsers | `Formats/MachO/MachOParser.swift` (724 ln), `Formats/ELF/ELFBinaryParser.swift` (478 ln), `Formats/PE/PEBinaryParser.swift` (375 ln), `Formats/Common/FormatSupport.swift` (`ByteCursor`, endian-aware reads, ULEB128, `readFileRegion`, `fileSize`) | Implemented — thin+fat Mach-O, ELF32/64 LE/BE, PE32/PE32+ |
| Binary I/O | `Binary/BinaryDetector.swift`, `BinaryLoader.swift` | Implemented |
| Built-in analysis | `Analysis/FunctionDiscovery`, `StringAnalysis`, `CrossReferences`, `TypeRecovery` | Implemented, wired into coordinator |
| Extended analysis | `Analysis/ControlFlow` (CFG + call graph), `DataFlow` (backend-seam only), `DebugInformation`, `DependencyAnalysis`, `ExportAnalysis`, `ImportAnalysis`, `SymbolAnalysis` | Implemented as libraries; **not yet invoked by `AnalysisCoordinator` or UI commands** |
| Canonical IR | `IntermediateRepresentation/` — `IRModule`, `IRFunction`, `IRInstruction`, `IRBasicBlock` + `IRModule.from(instructions:functions:)` converter | Implemented; not yet consumed by backends/passes |
| Disassembly engine | `Disassembly/Backends/ObjDumpDisassembler.swift`, `Disassembly/DisassemblerProvider.swift` | Implemented (llvm-objdump) |
| Decompilation engine | `Decompilation/Backends/GhidraDecompiler.swift`, `Decompilation/DecompilerRegistry.swift`, `Resources/EngineScripts/DecompileDump.py` | Implemented (Ghidra headless, optional install) |
| Engine plumbing | `Engines/EngineProtocols`, `EngineRegistry(+Resolution)`, `EngineBootstrap` | Implemented; `EngineBootstrap.installDefaults()` registers both engines |
| Persistence | `Storage/ProjectManifest`, `DecompilerProjectManager`, `AnalysisPersistence` (SQLite via `CSQLite` + JSON fallback), `CacheManager` (content-addressed cache), `DecompilerDatabase` (schema/migration doc) | Implemented; `CacheManager` not yet instantiated by sessions |
| Security | `Security/` — `BinarySecurityPolicy`, `AnalysisSandbox`, `ResourceLimits`, `InputValidation`, `PermissionPolicy`, `TemporaryFilePolicy` | Implemented |
| Symbol demangling | `Symbols/SymbolDemangler.swift` (`xcrun swift-demangle`, `c++filt`, Mach-O `_` strip) | Implemented; used by `SymbolTools` |
| Configuration | `Configuration/` — `DecompilerConfiguration`, `EngineConfiguration`, `AnalysisPreferences`, `WorkspacePreferences` (UserDefaults suite `com.swiftcode.decompiler`) | Implemented as persisted types; **not yet consumed** by sessions/engines |
| UI | `App/` (window manager/controller/commands/lifecycle), `Interface/Shared` (`DecompilerObservableState`), `Interface/Friendly`, `Interface/Master` | Implemented (SwiftUI + AppKit) |
| Exports | `Export/` — report (Markdown), assembly listing, graph JSON, project-bundle copy, pseudocode text, symbol CSV/JSON | Implemented as libraries; `exportAnalysis` command currently writes its own text summary, exporters not yet wired to UI |
| Decompile Assist | `AI/DecompileAssist/` — asset loader, configuration, identity, provider policy, context builder, session, tool registry + 7 tool files (~40 tools), 17 system-asset `.md` files | Implemented |

## 2. Production integration points

- **Menu command.** `swiftcode/Sources/YcodeUI/App/AppCommands.swift`
  routes `openDecompiler:` → `DecompilerWindowManager.shared.showWindow()`.
- **Lifecycle.** `App/DecompilerLifecycle.swift` provides
  `installDefaultEngines()` (calls `EngineRegistry.installDefaults()` +
  `EngineBootstrap.installDefaults()`) and `setAssistPanel(_:)` to inject
  the Decompile Assist panel into every window state. **Neither is called
  from `YcodeApp`/`YcodeUI` yet** — engine registration and assist-panel
  injection are opt-in hooks awaiting app-startup wiring.
- **Package wiring.** `swiftcode/Package.swift`: library product
  `YcodeDecompiler`; target deps `YcodeAssistant` + `YcodeSubprocess`;
  `.copy("Resources")`; test target `YcodeDecompilerTests` →
  `swiftcode/Tests/YcodeDecompilerTests`.
- **XcodeGen.** `project.yml`: `YcodeDecompiler` static-library target
  (sources exclude `Resources/**`; deps `YcodeAssistant`, `YcodeSubprocess`);
  `swiftcode/Sources/YcodeDecompiler/Resources` added to the `SwiftCode`
  app target's resources phase; `SwiftCode` app and `swiftcode-cli` depend
  on the target.
- **Assistant integration.** `DecompileAssistProviderPolicy` resolves a
  `GoogleCloudSDKConfiguration` via `YcodeAssistant` services
  (`GoogleAccountAuthService`, `AssistModelRouter`, `APIKeyManager`,
  `AntigravitySDKModelFetcher`), pinned to Antigravity/Gemini
  (`gemini-*` models; `executionMode` `antigravity` or `api_key`).
  `DecompileAssistSession` multiplexes on the shared
  `GoogleCloudSDKRuntime` with `decompile-assist-`-prefixed session ids.

## 3. Reusable components chosen

| Need | Reused component | Where |
|---|---|---|
| Engine subprocesses | `YcodeSubprocess` — `Subprocess.run`, `StreamingSubprocess.lines`, `/usr/bin/env java -version` probe | `swiftcode/Sources/YcodeSubprocess/` |
| AI provider | `YcodeAssistant` — `GoogleCloudSDKRuntime`, `GoogleCloudSDKConfiguration`, auth/key services, SDK event stream | `swiftcode/Sources/YcodeAssistant/` |
| SQLite | system `libsqlite3` via `CSQLite` systemLibrary | `swiftcode/Sources/CSQLite/` |
| Window-shell pattern | `SourceControlWindowManager`-style singleton window ownership | `swiftcode/Sources/YcodeUI/SourceControl/` |
| Symbol demangling | `xcrun swift-demangle`, `c++filt` | `Symbols/SymbolDemangler.swift` |

## 4. Missing / unwired capabilities (honest list)

- `DecompilerLifecycle.installDefaultEngines()` / `setAssistPanel(_:)`
  exist but are not invoked by the app entry point, so engines register
  only if something calls them (or a session resolves providers another
  way — `EngineRegistry.shared` starts empty).
- Extended analysis passes (`ControlFlowAnalyzer`, `CallGraphAnalyzer`,
  `DebugInformationAnalysis`, `DependencyAnalysis`, `ExportAnalysis`,
  `ImportExportAnalysis`, `SymbolAnalysis`), the canonical IR, the six
  `Export/` exporters and `Storage/CacheManager` are implemented but not
  yet called by `AnalysisCoordinator`, `DecompilerCommands` or the views.
- `Configuration/*` preference types persist to UserDefaults but nothing
  reads them back into `AnalysisConfiguration`/engine settings yet.
- `DataFlowAnalyzer` is intentionally a seam only (`isBackendProvidedOnly()`
  returns true) — real data-flow comes from the decompiler backend.
- No XcodeGen test target for `YcodeDecompilerTests` (SwiftPM only).
- `.scdecomp` is not yet a declared document type in `Info.plist`/`project.yml`.

## 5. Build constraints

- Swift 6, macOS 15.0 deployment target.
- Dual build: SwiftPM (`CSQLite` available → SQLite persistence,
  `Bundle.module` resources) and XcodeGen app target (no `CSQLite` →
  `Analysis.json` fallback; resources via `Bundle.main`). Both paths are
  handled with `#if canImport` and multi-location resource lookup.
- Parsers cap inputs (`ELF/PE` 2 GiB, Mach-O slice 2 GiB,
  ≤4096 sections/segments); engines are bounded by
  `AnalysisSandbox`/`AnalysisSecurityPolicy`.
- No new external Swift package dependencies.

## Evidence

| Claim | Level |
|---|---|
| File inventory, APIs, wiring, unwired items | 1 — direct source inspection |
| Intended behaviour of llvm-objdump/Ghidra backends | 1 — implementations exist and were read |
| App-startup wiring gaps | 1 — grep shows no call sites in `swiftcode/Sources` |
