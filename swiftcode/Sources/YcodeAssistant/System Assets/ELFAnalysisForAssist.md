# ELF Analysis for Assist

<!-- system-index-depends: ReverseEngineeringTriage.md -->

ELF is the executable format on Linux and most Unix-like systems. Assist
reads ELF structure to answer the same triage questions it asks of Mach-O:
what kind of file this is, what it needs, and where its code and data live.

## When to retrieve

- The user points Assist at a Linux binary, shared object, or core dump.
- A Linux build fails to run, load, or link, and the binary is suspect.
- Cross-platform work needs the ELF side of a format comparison.

## What Assist reads first

- The ELF header: class (32-bit or 64-bit), byte order, machine type,
  file type (executable, shared object, relocatable, core), and entry
  point. A mismatch here explains most "cannot execute" failures.
- Program headers: which segments the loader maps, their permissions, and
  the interpreter path for dynamic executables. A missing or wrong
  interpreter is a common launch failure.
- Section headers: named sections for code, data, symbols, relocations,
  and notes. Sections are the linker's view; segments are the loader's
  view. Both matter, for different questions.
- The dynamic section: needed libraries, run paths, symbol tables, and
  relocation tables. This is where dependency questions get answered.
- Symbol tables: defined and undefined symbols, their binding, and their
  visibility. A stripped binary has little or none of this.

## How to report ELF findings

- Lead with class, machine, file type, and entry point.
- Separate static facts (what the file declares) from runtime facts (what
  the loader will actually do).
- For each needed library, say whether it resolves on the target system.
- Note stripped status early: it changes what every later claim can rest
  on.

## Common misreadings

- Confusing sections with segments. A section can exist without being
  loaded, and a segment can contain parts of several sections.
- Assuming the entry point is `main`. It is the start address the loader
  jumps to, which is usually startup code, not the program's `main`.
- Treating an undefined symbol as missing. Undefined symbols are expected;
  they resolve from libraries at load time.
- Reading a 32-bit header as 64-bit, or the wrong byte order, and then
  reporting nonsense offsets as findings.

## Cross-references

- Authoritative format reference: `swiftcode/Sources/YcodeDecompiler/Resources/SystemAssets/DecompileAssist/ELF.md`
- Format identification: `BinaryFormatIdentification.md`
- Import and export analysis: `ImportAndExportAnalysis.md`

## Limits

- ELF reading is static. Runtime loading, lazy binding, and address layout
  need dynamic observation, which Assist does not perform on untrusted
  binaries.
- Core dumps contain memory, not just code; treat their contents as
  potentially sensitive and never repeat secrets found in them.
