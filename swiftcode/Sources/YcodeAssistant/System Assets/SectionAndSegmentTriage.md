# Section and Segment Triage

<!-- system-index-depends: MachOFileLayoutForAssist.md -->

Segments are the loader's units; sections are the linker's units. Assist
reads both to know where code, constants, and mutable state live, and what
protections each region carries.

## When to retrieve

- The user asks where something lives in a binary.
- A finding needs its location interpreted: code, data, or metadata.
- A protection question arises: writable, executable, or both.

## Mach-O landmarks Assist uses

- Executable code lives in the text segment; constant data sits nearby
  but is not executable.
- Mutable data lives in the data segment; it is writable and not
  executable.
- Linkedit holds metadata: symbol tables, string tables, and signature
  data. It is not code and not ordinary data.
- The page-zero segment reserves the null page. Its presence is normal;
  its absence is a finding.
- Section names refine the picture: code, stubs, constant strings, and
  metadata each have their own sections, and a finding's section changes
  its meaning.

## What to check in any segment or section

- Permissions: readable, writable, executable. A region that is both
  writable and executable deserves a flag and an explanation.
- Size versus content: a section that is suspiciously large, empty, or
  overlapping its neighbor.
- Alignment and placement: whether the section sits where the format
  expects it.
- Presence: which expected sections exist and which are absent. Absence
  of a metadata section in a stripped binary is expected; absence of a
  code section is not.

## How to report locations

- Name the segment and section together. Either alone is ambiguous.
- Give both the file offset and the virtual address when both matter, and
  say which is which.
- Explain what the location implies: a string in a constant section is
  data; the same bytes in a code section would be suspicious.

## Common mistakes

- Confusing segments with sections. A segment is mapped; a section is
  organized. A question about loading is a segment question; a question
  about content is a section question.
- Treating section names as guarantees. Names are conventions; the
  segment's protections are the enforcement.
- Assuming a writable section is written at runtime. Permission is not
  behavior.

## Cross-references

- Mach-O layout: `MachOFileLayoutForAssist.md`
- ELF analysis: `ELFAnalysisForAssist.md`
- PE analysis: `PEAnalysisForAssist.md`

## Limits

- Section and segment maps are static. Runtime protections can change
  (memory can be remapped), and Assist must not claim a static permission
  is a runtime guarantee.
