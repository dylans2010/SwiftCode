# YcodeDecompiler — Binary Formats

Supported container formats, slice handling, the address model, and what is
deliberately *not* parsed. All three parsers are implemented under
`Formats/` and registered in `BinaryLoader.parsers` (priority order:
Mach-O, ELF, PE).

## Detection (`BinaryDetector`)

Reads at most the first 4 KiB; keys off magic bytes only — extensions are
never consulted.

| Signature | Result |
|---|---|
| Mach-O magics `0xFEEDFACE`/`0xFEEDFACF` and byte-swapped (`MH_CIGAM*`) variants | `format = .machO`, `isUniversal = false` |
| `CA FE BA BE` / `CA FE BA BF` (+64-bit `…BF` forms) | `format = .machO`, `isUniversal = true` |
| `7F 45 4C 46` (`\x7FELF`) | `format = .elf` |
| `MZ` + `PE\0\0` at `e_lfanew` (u32 @ `0x3C`) | `format = .pe` |
| `MZ` without visible `PE\0\0` in first 4 KiB | `format = .pe` (candidate) |
| anything else / < 4 bytes | throws `unsupportedFormat` / `malformedBinary` |

`BinaryDetector.sha256(url:)` streams SHA-256 → `BinaryIdentity.sha256`,
the content key for caches, the store and `.scdecomp` identity.

## Parsers (`Formats/`)

### Mach-O (`MachOParser`, 724 lines)

- Thin 32/64-bit, little- **and** big-endian (`MH_CIGAM` orderings).
- Fat/universal containers: `FAT_MAGIC`/`FAT_CIGAM`/`FAT_MAGIC_64`,
  big- or little-endian arch tables (`detectFatSlices` enumerates
  `SliceDescriptor`s; `parse` slices via `slice.offset`/`slice.size`).
- Load commands handled: `LC_SEGMENT`/`LC_SEGMENT_64` (with full
  `section`/`section_64` tables), `LC_SYMTAB`, `LC_DYSYMTAB` (consumed),
  all dylib commands (`load/weak/reexport/lazy/upward` + `id` +
  `loadDylinker`), `LC_UUID`, `LC_ENCRYPTION_INFO(_64)`, `LC_MAIN`,
  `LC_CODE_SIGNATURE`, `LC_FUNCTION_STARTS`, `LC_DATA_IN_CODE`,
  `LC_DYLD_INFO(_ONLY)`, `LC_DYLD_EXPORTS_TRIE`,
  `LC_DYLD_CHAINED_FIXUPS`, `LC_BUILD_VERSION`,
  `LC_VERSION_MIN_{MACOSX,IPHONEOS,TVOS,WATCHOS}`; unknown commands are
  skipped by `cmdsize`.
- Derived data: segments+sections (absolute file offsets =
  `slice.offset +` on-disk offset), nlist symbols + undefined→imports,
  dyld export trie (`ULEB128`), function starts (`LC_FUNCTION_STARTS`
  deltas → VAs), entry point (`LC_MAIN` file offset + image base),
  dependencies with versions, `isEncrypted`, `isSigned` + signature
  notes, build/min-OS versions, `binaryUUID` (dashed UUID), `hasDebugInfo`
  (`__DWARF` segment or local defined symbols).
- Guardrails: slice ≤ 2 GiB, sane `cmdsize`, section table bounded by the
  load command.

### ELF (`ELFBinaryParser`, 478 lines)

- ELF32 and ELF64, little- and big-endian (`EI_DATA`).
- `e_type`, `e_machine`, `e_entry`, program headers (`PT_LOAD` →
  segments; `PT_INTERP` → interpreter note; `PT_DYNAMIC` noted),
  section headers including **extended section numbering** (shnum/shstrndx
  == 0 → real values from section header 0).
- `.symtab` + `.dynsym`: symbols with bind/type, undefined → imports,
  dynsym globals → exports; string tables resolved via `sh_link`.
