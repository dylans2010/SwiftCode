# Swift Metadata Recovery

<!-- system-index-depends: MachOFileLayoutForAssist.md, TypeReconstruction.md -->

Swift binaries carry rich metadata: type names, protocol conformances,
field layouts, and mangled symbol names. Assist reads this metadata to
recover structure that stripped C binaries would have lost.

## When to retrieve

- The user asks what Swift types a binary contains.
- A Swift symbol or mangled name needs demangling and explanation.
- Triage needs to know whether a binary is Swift, Objective-C, or mixed.

## What the metadata offers

- Type metadata: nominal types (structs, classes, enums) with their
  names, module, and field layouts where available.
- Protocol conformances: which types conform to which protocols, and where
  the witness tables live. A conformance is strong evidence about a type's
  role.
- Mangled names: encoded type, function, and symbol names. Demangling
  turns them into readable signatures. A mangled name is a fact about the
  symbol; the demangled form is its reading.
- Field offsets and type layouts: how a struct's fields are arranged in
  memory, which constrains reconstruction.
- Generic signatures: which generic parameters a type or function carries,
  and what constrains them.
- Reflection metadata: the data the runtime uses for casting, printing,
  and encoding. It names types the code actually uses.

## How to report metadata findings

- Lead with module and type names, demangled and readable. Quote the
  mangled form once for searchability, then use the readable form.
- Separate declared types from used types. A binary can carry metadata
  for types it never instantiates.
- Say what is missing: metadata can be stripped or minimized, and a
  release build may carry less than a debug build.
- Connect types to behavior: a type matters because of what its methods
  do and where it is used, not because it exists.

## Common mistakes

- Treating a mangled name as the full story. The name gives the signature;
  the body gives the behavior.
- Assuming every Swift type in the metadata is reachable. Dead types
  survive in metadata.
- Confusing a protocol conformance with a class hierarchy. Swift
  protocols are not inheritance.
- Reading a generic signature as a concrete type. The parameters must be
  resolved at each use site.

## Cross-references

- Type reconstruction: `TypeReconstruction.md`
- Objective-C metadata: `ObjCRuntimeRecovery.md`
- Symbolication: `SymbolicationForAssist.md`

## Limits

- Metadata describes types, not behavior. A type's methods still need
  analysis to understand.
- Demangled names can be long and deeply nested. Summarize the meaningful
  part and keep the full form available, not in the lead sentence.
