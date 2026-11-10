# YcodeDecompiler — Testing

## Running the tests

Tests live in `swiftcode/Tests/YcodeDecompilerTests/` and are wired into
the `swiftcode` SwiftPM package:

```bash
cd swiftcode
swift test --filter YcodeDecompilerTests
```

(the test target is declared in `swiftcode/Package.swift` with
`path: "Tests/YcodeDecompilerTests"` and depends on `YcodeDecompiler`).

The suite uses **XCTest** (`XCTestCase`, async test methods) with
`@testable import YcodeDecompiler`.

## Fixture strategy

All binary fixtures are **hand-built in code** — tens to hundreds of
bytes, deterministic, no corpus files, no Apple binaries, no network:

- `ELFParserTests` assembles an ELF64 LE executable: ELF header, one
  `PT_LOAD`, `.text`/`.symtab`/`.strtab`/`.shstrtab` sections, one `_main`
  symbol (~0x300 bytes). Section/symbol addresses sit inside the `PT_LOAD`
  range so segment assignment and VA→offset translation are exercised.
- `PEParserTests` assembles a PE32+ x86-64 image: DOS stub (`MZ`,
  `e_lfanew=0x80`), PE signature, COFF header, 0xF0-byte optional header
  (PE32+ magic 0x20B, ImageBase 0x140000000, entry RVA 0x1000), one `.text`
  section (~0x400 bytes).
- `MachOParserTests` assembles a thin arm64 Mach-O: `mach_header_64`,
  `LC_SEGMENT_64` with one `__text` section (exec flags
  `S_ATTR_PURE_INSTRUCTIONS|S_ATTR_SOME_INSTRUCTIONS`), `LC_SYMTAB`, one
  `_main` `nlist_64` (~0x140 bytes).
- `DetectorTests` writes signature-only buffers (4–256 bytes) with
  misleading extensions to prove detection ignores names.

Every fixture is written to `FileManager.default.temporaryDirectory`
with a UUID name and removed via `addTeardownBlock`.

## Parser-test approach

Tests resolve the parser through `BinaryLoader.parsers.first { $0.format
== … }` (the `BinaryParser` protocol) rather than naming concrete types,
and raise `XCTSkip` if a format parser is not registered — so the tests
pin the *contract* (`detectSlices`, `parse` → `BinaryImage`) and survive
internal parser refactors. `parse` is fed a `BinaryIdentity` and a
file-backed `byteProvider` closure matching the production signature.

Assertions are deliberately tolerant where the canonical model allows
latitude (e.g. `fileType` string content is only checked non-empty;
symbol lookup matches `contains("main")`).

## What's covered

| File | Coverage |
|---|---|
| `AddressTests.swift` | `DecompilerAddress` parse/format/order; `BinaryImage.fileOffset(forVirtualAddress:)` mapping, unmapped/beyond-fileSize cases, `bytes(virtualAddress:)` `unmappedAddress` error |
| `ELFParserTests.swift` | ELF detection, single-slice enumeration (x86_64), header fields (format/arch/entry 0x400100/not-encrypted), LOAD segment at 0x400000, `_main` symbol |
| `PEParserTests.swift` | PE detection, slice enumeration (x86_64), header fields (format/arch/entryPoint non-nil/not-encrypted), `.text` section present |
| `MachOParserTests.swift` | Mach-O detection, slice enumeration (arm64), header fields, `__TEXT` segment + executable `__text` section at expected VA, `_main` symbol |
| `DetectorTests.swift` | All magics (thin 32/64 Mach-O, fat 32/64, ELF, PE via MZ+PE-header and MZ-only), unknown-signature and tiny-file rejection, SHA-256 stability/format |
| `StoreTests.swift` | `AnalysisStore` function/symbol upsert + dedup + sort, `function(at:)`/`function(containing:)` (incl. end-address and next-function bounds), reversible renames (`originalName`, `userName`, `effectiveName`, symbol sync), comments/labels hex keys, `storePseudocode`→`hasPseudocode`, pin toggling |

## Known gaps in coverage

- **No engine-backend tests** — `ObjDumpDisassembler` and
  `GhidraDecompiler` are implemented but untested (they need
  llvm-objdump/Ghidra installed; a fake-tool PATH shim would be the way
  to test them hermetically).
- **No persistence round-trip test** — `AnalysisPersistence` /
  `CacheManager` deserve save→load diff tests against a temp
  `.scdecomp`.
- **No session/coordinator end-to-end test** — `importBinary` →
  `runAnalysis` → store assertions using the ELF fixture is the natural
  next test now that parsers exist.
- **No UI tests** (SwiftUI views are not unit-tested anywhere in the repo
  convention).
- Fat-Mach-O slicing, big-endian ELF, PE32 (non-+) and import/export
  directory parsing are implemented but not covered by fixtures yet.

## Evidence

| Claim | Level |
|---|---|
| Test inventory, fixture approach, run command | 1 — test sources + `Package.swift` |
| Coverage gaps | 1 — cross-checked against module sources |
