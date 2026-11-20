# Binary Format Identification

<!-- system-index-depends: ReverseEngineeringTriage.md -->

Before any analysis, Assist must know what kind of file it is looking at.
Format identification is the first triage step, and getting it wrong
invalidates everything after it.

## When to retrieve

- The user hands Assist an unknown file.
- A file's extension disagrees with its contents.
- Triage needs to choose between Mach-O, ELF, PE, or something else.

## How identification works

- Magic bytes first: the first few bytes name the format. Mach-O, ELF,
  PE, and fat binaries each have distinct markers. Read the bytes; do
  not trust the extension.
- Fat binaries second: a single file can hold several architectures. Name
  each slice and its architecture before analyzing any one of them.
- Structure third: once the magic matches, confirm the header parses.
  A matching magic with a corrupt header is a damaged file, not a valid
  binary of that format.
- Content fourth: archives, disk images, and installers can contain
  binaries without being binaries themselves. Name the container and the
  contents separately.

## Formats Assist distinguishes

- Mach-O: Apple platforms, including fat (multi-architecture) variants.
- ELF: Linux and Unix-like systems, 32-bit and 64-bit.
- PE: Windows executables, DLLs, and drivers.
- Archives and bundles: zip, tar, disk images, app bundles, and IPSW
  files, which contain binaries rather than being one.
- Plain data: text, images, and plists that are sometimes mistaken for
  binaries.

## How to report identification

- Lead with the format, architecture list, and file kind, in one line.
- Say what the identification rests on: the magic bytes and the header
  check.
- If the file is a container, list what it contains at the top level
  before analyzing any inner file.
- If identification fails, say so and describe what the first bytes
  actually look like, without guessing a format.

## Common mistakes

- Trusting the file extension. Extensions lie; magic bytes do not.
- Analyzing one slice of a fat binary as if it were the whole file.
- Treating an app bundle as a binary. The binary is inside the bundle.
- Calling a static library an executable. It has no entry point and
  cannot run alone.

## Cross-references

- Mach-O layout: `MachOFileLayoutForAssist.md`
- ELF analysis: `ELFAnalysisForAssist.md`
- PE analysis: `PEAnalysisForAssist.md`
- IPSW-adjacent analysis: `IPSWAdjacentAnalysis.md`

## Limits

- Identification names the format; it says nothing about safety,
  behavior, or trustworthiness. Those need the rest of triage.
- An unrecognized file is an unrecognized file. Do not force it into the
  nearest familiar format.
