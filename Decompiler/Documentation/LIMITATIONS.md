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

## AI (Decompile Assist)

- Implemented end-to-end in code: asset loading (17 `.md` present),
  provider policy (Antigravity/Gemini only), context builder, SDK session
  multiplexing, ~40 tools across 7 files with approval gating.
- **Not yet wired into the app**: `DecompilerLifecycle.
  installDefaultEngines()`/`setAssistPanel(_:)` have no call sites in
  `swiftcode/Sources`, so the assist panel is not injected and engines
  are not auto-registered at startup.
- Model output is unverified by definition; findings require user
  confirmation.
- Provider policy is intentionally narrow — no OAuth **and** no Gemini
  key ⇒ `engineUnavailable`.

## UI / integration gaps

- UI is implemented (`Interface/` Friendly+Master, `App/` window
  manager/controller/commands) and `openDecompiler:` routes to
  `DecompilerWindowManager` — but nothing calls
  `DecompilerLifecycle.installDefaultEngines()`, so `EngineRegistry`
  starts empty unless bootstrap runs; sessions will report
  `engineUnavailable` for disassembly/decompilation until then.
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
