# YcodeDecompiler — Limitations

An honest accounting of what the module does **not** do, quality ceilings,
and integration gaps. Verified against current sources.

## Format parsing

- **No DWARF/PDB contents** — only presence is reported
  (`hasDebugInfo`, `dwarfSections`, PDB path note). Type/line recovery is
  delegated to the decompiler backend; `TypeRecovery.recover` returns `[]`
  by design.
- **No Objective-C/Swift runtime metadata** — classes, selectors,
  protocols, Swift reflection sections are not decoded (string sections
  are only *marked* `containsStrings`).
- **No relocations** — pointers in data are not rebased.
- **No code-signature superblob parsing** — `isSigned`/notes only.
- **PE**: no `.rsrc` (version info/icons), TLS callbacks, delay-load
  imports, .NET/CLI metadata, bound imports.
- **ELF**: no notes beyond build-id, no `.gnu_debuglink`, no
  `SHF_COMPRESSED`/`ELFCOMPRESS` decompression, no split-DWARF.
- **Mach-O**: no chained-fixup *resolution* (only noted), no
  `LC_DYSYMTAB` indirect-symbol resolution, no Objective-C opt pointers.
- Archives (`.a`/`.lib`), scripts, JVM/.NET binaries: not detected.
- ELF `strings`/`functionStarts` left empty — string extraction is the
  separate `StringAnalysis` pass (which runs only when a disassembler-less
  path still executes it — see pipeline note below).

## Disassembly (llvm-objdump backend)

- **Linear sweep only** (`-D` per section): no recursive descent, no
  function-aware skip — inline data/jump tables can decode as
  instructions; undecodable bytes → `.byte`/`(bad)` → `.invalid`.
- **No structured operands** — operand text is `.other(...)`; branch
  targets are best-effort text extraction.
- Requires an `llvm-objdump` on the system (Xcode toolchain, PATH, or
  `SWIFTCODE_LLVM_OBJDUMP`); none is bundled.
- Per-section extraction means cross-section flows are not disassembled
  as one stream.

## Decompilation (Ghidra backend)

- Requires a user-installed Ghidra + Java 21+; not bundled.
- **Project cache keyed by FNV-1a of `imagePath`, not content hash** —
  same bytes at a new path re-import; changed bytes at the same path can
  serve stale analysis until the 7-day prune.
- Per-function `-process` invocations; no whole-program dump-all mode.
- Fat Mach-O handled by an all-programs retry relying on the script's
  address filter — not guaranteed.
- Output is unverified machine-generated pseudocode
  (`provenance = .engine`, `rawBackendOutput` retained ≤1 MiB).
- `pcode` capability is not advertised even though Ghidra computes it
  internally.

## Analysis quality

- `AnalysisCoordinator` still runs only the original pipeline:
  symbols → `FunctionDiscovery` → strings → disassembly → xrefs →
  refine → types → persist. The extended passes
  (`ControlFlowAnalyzer`, `CallGraphAnalyzer`, `DebugInformationAnalysis`,
  `DependencyAnalysis`, `ExportAnalysis`, `ImportExportAnalysis`,
  `SymbolAnalysis`), the canonical IR (`IRModule` et al.) and
  `Storage/CacheManager` are **implemented but not wired in** — no call
  sites outside their own files.
- `TypeRecovery.recover` returns `[]` — no fabricated types.
- `DataFlowAnalyzer` is a documented seam only
  (`isBackendProvidedOnly() == true`).
- Function boundaries come from metadata + call-target harvesting;
  `refine` returns input unchanged without real instructions.
- String `isReferenced` is never set — no string→code reference
  resolution yet.

## Reconstruction & Assemble (added 2026-11-10)

- **No ObjC/Swift metadata recovery** — only symbol-proven facts are
  emitted (`@class` forward declarations for `OBJC_CLASS_$_` symbols,
  a Swift symbol list with an explicit "not reliable" diagnostic).
  No methods, properties, or Swift types are invented.
