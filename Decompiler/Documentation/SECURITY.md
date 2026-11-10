# YcodeDecompiler — Security

How the module treats untrusted binary input and untrusted tool/model
output. Governing rule: **binaries are data, never code.** Nothing
executes, loads, or maps the analysed file.

## Untrusted-binary policy

- `AnalysisSecurityPolicy.validateImport(url:)` runs before every import
  (`DecompilerSession.importBinary`): must be a regular file, readable,
  ≤ `maxBinarySize` (4 GiB). Directories/devices/oversized files get typed
  `DecompilerError`s.
- Detection is signature-based; extensions are never trusted.
- All bytes flow through `BinaryImage.byteProvider` — random-access
  `FileHandle` reads bounded per call; files are never fully required in
  memory (ELF/PE parsers do read the whole slice once, capped at 2 GiB by
  parser guardrails).
- Parsers are bounds-checked throughout (`ByteCursor` throws
  `truncatedFile` past end; section/program-header counts capped at
  4096/1024; `cmdsize` validated against the load-command region).

## Resource limits

`AnalysisSecurityPolicy` (import-time):

| Limit | Value |
|---|---|
| `maxBinarySize` | 4 GiB |
| `maxReadLength` | 64 MiB per provider read (`bounded(_:)` wrapper) |
| `maxStrings` | 2,000,000 |
| `maxFunctions` | 5,000,000 (declared bound) |

`AnalysisSandbox` + `ResourceLimits` (per-operation, persisted via
`DecompilerConfiguration.resourceLimits`):

| Limit | Value |
|---|---|
| `maxFunctionsPerBulkOperation` | 100,000 |
| `maxPseudocodeBytesPerFunction` | 8 MiB (`validateResultSize`) |
| `maxEngineRuntimeSeconds` | 600 (`validateEngineTimeout` rejects, not clamps) |

Parser-level caps: ELF/PE files ≤ 2 GiB, Mach-O slices ≤ 2 GiB.
`StringAnalysis` caps per-section reads at 256 MiB.

## No execution of analysed binaries

- Parsers/analysis/stores are static reads only.
- The only spawned processes are *tools*: `llvm-objdump` (via
  `xcrun`/PATH), `analyzeHeadless`, `swift-demangle`, `c++filt`, `java
  -version` — all through `YcodeSubprocess`/`Process` with argv arrays
  (no shell), bounded pipes, and `MainThreadGuard`.
- `DecompilerSession.cancelAnalysis()` cancels the analysis `Task`;
  `Task.checkCancellation()` is honoured between disassembly sections;
  `StreamingSubprocess.ExitError.wasInterrupted` maps to
  `engineCancelled`.

## Tool approval model

Two layers:

- **`PermissionPolicy`** (`Security/PermissionPolicy.swift`) — name-based
  classification: read-only prefixes (`get_`, `list_`, `search_`, …) vs
  approval prefixes (`rename_`, `add_`, `annotate_`, `create_user_label`,
  `save_analysis_finding`, `delete_`, `set_`, `write_`, `import_`, …).
  **Unknown tools default to `.requiresApproval`** — fail-safe.
- **`DecompileAssistToolRegistry`** — the authoritative per-tool
  `requiresApproval` flag on each `DecompileAssistTool`; dispatch rejects
  mutating calls lacking `"approved": true`. (The registry docs note the
  name-based classifier would fail-safe-block legitimate read tools like
  `inspect_*`/`explain_*`, so the flag — not the classifier — gates
  dispatch.)

## Input validation (`InputValidation`)

- `validateSymbolName`: non-empty, ≤256 chars, no control characters.
- `validateProjectName`: non-empty, ≤128 chars, no path separators or
  `..` (the name becomes a bundle directory name; creation also
  sanitizes to `[A-Za-z0-9\-_. ]`).
- `validateAddressString`: parses via `DecompilerAddress.parse`.

## Path & temp-file policy

- `validateImport` rejects non-regular/unreadable paths; binaries are
  addressed by `URL` + numeric offsets, never interpolated into shell
  strings.
- `TemporaryFilePolicy` centralizes engine temp files under
  `NSTemporaryDirectory()/SwiftCodeDecompiler/`; `cleanupOlderThan`
  deletes aged entries (unageable entries are kept — fail-safe); the
  Ghidra backend additionally prunes project dirs older than 7 days.
- `.scdecomp` open validates directory + decodable `Project.json` with
  `schemaVersion ≤ projectSchemaVersion`.

## AI-output trust

- All model output enters via `DecompileAssistSession` tools returning
  JSON; findings persist as `AnalysisFinding(userConfirmed: false)` with
  `provenance = .aiSuggestion`.
- Provider policy (`DecompileAssistProviderPolicy`) pins Decompile Assist
  to Antigravity/Gemini (`gemini-*` model, `executionMode` `antigravity`
  or `api_key`) — `validate(_:)` rejects any other provider/mode/model;
  no silent fallback.

## Honest gaps

- `maxFunctions` (5M) is a declared bound, not enforced at a single
  choke point; `AnalysisStore.instructions` is unbounded in practice.
- Engine subprocesses run with user privileges — no sandbox profile.
- `PermissionPolicy.classify` is advisory; dispatch uses the per-tool
  flag (documented above).
- `Configuration/*` preference types (incl. `resourceLimits`) persist
  but are not yet read back into enforcement paths.

## Evidence

| Claim | Level |
|---|---|---|
| Import validation, limits, no-execution, approval model, path/temp handling, AI trust | 1 — `Security/*.swift`, `DecompileAssistToolRegistry.swift`, `DecompileAssistProviderPolicy.swift`, backend sources |
