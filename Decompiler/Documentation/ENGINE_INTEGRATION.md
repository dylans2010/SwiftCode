# YcodeDecompiler — Engine Integration

How the concrete analysis backends work. Disassemblers:
`ObjDumpDisassembler` (LLVM `llvm-objdump`, container mode for Mach-O/ELF)
and `OtoolDisassembler` (Apple `otool`). Decompilers: `GhidraDecompiler`
(Ghidra `analyzeHeadless`) and `AngrDecompiler` (Python `angr` bridge).
All are implemented and registered by `EngineBootstrap.installDefaults()`.

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

**Invocation model** — two modes:

- *Container mode* (preferred): the image's slice bytes
  (`containerOffset`/`byteCount`) are written to a temp file and
  `llvm-objdump -d` decodes every instruction-bearing section natively in
  one pass — Mach-O `__text`/`__stubs`/`__objc_stubs`, ELF `.text`,
  COFF `.text`. Output is cached per image identity and filtered to
  `[lo, hi)`. This covers stub sections that raw-section disassembly and
  `otool -x` both miss.
- *Raw mode* (fallback): the container file is *not* disassembled directly
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
- Per-section container-mode failures are caught by
  `AnalysisCoordinator`, which continues with other sections and records a
  `Disassembly incomplete` finding rather than failing the analysis.

## OtoolDisassembler (`Disassembly/Backends/OtoolDisassembler.swift`)

Apple `otool` backend for Mach-O only — the preferred disassembler for
Mach-O images on macOS when `llvm-objdump` is absent.

**Tool discovery** (`locateToolPath`, cached in `ToolCache`):

1. `SWIFTCODE_OTOOL` environment override
2. `xcrun -f otool` (Apple toolchains)
3. `/usr/bin/otool`, `/bin/otool`, then `which otool`

**Invocation**: `otool -xjV [-arch <arch>] <file>` — `-x` disassembles
every text section, `-j` prints the instruction word, `-V` resolves
operands symbolically (`; symbol stub for: …` comments). Output lines are
`ADDR\tHEX\tMNEMONIC\tOPERANDS`; the hex column is the 32-bit instruction
word on AArch64 (stored little-endian) and raw bytes elsewhere.

**Caching**: the full listing is parsed once per (file, arch) and kept in
a small LRU (`ListingCache`, capacity 3); each `disassemble` call filters
to `[lo, hi)`. An `-arch` failure retries once without `-arch` (covers
arm64e subtype drift on thin files).

**Classification** reuses `ObjDumpDisassembler.classify`; stub comments
(`symbol stub for:`) become `Instruction.comment`. Mach-O only —
`capabilities` returns empty for non-Mach-O formats.

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

## AngrDecompiler (`Decompilation/Backends/AngrDecompiler.swift`)

Python `angr` backend — the fallback decompiler when Ghidra is not
installed. Requires a CPython with `angr` importable (Python 3.10–3.13).

**Interpreter discovery** (`pythonCandidates` + `probe`, cached in
`AngrState`):

1. `SWIFTCODE_ANGR_PYTHON` environment override
2. `~/.swiftcode-engines/angr-venv/bin/python`
3. `python3`, `python3.12`, `python3.13`, `python3.14` resolved via `which`
4. Well-known absolute paths (`/opt/homebrew/bin/…`, `/usr/local/bin`, …)

Each candidate is probed with `python -c "import angr; print(angr.__version__)"`.

**Bridge script** (`Resources/EngineScripts/AngrDecompile.py`, located via
`Bundle.module` → `Bundle.main` → `#filePath` fallback):

```
python3 AngrDecompile.py <binary> <out.json> [--arch=NAME] <addrHex>…
```

Loads the binary once with angr/cle (`auto_load_libs=False`, `--arch`
hint for fat slices), builds one CFGFast model, then runs angr's
`Decompiler` per requested address. JSON schema matches `DecompileDump.py`
(one object per line; `{"error": …}` records for failures). Records are
**streamed** to the output file as they are produced, so a killed or
timed-out run still yields every completed function.

**Batch** (`decompileBatch`): all requests share one process — the CFG
cost is paid once. Results are keyed by entry-point address; duplicate
addresses consume records in order.

**Timeouts**: CFGFast is capped in-script (`ANGR_CFGFAST_TIMEOUT`,
default 240 s → per-function mode without a global CFG); each function is
capped (`ANGR_FUNC_TIMEOUT`, default 90 s → `decompile-timeout` record);
the whole batch is capped Swift-side (`SWIFTCODE_ANGR_TIMEOUT_SECONDS`,
default 1200 s → process killed, partial records parsed, every result
annotated with a timeout warning). `0`/negative disables each limit.

**Capabilities** (when angr is importable): `decompileFunction`,
`decompileBatch`. Supported formats: Mach-O, ELF, PE; architectures map
to angr/archinfo names (`AARCH64`, `AMD64`, `ARM`, `X86`, `RISCV64`,
`MIPS32`, `PPC32`, `PPC64`).

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
- llvm-objdump path on very large images produces a multi-hundred-MB
  listing; `containerListing` caches it per image identity for the
  process lifetime.
- angr path: pseudocode quality is below Ghidra's on large/optimised
  binaries; CFGFast timeout degrades gracefully to slower per-function
  recovery. angr does not load external libraries
  (`auto_load_libs=False`), so calls into system frameworks appear as
  unresolved imports in the pseudocode.

## Evidence

| Claim | Level |
|---|---|
| Provider contracts, registry, bootstrap | 1 — source inspection |
| llvm-objdump discovery order, flags, triples, classification | 1 — `ObjDumpDisassembler.swift` |
| Otool discovery, `-xjV` parsing, arch mapping, listing cache | 1 — `OtoolDisassembler.swift` |
| Ghidra discovery, cache layout, invocation, JSON contract, retry/prune | 1 — `GhidraDecompiler.swift` + `DecompileDump.py` |
| Angr interpreter discovery, bridge contract, timeout env vars | 1 — `AngrDecompiler.swift` + `AngrDecompile.py` |
| Unwired config preferences | 1 — grep-verified |