- **Ghidra pseudocode is machine-generated** — labelled
  Reconstructed/Inferred with provenance and a `ghidra_types.h` compat
  header; unknown imports are declared `extern long name();` (honest,
  links) and known libc functions get real system headers. Raw Ghidra
  output is ~8% compilable as-is in published measurements, so the
  assembly fallback + address map always ship alongside.
- **Assembly fallback is `.partial` by design** — PC-relative repair
  covers x86_64 RIP-relative/GOT and arm64 adrp/adr/bl + GOT-pair
  rewrites; unrepairable references keep their bytes plus a warning.
  The x86_64 path is verified end to end (Linux E2E rebuild +
  `dlopen`); the arm64 path is implemented but has no end-to-end test
  on a real arm64 binary.
- **Assemble needs a real compiler** (`xcrun clang` on macOS, `clang`/
  `cc`/`gcc` on PATH elsewhere); without one it reports guidance,
  not a fake artifact. Output is validated by re-parsing with the
  module's own parsers; equivalence reports export/import/dependency
  diffs and never claims behavioral equivalence from build success.
- **No DWARF-based line/type recovery** — source maps are
  function-level (address → file/line of the generated definition),
  not original line numbers.

## Multi-language Assemble (Slices 1–6, added 2026-11-10)

- **The original source language cannot be recovered** — a `.dylib`
  is native machine code; reconstruction is C/assembly by nature.
  The 17 backends rebuild *edited* source in the language the user
  chose; they say nothing about what the original was written in.
- **Managed/scripted languages are not native** — JavaScript, Python,
  Lua and JVM Java reach a `.dylib` only through an embedded runtime
  (JavaScriptCore/QuickJS, CPython, Lua interpreter, JNI). The
  produced library is a shim plus a bundled script, not compiled
  source, and the backend reports that. QuickJS has no JIT; it is an
  interpreter, so QuickJS-built libraries are slower than
  JavaScriptCore's.
- **No SwiftPM tree-sitter grammar for Swift, Lua, Kotlin, Nim, or D**
  — Swift is validated with SwiftParser (swift-syntax, already a repo
  dependency); Lua/Kotlin/Nim/D sources are skipped by the validator
  with an honest info diagnostic, not silently passed as valid.
- **The tree-sitter validator checks syntax only** — it reports parse
  errors before a compiler runs; it does not type-check, resolve
  imports, or guarantee the code compiles.
- **LSP is server management only** — `LanguageServerManager`
  launches, supervises and restarts language servers and reports
  missing binaries with install guidance. Completion, hover and
  diagnostics are not wired into the main editor; that is a follow-up.
  On Linux the manager does not use Foundation's
  `terminationHandler` or `terminationStatus`: when a server is
  launched from a Swift-concurrency context, the handler never fires
  for a terminated process and `terminationStatus` can trap, because
  the child inherits the pool thread's blocked SIGTERM mask and never
  dies from SIGTERM at all. The manager instead polls `waitpid`
  (WNOHANG) per server for exit detection and stops a server with
  SIGTERM followed by SIGKILL after 200 ms if it is still alive.
  SIGKILL cannot be blocked, so stopping is guaranteed. This is a
  Linux-verified workaround; the macOS behaviour of the same code is
  untested until the Mac build.
- **Backend availability is toolchain-dependent** — a backend that
  cannot find its toolchain reports unavailable with guidance; the
  picker disables it. No backend is ever faked as available.
- **JavaScript/Python grammars are pinned to tree-sitter 0.23.x** —
  their 0.25.0 manifests use a relative-path file check to decide
  whether to compile the external scanner, which evaluates false when
  the package is a dependency under SwiftPM 6.2.3, producing a link
  failure. 0.23.1 (JavaScript) and 0.23.6 (Python) list the scanner
  unconditionally. Re-check before upgrading.
