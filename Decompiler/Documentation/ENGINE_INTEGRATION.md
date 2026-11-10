# YcodeDecompiler — Engine Integration

How the two concrete analysis backends work:
`ObjDumpDisassembler` (LLVM `llvm-objdump`) and `GhidraDecompiler`
(Ghidra `analyzeHeadless`). Both are implemented and registered by
`EngineBootstrap.installDefaults()`.

## Provider contracts (`Engines/EngineProtocols.swift`)

### `DisassemblerProvider`

```swift
var id: String { get }               // "llvm-objdump"
var displayName: String { get }
var version: String? { get }
func capabilities(for image: BinaryImage) -> DecompilerCapabilitiesSet
func isAvailable() async -> Bool
func disassemble(image: BinaryImage, start: DecompilerAddress,
                 end: DecompilerAddress,
                 progress: (@Sendable (AnalysisProgress) -> Void)?)
    async throws -> [Instruction]
```

`start`/`end` are virtual addresses. Backends translate through
`BinaryImage.fileOffset(forVirtualAddress:)` / `bytes(virtualAddress:)`.

### `DecompilerProvider`

```swift
var id: String { get }               // "ghidra"
var displayName: String { get }
var version: String? { get }
var isPrimary: Bool { get }          // Ghidra: true
func isAvailable() async -> Bool
func availabilityDetail() async -> String
func capabilities(for image: BinaryImage) -> DecompilerCapabilitiesSet
func decompile(_ request: DecompilationRequest,
               progress: ...) async throws -> DecompilationResult
func decompileBatch(_ requests: [DecompilationRequest],
                    progress: ...) async throws -> [DecompilationResult]
```

`DecompilationRequest` carries function address/name, `imagePath`,
architecture, format and free-form `options`. `DecompilationResult` holds
pseudocode, optional signature, parameters, return type, locals,
address→line map, warnings, `engineID`/`engineVersion`, and
`rawBackendOutput` (capped at 1 MiB by the Ghidra backend).

## EngineRegistry & resolution

`EngineRegistry` (actor) holds provider lists; `register` deduplicates by
`id`. `resolveDisassembler(for:preferredID:)` returns the first registered
disassembler (the llvm-objdump backend advertises an empty capability set —
resolution does not filter on caps for disassemblers).
`resolveDecompiler(for:required:preferredID:)` filters by
`DecompilerCapabilitiesSet` superset-or-`decompileFunction`, prefers
`isPrimary`, and honours `preferredID`. `descriptors()` returns live
availability for UI. `EngineRegistry.installDefaults()` is an empty hook;
`EngineBootstrap.installDefaults()` performs the real registration
(`ObjDumpDisassembler` + `GhidraDecompiler`) and is invoked by
`DecompilerLifecycle.installDefaultEngines()`.

## ObjDumpDisassembler (`Disassembly/Backends/ObjDumpDisassembler.swift`)

**Tool discovery** (`ToolCache`, resolved once, `NSLock`-guarded):

1. `SWIFTCODE_LLVM_OBJDUMP` environment override (checked first)
2. `xcrun -f llvm-objdump` (Apple toolchains)
3. `which llvm-objdump` / PATH lookup

Version is parsed from `llvm-objdump --version` output and cached.

**Invocation model** — the container file is *not* disassembled directly
(fat/multi-arch inputs would pick the wrong slice). Instead, for each
executable section overlapping `[start, end)`:

1. Section bytes are extracted through `BinaryImage.byteProvider`.
2. A raw binary is disassembled per section:

   ```
   llvm-objdump -D -b binary --triple=<arch-triple>
       --adjust-vma=<sectionVMA>
       --start-address=<lo> --stop-address=<hi>
   ```

   `-D` forces linear disassembly of the entire section; `--adjust-vma`
   rebases addresses so output addresses match the image's virtual
   addresses; start/stop bound the requested range.

3. Output lines are parsed (`parseLine`) into address/mnemonic/operand
   text/raw bytes; lines outside `[lo, hi)` are filtered.
4. `makeInstruction` builds `Instruction` values: operands become
   `.other(text)` (no structured operand decoding), `classification` is
   derived from mnemonic tables (`returnMnemonics`, `callMnemonics`,
   `branchMnemonics`), and `branchTarget` is extracted from operand text
   when it looks like an address.

**Triples** (`triple(for:)`): aarch64, aarch64_32, x86_64, armv7/armv7s
(`armv7-linux-gnueabihf`), armv6, i386, riscv64, powerpc, powerpc64, mips —
all `*-linux-gnu*`; `.unknown` → `unsupportedArchitecture`.

**Limitations (by design, documented in-source):**

- Linear sweep only (`-D`): no recursive descent, no function-aware skip —
  inline data/jump tables can decode as instructions; undecodable bytes
  surface as `.byte`/`(bad)` and are classified `.invalid`.
- No structured operands — operand text is preserved verbatim.
- Subprocess runs through `YcodeSubprocess` (`Subprocess.run` /
  `StreamingSubprocess`), inheriting `MainThreadGuard` and pipe bounds.

## GhidraDecompiler (`Decompilation/Backends/GhidraDecompiler.swift`)

**Install discovery** (`locateGhidraHome()`, cached in `GhidraState`):

