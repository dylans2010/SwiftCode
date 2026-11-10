# PE Reference

PE (Portable Executable) is the executable format on Windows: `.exe`,
`.dll`, `.sys` drivers, and `.scr`. COFF object files share the header family.

## Structure

- **DOS header** (`IMAGE_DOS_HEADER`): starts with `MZ`; `e_lfanew` at offset
  `0x3c` points to the PE signature.
- **PE signature**: `PE\0\0`, then `IMAGE_FILE_HEADER` (machine, section
  count, timestamp, characteristics like `IMAGE_FILE_DLL`, `IMAGE_FILE_EXECUTABLE_MACHINE`).
- **Optional header** (`IMAGE_OPTIONAL_HEADER32/64`): magic `0x10b`/`0x20b`,
  entry point RVA, image base, section alignment, subsystem, **data
  directories** (16 entries).
- **Section headers** (`IMAGE_SECTION_HEADER`): name (8 bytes), virtual size,
  virtual address, raw size, raw pointer, characteristics — maps to
  `BinarySectionInfo` with executable/writable flags from characteristics.

## Data directories

The 16 data directories are the PE equivalent of Mach-O load commands:

| Index | Name | Contents |
|---|---|---|
| 0 | Export | Exported functions/data |
| 1 | Import | Imported functions per DLL |
| 2 | Resource | Version info, icons, manifests, dialogs |
| 3 | Exception | SEH/unwind data (x64) |
| 5 | Base reloc | Relocation fixups (PIE/ASLR) |
| 9 | TLS | Thread-local storage callbacks |
| 10 | Load config | SEH table, CFG flags, guard CF |
| 12 | IAT | Import address table |

`image.exports`/`image.imports`/`image.dependencies` derive from these.

## Imports and the IAT

Calls to imports go through the IAT: `call qword ptr [rip+X]` (x64) or
`call dword ptr [iat_entry]` (x86). The disassembly shows the IAT slot; the
symbol name comes from the import directory. Thunks may appear as `jmp`
stubs.

## Notable traits

- **Sections** are conventionally `.text` (code), `.rdata` (constants),
  `.data` (globals), `.pdata` (unwind info), `.rsrc` (resources),
  `.reloc` (fixups).
- **Rich header**: undocumented XOR-encoded blob after the DOS stub listing
  tool versions — useful for provenance, rarely analyzed.
- **Authenticode**: signature in a security directory (certificate table,
  data directory index 4) — maps loosely to `isSigned`/`codeSignatureInfo`.
- **Manifest** (in resources): requested OS version, DPI awareness,
  requestedExecutionLevel — useful context for behavior.
- Packed binaries (UPX etc.) have high-entropy sections and few imports;
  `analyze_suspicious_patterns` flags writable+executable sections.