- `.dynamic`: `DT_NEEDED` → dependencies (d_val translated VA→file offset
  through `PT_LOAD`s).
- `NT_GNU_BUILD_ID` notes → `binaryUUID` (hex); `.debug*` sections →
  `hasDebugInfo`.
- Non-alloc/unclaimed sections go to a `__NON_ALLOC` bookkeeping segment
  (vmSize 0 → no VA mapping).
- Guardrails: file ≤ 2 GiB, ≤4096 sections, ≤1024 segments.

### PE (`PEBinaryParser`, 375 lines)

- DOS stub (`MZ`, `e_lfanew`), `PE\0\0`, COFF header, optional header
  **PE32 (0x10B) and PE32+ (0x20B)**.
- Machine → arch via `peMachine` (AMD64/I386/ARM64/ARM/ARMNT).
- All 16 data directories parsed where present: **import table**
  (descriptors → DLL dependencies + per-function imports via thunk
  walk), **export table** (names/ordinals → `BinaryExport`s),
  **security directory** (certificate table → `isSigned` + note),
  **debug directory** (CodeView `RSDS` → PDB path note +
  `hasDebugInfo`).
- Each section becomes its own `BinarySegmentInfo` so
  `fileOffset(forVirtualAddress:)` resolves `ImageBase + RVA` →
  `PointerToRawData` correctly; executable/writable from
  `IMAGE_SCN_MEM_*` characteristics.
- Guardrails: file ≤ 2 GiB, ≤4096 sections.

## Canonical image model (`BinaryImage`)

Every parser produces the same backend-independent structure:
`BinaryIdentity` (sha256, names, size, format, arch, slice index/name,
`binaryUUID`, `parserVersion`; `stableID = "<sha256[0..16]>-s<slice>"`),
`entryPoint`, `segments`→`BinarySegmentInfo` (vmaddr/vmsize/fileoff/
filesize/protections/`isExecutable`) containing `BinarySectionInfo`
(name, segment, VA, size, fileOffset, flags, `isExecutable`,
`isWritable`, `containsStrings`), `imports`, `exports`, `dependencies`
(`load`/`weak`/`reexport`/`upward`/`lazy`), `symbols`, `strings`,
`functionStarts`, flags (`isEncrypted`, `isSigned`, `entitlements`,
`codeSignatureInfo`, `buildVersion`, `minOSVersion`, `hasDebugInfo`),
`byteCount` + bounded random-access `byteProvider`.

## Slice handling

- `detectSlices(url:)` enumerates slices **without** full parsing:
  fat Mach-O → one `SliceDescriptor` per arch (index, architecture,
  cpuIdentifier `"<cpuType>/<cpuSubtype>"`, offset, size, name);
  thin ELF/PE/Mach-O → exactly one slice at offset 0.
- `parse(url:sliceIndex:…)` re-derives slices internally and selects by
  index (first slice as fallback); Mach-O reads only the slice's byte
  range and rebases file offsets by `slice.offset`.
- `DecompilerSession.importBinary(at:sliceIndex:)` /
  `selectSlice(_:)` drive slice choice; `availableSlices()` feeds the UI
  architecture picker.

## Address model

`DecompilerAddress` = typed `(kind, value)`:

| Kind | Meaning |
|---|---|
| `.virtual` | loaded-image virtual address |
| `.fileOffset` | byte offset in the original file |
| `.sectionRelative` | offset from a section start |
| `.imageRelative` | offset from a slice start inside a container |

VA and file offset are never interchangeable. Translation:
`BinaryImage.fileOffset(forVirtualAddress:)` walks segments — mapped iff
`vmAddress ≤ va < vmAddress+vmSize` **and** delta `< fileSize`;
`bytes(virtualAddress:)` throws `unmappedAddress` otherwise. Section
`fileOffset`s are stored absolute (slice base included) so string
analysis and byte reads index correctly through `byteProvider`.

## Architecture coverage

