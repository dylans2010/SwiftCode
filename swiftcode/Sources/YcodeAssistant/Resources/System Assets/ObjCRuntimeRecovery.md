# Objective-C Runtime Recovery

<!-- system-index-depends: MachOFileLayoutForAssist.md, TypeReconstruction.md -->

Objective-C binaries carry their class and method structure in the open:
classes, selectors, protocols, categories, and instance-variable layouts
are metadata, not inference. Assist reads this metadata to recover the
object model of a binary.

## When to retrieve

- The user asks what classes or methods a binary contains.
- A selector or a class name needs tracing to its implementation.
- Triage needs to know whether a binary is Objective-C, Swift, or mixed.

## What the runtime metadata offers

- Class lists: every class the binary defines, its superclass, and its
  metaclass. The hierarchy is a fact, not a guess.
- Method lists: selectors, implementations, and types for instance and
  class methods. A selector names the message; the method list gives its
  address.
- Protocols: declared protocols, their required and optional methods, and
  which classes adopt them.
- Categories: methods added to existing classes, with the category name
  and the class they extend. Categories can override, which matters for
  behavior.
- Instance-variable layouts: ivar names, types, and offsets. These
  constrain the object's memory shape.
- Property metadata: declared properties, their attributes, and their
  backing ivars where present.

## How to report runtime findings

- Lead with the class hierarchy and the classes relevant to the question.
  A full class dump is a reference, not an answer.
- For a method, give the selector, the class, and what the implementation
  does at the behavior level. The selector alone is not the behavior.
- Flag dynamic features explicitly: message forwarding, method
  swizzling, and runtime class creation mean the static picture is
  incomplete.
- Note categories separately. A method's behavior may come from a category
  the user did not expect.

## Common mistakes

- Treating a selector as a function name. Selectors are messages; the
  implementation is resolved at runtime.
- Ignoring categories and reporting only the class's own methods.
- Assuming a declared protocol method is implemented. Adoption declares
  intent; the method list proves it.
- Reading an ivar offset as a field type. The offset locates; the type
  encoding describes.

## Cross-references

- Type reconstruction: `TypeReconstruction.md`
- Swift metadata: `SwiftMetadataRecovery.md`
- Symbolication: `SymbolicationForAssist.md`

## Limits

- Runtime metadata describes the static class structure. Dynamic behavior
  (forwarding, swizzling, runtime-generated classes) needs observation,
  which Assist does not perform on untrusted binaries.
- Method bodies are behavior, not metadata. Their analysis belongs in
  DecompileAssist.
