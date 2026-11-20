# Type Reconstruction

<!-- system-index-depends: DecompilerOutputTriage.md -->

Type reconstruction guesses the shapes of data a binary manipulates:
structs, enums, arrays, and pointers. It is inference, and Assist must
treat it as inference, with confidence attached to every claim.

## When to retrieve

- The user asks what data structure a binary uses.
- A DecompileAssist result proposes a struct or a signature and it needs
  a check.
- A crash or a parsing bug points at a misread data layout.

## Where type evidence comes from

- Metadata first: Swift type metadata and Objective-C runtime info name
  real types. Metadata-backed types are the strongest claims available.
- Usage second: how memory is read and written. Consistent field offsets
  and sizes suggest a struct; inconsistent access suggests a union, a
  buffer, or a wrong boundary.
- Size and alignment: the total size a value occupies, and the alignment
  its accesses require, constrain every candidate shape.
- Calls third: the functions a value is passed to, and how they use it,
  narrow its kind.
- Strings and constants: a field that always holds a small integer near a
  known set of values may be an enum; a field holding a pointer to text
  is likely a string reference.

## How to report a reconstructed type

- Give the proposed layout with a confidence per field, not a single
  confidence for the whole type.
- State the evidence for each field: the offset, the access size, and the
  usage that supports the guess.
- Name the alternatives: where a field could be two types, say so and say
  what would decide between them.
- Mark inferred names as invented. A reconstructed type's field names are
  labels Assist chose, not the original names.

## Common mistakes

- Treating an inferred struct as the real struct. It is a model that fits
  the evidence so far.
- Assuming a zero-initialized field is a separate field rather than
  padding or a different type's tail.
- Reading a pointer as the pointed-to value, or a value as a pointer.
- Forcing a single type onto memory that serves two purposes at different
  times.

## Cross-references

- Core concepts: `swiftcode/Sources/YcodeDecompiler/Resources/SystemAssets/DecompileAssist/DECOMPILATION.md`
- Swift metadata: `SwiftMetadataRecovery.md`
- Objective-C metadata: `ObjCRuntimeRecovery.md`
- Decompiler triage: `DecompilerOutputTriage.md`

## Limits

- Without metadata, type reconstruction is bounded by what the code's
  accesses reveal. Unaccessed fields are unknown, not absent.
- Reconstructed types never enter the clean room as source. Only a
  behavioral spec describing the layout's observable effects may cross.
