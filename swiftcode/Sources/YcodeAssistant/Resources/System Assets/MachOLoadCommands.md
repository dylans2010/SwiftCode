# Mach-O Load Commands

<!-- system-index-depends: MachOFileLayoutForAssist.md -->

Load commands are the Mach-O header's instruction list to the loader. Each
one declares something the binary needs or offers: an entry point, a
library, a search path, encryption state, or a signature. Assist reads them
to understand what a binary expects from its environment.

## When to retrieve

- The user asks what a binary depends on or how it starts.
- A launch failure, missing-library error, or dyld complaint needs context.
- Triage found an unusual load command and needs to know what it means.

## Commands Assist checks first

- Entry point: where execution begins, and whether the binary declares one
  at all. A library has none; an executable must have one.
- Library loads: which dynamic libraries the binary links, and whether each
  is a system library, a framework, or a bundled dependency.
- Install names and identifiers: what a library calls itself, which matters
  when a load fails because the expected path does not match.
- Search paths: run paths and loader paths that decide where libraries are
  found. A relative or user-writable search path is a finding, not trivia.
- Encryption info: whether the executable segment is encrypted, which is
  normal for App Store binaries and a red flag for tampering analysis.
- Code signature: where the signature blob lives, and whether one is
  present at all. Presence is not validity; see
  `EntitlementsAndCodeSigningAnalysis.md`.
- Version and platform minimums: which OS versions the binary targets and
  which SDK built it. Mismatches here explain many launch failures.
- Thread and entry state: the initial thread state the loader sets up.

## How to report them

- Group by purpose: startup, dependencies, paths, security, versioning.
- For each library, say whether it is present on the system, bundled, or
  missing. A missing system library and a missing bundled library are
  different problems with different fixes.
- Quote the command's declared values, not a paraphrase that loses the
  exact path or version.
- Flag weak or missing entries: an executable with no entry point, a
  library with no install name, or a signature command pointing nowhere.

## Common misreadings

- A load command listing a library does not prove the library is used at
  runtime. Lazy binding means some imports may never resolve.
- A search path that looks suspicious may be legitimate for a developer
  build. Check the binary's origin before calling it a finding.
- The number of load commands is a header field, not a guarantee; a
  truncated file can declare more commands than it contains.

## Cross-references

- Format reference: `swiftcode/Sources/YcodeDecompiler/Resources/SystemAssets/DecompileAssist/MACHO.md`
- Library loading at runtime: `DyldAndSharedCache.md`
- Import and export analysis: `ImportAndExportAnalysis.md`

## Limits

- Load commands describe intent at load time. Runtime behavior, including
  libraries loaded later, needs dynamic observation, which Assist does not
  perform on untrusted binaries.
