# Decompiler Output Triage

<!-- system-index-depends: ReverseEngineeringTriage.md -->

Decompiler output is a reconstruction, not a transcript. It guesses at
source-level structure from machine code, and some guesses are wrong.
Assist triages that output: what to trust, what to check, and what to
discard.

## When to retrieve

- The user pastes or describes decompiler output and asks what it means.
- A DecompileAssist result needs a confidence check before it is used.
- A reconstruction is being considered as the basis for a spec or a fix.

## What to trust first

- Control flow the disassembly confirms: branches, calls, and returns that
  match the underlying instructions.
- Constants and strings that appear verbatim in the binary.
- Imported calls: a call to a known library function is strong evidence
  about intent.
- Types that come from metadata (Swift or Objective-C) rather than from
  inference alone.

## What to check before relying on it

- Variable names: the decompiler invents them. A suggestive name is not
  evidence about purpose.
- Recovered types: inferred structs and signatures are hypotheses until
  metadata or usage confirms them.
- Control-flow simplifications: loops and switches the decompiler merged
  may hide branches the disassembly still shows.
- Arithmetic: strength-reduced or vectorized arithmetic may look nothing
  like the source operation. Check the disassembly before concluding what
  a computation does.

## How to report triage

- Separate confirmed, plausible, and speculative claims, and label each.
- Cite the evidence for each claim: the instruction pattern, the string,
  the metadata entry, or the call target.
- When two readings are possible, present both with their evidence instead
  of picking the prettier one.
- Never present decompiler output as source code. It is a hypothesis about
  source code.

## Common mistakes

- Quoting a decompiler variable name as if it were the original name.
- Treating a reconstructed function signature as the real ABI.
- Assuming the decompiler saw the whole function when it warns about
  missing blocks.
- Using decompiler output as a spec without the evidence section that
  justifies each claim.

## Cross-references

- Core concepts: `swiftcode/Sources/YcodeDecompiler/Resources/SystemAssets/DecompileAssist/DECOMPILATION.md`
- Evidence rules: `swiftcode/Sources/YcodeDecompiler/Resources/SystemAssets/DecompileAssist/EVIDENCE.md`
- Type reconstruction: `TypeReconstruction.md`
- Control-flow recovery: `ControlFlowRecovery.md`

## Limits

- Decompiler output never enters the clean room as code-shaped text. Only
  behavioral specs derived from it may cross, with evidence levels noted.
- If the output is truncated or the analysis is incomplete, confidence
  drops across the board. Say so.