`BinaryArchitecture`: arm64, arm64_32, x86_64, armv7, armv7s, armv6,
i386, riscv64, powerpc, powerpc64, mips, unknown — with `addressWidth`
and `endianness` (PowerPC/MIPS big-endian only). `ArchitectureResolver`
maps raw CPU ids: Mach-O `cpuType/cpuSubtype` (ARM64 0x0100000C incl.
arm64e, X86_64 0x01000007, ARM 12+subtype, I386 7, PPC 18, PPC64
0x01000012), ELF `e_machine` (AARCH64 183, X86_64 62, ARM 40, 386 3,
MIPS 8, PPC 21, RISCV 243), PE machine (0x8664/0x014C/0xAA64/0x01C0/
0x01C4).

## Feature matrix (as implemented)

| Feature | Mach-O | ELF | PE |
|---|---|---|---|
| Universal/fat slices | yes (4 magics, 32/64 arch entries) | n/a | n/a |
| Endianness | LE + BE (CIGAM) | LE + BE | LE |
| Class | 32 + 64 | 32 + 64 | PE32 + PE32+ |
| Segments/sections | all segment cmds + sections | PT_LOAD + all shdrs | per-section pseudo-segments |
| Entry point | LC_MAIN (+image base) | e_entry | ImageBase + AddressOfEntryPoint |
| Symbols | LC_SYMTAB nlist (incl. ext/weak) | .symtab/.dynsym | — (export table instead) |
| Imports | undefined nlists | SHN_UNDEF syms | import descriptors + thunks |
| Exports | dyld export trie + dynsym | .dynsym globals | export directory |
| Dependencies | dylib cmds w/ versions | DT_NEEDED | import DLL names |
| UUID/build-id | LC_UUID | NT_GNU_BUILD_ID | — |
| Encryption | LC_ENCRYPTION_INFO(_64) | — | — |
| Signature | LC_CODE_SIGNATURE → notes | — | security dir → isSigned |
| Debug info | __DWARF/local syms → flag | .debug* → flag | debug dir → PDB note |
| Function starts | LC_FUNCTION_STARTS (ULEB128) | — | — |
| min-OS/build | LC_VERSION_MIN_*, LC_BUILD_VERSION | — | — |

## What is NOT parsed (honest list)

- **No DWARF/PDB contents** — presence is reported (`hasDebugInfo`,
  `dwarfSections`, PDB path note); types/lines are delegated to the
  decompiler backend. `TypeRecovery.recover` still returns `[]`.
- **No Objective-C/Swift runtime metadata** (classes, selectors,
  protocols) beyond plain symbols/strings; no Swift reflection-section
  decoding despite `sectionStringNames` awareness.
- **No relocations** (no rebasing of pointers/addresses in data).
- **No code-signature superblob parsing** — presence/size noted only.
- **No PE resources** (`.rsrc` version info/icons), TLS callbacks,
  delay-load imports, .NET metadata.
- **No ELF notes beyond build-id**, no `.gnu_debuglink`, no
  compressed (`SHF_COMPRESSED`/`ELFCOMPRESS`) section decompression.
- **No instruction decoding** in parsers — that is
  `DisassemblerProvider`'s job; **no decompilation** — `DecompilerProvider`.
- Archives (`.a`/`.lib`), relocatable `.o`/`.obj` (though ET_REL parses
  structurally), .NET assemblies, class files, scripts: not detected.
- ELF `strings`/`functionStarts` are left empty — string extraction is a
  separate `StringAnalysis` pass over non-executable sections; Mach-O
  likewise leaves `strings` empty for the same reason.

## Evidence

| Claim | Level |
|---|---|
| Detection, parsers, address model, arch table, guardrails | 1 — `BinaryDetector.swift`, `Formats/**`, `BinaryImage.swift`, `BinaryFormat.swift`, `DecompilerAddress.swift` |
| "Not parsed" list | 1 — verified against parser sources |
