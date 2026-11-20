# Symbolication for Assist

<!-- system-index-depends: ReverseEngineeringTriage.md -->

Symbolication turns addresses into names: a crash address becomes a
function, a file, and a line. Without symbols, Assist reads addresses;
with them, Assist reads a story. This asset covers how Assist reasons
about symbols and their absence.

## When to retrieve

- The user pastes a crash log or a stack trace with bare addresses.
- A binary is stripped and the user asks what can still be learned.
- Symbol lookup fails and the user asks why.

## What symbols are

- A symbol table maps addresses to names for functions, variables, and
  sometimes types. It is metadata, not code.
- Debug information (dSYM on Apple platforms) adds file and line mappings
  on top of symbols. A binary and its dSYM must match by UUID; a mismatched
  dSYM produces confident-looking wrong answers.
- Stripped binaries remove some or all of this metadata. Stripping is
  normal for shipped software, not evidence of wrongdoing.

## What Assist does with symbols

- Matches addresses to the nearest known symbol and reports the offset.
  An address inside a large function with a big offset is weak evidence
  about which part of the function ran.
- Checks that the symbol file matches the binary before trusting any
  mapping. UUID, architecture, and version must agree.
- Falls back gracefully: exports, Objective-C metadata, and Swift metadata
  can name functions a stripped symbol table cannot.
- Reports unsymbolicated frames as addresses, not as guesses. A guess
  presented as a name is worse than an honest address.

## Stripped binaries

- Say what is lost: function names, file and line info, and sometimes
  boundaries.
- Say what survives: exports, dynamic symbols, Objective-C class and
  selector metadata, Swift type metadata, strings, and constants.
- Adjust confidence everywhere downstream. Every claim built on an
  unsymbolicated frame is weaker than the same claim with symbols.

## Common mistakes

- Symbolicating with the wrong dSYM and reporting the result as fact.
- Treating the nearest symbol as the exact function when the offset is
  large.
- Assuming a stripped binary is unanalyzable. Much can still be learned
  from structure, strings, and metadata.
- Repeating a symbol name as if it proved intent. A name is a label; the
  behavior is the evidence.

## Cross-references

- Crash logs: `CrashLogAnalysisForAssist.md`
- Swift metadata: `SwiftMetadataRecovery.md`
- Objective-C metadata: `ObjCRuntimeRecovery.md`
- Function boundaries: `FunctionBoundaryRecovery.md`

## Limits

- Assist never fabricates a symbol. If no symbol exists for an address,
  the address is the answer.
- Symbol files may contain paths and names from the builder's machine;
  treat them as potentially sensitive and do not repeat them needlessly.