1. `SWIFTCODE_GHIDRA_HOME`, then `GHIDRA_INSTALL_DIR` — each is accepted
   directly if it contains `support/analyzeHeadless`, or searched one
   level deep for a `ghidra*` child that does.
2. Bundle resource dirs: `Bundle.module`/`Bundle.main` `Engines/ghidra`,
   plus a `#filePath`-relative `Resources/Engines/ghidra` fallback.
3. Filesystem scan: newest `ghidra*` directory under `~`, `/opt`,
   `/usr/local`, `/Applications` (sorted descending, first valid root wins).

`isAvailable()` additionally requires `java -version` (via
`/usr/bin/env`, PATH-honouring) to succeed — Ghidra needs Java 21+;
`availabilityDetail()` reports which prerequisite is missing.
Version comes from `application.version` in `application.properties`.

**Project cache layout** — under
`NSTemporaryDirectory()/SwiftCodeDecompiler/ghidra-projects/`:

```
proj-<fnv1a64(imagePath)>/
    swiftcode-<fnv1a64(imagePath)>.gpr     # Ghidra project
    swiftcode-<fnv1a64(imagePath)>.rep/    # project repository (created by Ghidra)
    .swiftcode-imported                     # import-success marker
    decompile-<uuid>.json                   # per-request output (deleted after read)
```

- Key = FNV-1a 64 of `request.imagePath` (stable per path, not content
  hash — see Limitations).
- `ensureImported` runs the expensive step once:
  `analyzeHeadless <dir> <name> -import <file> -scriptPath <dir>`
  (full Ghidra auto-analysis). A `.swiftcode-imported` marker + `.gpr`
  presence skips re-import; stale/partial dirs are deleted first.
- Entries older than 7 days are pruned opportunistically
  (`pruneOldProjects`).

**Decompile invocation** (per function):

```
analyzeHeadless <dir> <name> -process <programName> -noanalysis \
    -scriptPath <dir> -postScript DecompileDump.py <out.json> <addrHex>
```

- `-noanalysis` reuses the imported analysis — only the decompiler runs.
- `programName` defaults to the binary's last path component; on
  `engineFailure` the backend retries with bare `-process` (all programs)
  because fat/universal Mach-O imports can produce differently-named
  programs.
- `DecompileDump.py` (Jython, bundled in `Resources/EngineScripts/`,
  located via `Bundle.module` → `Bundle.main` → `#filePath` fallback)
  decompiles the function(s) matching the address filter and writes **one
  JSON object per line**:

  ```json
  {"address":"0x…","name":"…","signature":"…","cCode":"…",
   "parameters":[…],"returnType":"…","localVariables":[…],"warnings":[…]}
  ```

  Per-function failures emit `{"error":"…"}` records; an unmatched filter
  emits `{"error":"function-not-found"}`.

- The Swift side reads the last non-error record and maps it onto
  `DecompilationResult` (`cCode`→`pseudocode`, `signature`, `parameters`,
  `returnType` (empty→nil), `localVariables`, `warnings`, full text →
  `rawBackendOutput` when ≤1 MiB).

**Batch** (`decompileBatch`): each request gets its own headless
`-process` call, but the `-import`+auto-analysis step is shared per
`imagePath` through an in-call `imported` cache. There is no dump-all
single-run mode.

**Capabilities** (when Ghidra is installed): `decompileFunction`,
`decompileBatch`, `functionDiscovery`, `typeRecovery`,
`crossReferences`, `controlFlowGraph`, `callGraph` — `pcode` is *not*
exposed even though the script uses the decompiler internally.

**Process layer**: `analyzeHeadless` runs via
`StreamingSubprocess.lines`; `ExitError.wasInterrupted` →
`engineCancelled`, non-zero exit → `engineFailure` with a 600-char stderr
tail; `CancellationError` → `engineCancelled`.

## Protocol / JSON contract summary

- In-process: the Swift protocols above; no IPC.
- Ghidra bridge: newline-delimited JSON records as documented above —
  the only cross-process data contract.
- Persistence formats: see `STORAGE.md`.

## Limitations

- llvm-objdump path: linear sweep, `.other` operands, no function-aware
  decoding; architecture coverage = LLVM target triples (no `.unknown`).
- Ghidra path: project cache keyed by **path hash**, not content hash —
  same bytes at a different path re-import; same path with changed bytes
  reuses stale analysis until the 7-day prune or manual cache clear.
- Fat Mach-O: `-process <programName>` may miss; the all-programs retry
  relies on the script's address filter.
- `EngineConfiguration.ghidraHomePath`/`ghidraExtraArguments` exist as
  persisted preferences but are not yet read by `GhidraDecompiler`
  (discovery is env/bundle/filesystem only).
- Engine availability is probed lazily and cached for process lifetime.
- `engineTimeoutSeconds` (default 600 s, `AnalysisSandbox` max 600) is a
  configuration value; headless runs are bounded by process cancellation,
  not an in-code timer.

## Evidence

| Claim | Level |
|---|---|
| Provider contracts, registry, bootstrap | 1 — source inspection |
| llvm-objdump discovery order, flags, triples, classification | 1 — `ObjDumpDisassembler.swift` |
| Ghidra discovery, cache layout, invocation, JSON contract, retry/prune | 1 — `GhidraDecompiler.swift` + `DecompileDump.py` |
| Unwired config preferences | 1 — grep-verified |
