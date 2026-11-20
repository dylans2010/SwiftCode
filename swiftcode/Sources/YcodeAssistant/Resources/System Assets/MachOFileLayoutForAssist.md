# Mach-O File Layout for Assist

<!-- system-index-depends: ReverseEngineeringTriage.md, Safeguards.md -->

Mach-O is the executable format for macOS, iOS, and other Apple platforms.
Assist reads its layout to answer structural questions: what kind of file
this is, what architectures it covers, and where its code and data live.

## When to retrieve

- The user asks what a Mach-O file is or what it contains.
- Triage needs the file type, architecture list, or segment map.
- Another finding (a missing symbol, an odd load command) needs layout
  context before it can be interpreted.

## What Assist reads first

- The header: magic, CPU type and subtype, file type (executable, dynamic
  library, bundle, object, core), number of load commands, and flags.
- The fat header when present: which architectures are bundled, and which
  slice Assist is actually describing. Never describe a fat binary as if it
  had one architecture.
- The segment map: which segments exist, their addresses and sizes, and
  their protections. Executable segments, writable segments, and the
  linkedit segment each answer different questions.
- The section map inside each segment: code, constant data, mutable data,
  and metadata live in different sections, and a finding means something
  different depending on where it sits.

## How to report layout

- Lead with file type and architectures. Everything else is detail.
- Give addresses as file offsets and virtual addresses together when both
  matter; a bare address without saying which kind it is causes confusion.
- Distinguish the file on disk from the image in memory. Offsets shift when
  the image is loaded; say which view a number belongs to.
- Flag anomalies instead of smoothing them over: overlapping segments,
  truncated load commands, or a header that disagrees with the file size.

## What layout alone cannot tell Assist

- Layout says where things are, not what they do. Behavior needs
  disassembly or decompilation, which belongs in DecompileAssist.
- A segment being writable does not prove it is written at runtime; it only
  permits it.
- Absence of a section is weak evidence. Stripped binaries omit metadata
  that a fuller build would carry.

## Cross-references

- Authoritative format reference: `swiftcode/Sources/YcodeDecompiler/Resources/SystemAssets/DecompileAssist/MACHO.md`
- Load-command detail: `MachOLoadCommands.md`
- Segment and section roles: `SectionAndSegmentTriage.md`
- Shared-cache and loading: `DyldAndSharedCache.md`

## Limits

- Never reproduce raw header dumps as the answer. Summarize the layout in
  plain language and cite the fields that support each claim.
- If the header is corrupt or truncated, stop and say so; do not guess the
  layout from the filename or extension.
