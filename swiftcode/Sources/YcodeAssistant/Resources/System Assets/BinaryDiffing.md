# Binary Diffing

<!-- system-index-depends: ReverseEngineeringTriage.md, StringAndConstantAnalysis.md -->

Binary diffing compares two builds of the same program to find what
changed. It is how Assist answers "what did this update do" and "is this
patch what it claims to be" without source access.

## When to retrieve

- The user asks what changed between two versions of a binary.
- A patch or update needs verification before it is trusted.
- A regression appeared in a new build and the change set is unknown.

## What to compare, in order

- Identity first: format, architecture, file type, and version metadata.
  Different architectures or a rebuilt-from-scratch binary make byte-level
  comparison meaningless.
- Structure second: segments, sections, load commands, imports, and
  exports. A new import or a removed export is a high-signal change.
- Strings and constants third: new strings often name new features,
  endpoints, or error paths. See `StringAndConstantAnalysis.md`.
- Function sets fourth: added, removed, and changed functions, by size and
  by symbol where symbols exist.
- Behavior last: what the changed functions do, which needs deeper analysis
  and usually belongs in DecompileAssist.

## How to report a diff

- Lead with the shape of the change: mostly identical, a small patch, or a
  substantial rebuild.
- Group changes by kind: added, removed, modified. Do not list raw
  addresses without saying what lives there.
- Distinguish meaningful changes from noise: timestamps, build IDs,
  ordering changes, and re-linked addresses are expected between builds.
- Say what the diff cannot show: behavior of unchanged-looking code that
  calls changed code, and runtime configuration that lives outside the
  binary.

## Common mistakes

- Diffing binaries built with different compilers or optimization levels
  and treating every difference as intentional.
- Diffing different architectures and reporting the format differences as
  feature changes.
- Treating an added string as proof of an added feature. Strings can be
  dead, diagnostic, or shared.
- Ignoring the build ID: two files with the same version string can be
  different builds.

## Cross-references

- String analysis: `StringAndConstantAnalysis.md`
- Patching safety: `BinaryPatchingSafety.md`
- Evidence handling: `EvidenceHandlingAndChainOfCustody.md`

## Limits

- Diffing shows what changed in the file, not why. Intent needs context
  from release notes, the vendor, or the surrounding system.
- Packed or encrypted binaries diff as noise. Say so instead of reporting
  the noise as findings.
