# ELF Reference

ELF is the executable format on Linux, *BSD, and most Unix-like systems.

## Structure

- **ELF header** (`Elf64_Ehdr`/`Elf32_Ehdr`): magic `0x7f 'E' 'L' 'F'`, class
  (32/64-bit), endianness, `e_type` (`ET_EXEC`, `ET_DYN`, `ET_REL`),
  `e_machine` (architecture), entry point `e_entry`, section/program header
  offsets.
- **Program headers** (`Elf64_Phdr`): loadable segments — maps to
  `BinarySegmentInfo`. `p_type` values: `PT_LOAD`, `PT_DYNAMIC`,
  `PT_INTERP`, `PT_NOTE`, `PT_GNU_STACK`.
- **Section headers** (`Elf64_Shdr`): name, type, flags (`SHF_EXECINSTR`,
  `SHF_WRITE`, `SHF_ALLOC`), address, offset, size — maps to
  `BinarySectionInfo`.
- **Dynamic section** (`PT_DYNAMIC` / `.dynamic`): `DT_NEEDED` (dependencies),
  `DT_STRTAB`, `DT_SYMTAB`, `DT_PLTGOT`, relocations — maps to imports.

## Key sections

- `.text`: executable code.
- `.rodata`: read-only constants including strings.
- `.data`, `.bss`, `.data.rel.ro`: writable and relocated data.
- `.plt` / `.got.plt`: procedure linkage table and GOT for imported calls.
- `.dynsym` / `.dynstr`: dynamic symbol/string tables.
- `.symtab` / `.strtab`: full symbol table (present unless stripped).
- `.note.gnu.build-id`: build ID (maps to `binaryUUID`).

## Symbols and relocations

- Symbol visibility: `STB_LOCAL`/`STB_GLOBAL`/`STB_WEAK`; binding and type
  (`STT_FUNC`, `STT_OBJECT`, `STT_NOTYPE`) inform `BinarySymbol.kind`.
- Stripped binaries keep only `.dynsym` — internal functions need discovery.
- Relocations (`R_X86_64_*`, `R_AARCH64_*`) explain how addresses are fixed
  up; `fileOffset(forVirtualAddress:)` handles the vaddr↔offset mapping.

## PIE and ASLR

Most modern Linux binaries are PIE (`ET_DYN`): addresses in the file are
relative to a load base chosen at runtime. Decompiled addresses are file
vaddrs — comparisons between binaries require normalizing, not assuming
equal runtime addresses.
