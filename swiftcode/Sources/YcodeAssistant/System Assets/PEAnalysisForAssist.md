# PE Analysis for Assist

<!-- system-index-depends: ReverseEngineeringTriage.md -->

PE (Portable Executable) is the executable format on Windows: executables,
DLLs, drivers, and screensavers. Assist reads PE structure to triage
Windows binaries the same way it triages Mach-O and ELF.

## When to retrieve

- The user points Assist at a Windows `.exe`, `.dll`, or `.sys` file.
- A Windows binary fails to load, or a DLL dependency is in question.
- Cross-platform work needs the PE side of a format comparison.

## What Assist reads first

- The DOS header and stub: mostly historical, but the PE offset it points
  to must be valid before anything else can be read.
- The COFF header: machine type, number of sections, timestamp, and
  characteristics. The machine type decides whether the binary can run on
  the target at all.
- The optional header: entry point, image base, subsystem (console, GUI,
  driver), DLL characteristics, and the data-directory table. The
  subsystem alone explains many "nothing happens when I run it" reports.
- The data directories: imports, exports, resources, relocations, debug
  info, TLS, and the certificate table. Each directory is either present
  with a size or absent; an absent directory is itself a finding.
- The section table: code, initialized data, uninitialized data, and
  resources, with their permissions. Writable-and-executable sections
  deserve a flag.
- The import table: which DLLs and functions the binary declares. The
  export table: what a DLL offers to its callers.

## How to report PE findings

- Lead with machine type, subsystem, and file kind (EXE, DLL, driver).
- Separate declared imports from delay-loaded imports; the second group
  may never load.
- For resources, summarize what kinds exist (icons, manifests, version
  info) rather than dumping their contents.
- Report the certificate table's presence, not its validity; validity
  needs a signature check, not a glance.

## Common misreadings

- Assuming a DLL with no exports is broken. Some DLLs are loaded for
  their side effects or through ordinals.
- Treating the timestamp as a build date. It can be forged, zeroed, or
  inherited from a template.
- Reading the image base as the load address. Relocation moves the image;
  the base is only the preferred address.
- Confusing the subsystem with the file type: a GUI executable and a
  console executable differ in startup behavior, not in format.

## Cross-references

- Authoritative format reference: `swiftcode/Sources/YcodeDecompiler/Resources/SystemAssets/DecompileAssist/PE.md`
- Format identification: `BinaryFormatIdentification.md`
- Import and export analysis: `ImportAndExportAnalysis.md`

## Limits

- PE reading is static. Runtime loading and side-by-side assembly
  resolution need dynamic observation, which Assist does not perform on
  untrusted binaries.
- Never execute a Windows binary to learn what it does, and never forward
  it to an external service for analysis.