- **The vendored QuickJS copies differ in layout** — the `CQuickJS`
  target keeps `quickjs.h` under `include/` for its SwiftPM module
  map and also flat at the target root for Assemble bundling; the
  `Resources/QuickJS/` copy is flat only. The drift test pins the
  flat files byte-identical; the `include/` copy is not covered by
  that test.
- **The Xcode build is still the gate** — the multi-language Assemble
  work (including the new packages and the `CQuickJS` target) is
  verified on Linux via the Foundation-only mini-package; the Xcode
  build, the Xcode test suite, and a live Mach-O `.dylib` rebuild on
  Dylan's Mac are pending. The `CQuickJS` Xcode target is declared in
  `project.yml`; whether Xcode picks up the C target (including its
  module map for `import CQuickJS`) from the hand-patched `.xcodeproj`
  is unverified until the Mac build.

## AI (Decompile Assist)

- Implemented end-to-end in code: asset loading (17 `.md` present),
  provider policy (Antigravity/Gemini only), context builder, SDK session
  multiplexing, ~40 tools across 7 files with approval gating.
- Wired into the app at startup (`AppSupport` calls
  `DecompilerLifecycle.installDefaultEngines()` and
  `setAssistPanel(_:)`); the earlier "no call sites" claim was wrong.
  `GoogleCloudSDKRuntime.toolExecutionHandler` is still a single global
  slot shared by Decompile Assist sessions — concurrent sessions can
  clobber each other.
- Model output is unverified by definition; findings require user
  confirmation.
- Provider policy is intentionally narrow — no OAuth **and** no Gemini
  key ⇒ `engineUnavailable`.

## UI / integration gaps

- UI is implemented (`Interface/` Friendly+Master, `App/` window
  manager/controller/commands) and `openDecompiler:` routes to
  `DecompilerWindowManager`; `AppSupport` calls
  `DecompilerLifecycle.installDefaultEngines()` at startup, so
  `EngineRegistry` is populated. Decompile Asset / Assemble / Open in
  Editor are wired as toolbar items, `DecompilerCommands` cases, and
  Friendly toolbar buttons.
- `.scdecomp` is not a declared document type (`Info.plist`/`project.yml`).
- No XcodeGen test target for `YcodeDecompilerTests`.
- `exportAnalysis` command writes a hand-built text summary; the six
  `Export/` exporters (report/assembly/graph/project/pseudocode/symbol)
  are implemented but not wired to UI.
- `Configuration/*` preference types persist to UserDefaults but are not
  yet read back into `AnalysisConfiguration`/engine settings
  (`EngineConfiguration.ghidraHomePath`, `ghidraExtraArguments`,
  `engineTempDirectory`, `ghidraEnabled` are currently inert).

## Storage / performance

- Persistence is full-rewrite per save (SQLite delete-all + reinsert, or
  whole JSON snapshot); no incremental updates.
- Migrations: only schema v1 exists; `DecompilerDatabaseSchema.
  migrations()` documents the DDL and `DatabaseMigrations/` is reserved —
  no migration runner yet.
- `AnalysisStore.instructions` is unbounded — disassembling a very large
  binary can exhaust memory before declared caps matter.
- `CacheManager` exists but is unused, so repeated decompile/disassemble
  calls re-run engines (Ghidra re-`-process` is cheap-ish due to
  `-noanalysis`, but not free).
- `Analysis.json` fallback duplicates everything as JSON — wasteful for
  large stores; SQLite preferred where available.

## Platform

- SwiftPM is the primary tested path; XcodeGen build lacks `CSQLite`
  (JSON fallback) and the test target.
- Engine discovery assumes macOS/Xcode (`xcrun`, `/Applications`,
  `~/ghidra*`); Linux behaviour unverified.
- `xcrun`-dependent demangling degrades gracefully (raw names) off-macOS.

## Evidence

| Claim | Level |
|---|---|
| Every limitation above | 1 — verified against current sources |
| llvm-objdump linear-sweep / Ghidra path-hash caveats | 1 — documented in backend source comments |
