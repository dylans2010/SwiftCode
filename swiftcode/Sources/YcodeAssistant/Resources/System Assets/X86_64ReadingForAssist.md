# Reading x86-64 Disassembly Findings for Assist

<!-- system-index-depends: ReverseEngineeringTriage.md -->

x86-64 powers Intel and AMD Macs, Windows, Linux, and most servers. It is a
variable-length CISC architecture, so reading its findings needs more care
than a fixed-width ISA: instruction boundaries are themselves a finding.

## When to retrieve

- A DecompileAssist result mentions x86-64 instructions and the user wants
  an explanation.
- The user asks about behavior in an Intel Mac binary or a Linux binary.
- Triage needs to judge whether an x86-64 finding is credible.

## Concepts Assist must get right

- Variable-length encoding: instructions are one to fifteen bytes, so a
  wrong starting offset decodes garbage. If the decode looks implausible,
  the boundary is probably wrong, not the code.
- Registers and their widths: a 64-bit register has 32-bit, 16-bit, and
  8-bit views, and writing a 32-bit view zeroes the upper half. Report the
  width that was actually written.
- Calling convention: the first arguments arrive in registers, the rest on
  the stack; the caller cleans the stack. System V and the Windows
  convention differ, so name which one applies before interpreting any
  argument.
- Flags: comparisons set flags that the next conditional jump consumes.
  Read the comparison and the jump as one unit.
- Addressing modes: base plus index plus scale plus displacement. A memory
  operand is a computed address, and the computation is part of the claim.
- Stack discipline: pushes, pops, and the frame pointer. A misaligned
  stack or an unbalanced push is a signal, not noise.
- Vector and floating-point registers: separate register files with their
  own conventions. Do not mix them into integer-argument reasoning.

## How to explain findings

- Translate into behavior: what is loaded, what is compared, what is
  stored, and where control goes.
- Name the calling convention before naming any argument.
- Flag indirect control flow explicitly: a jump through a register or a
  table has a target Assist cannot state with certainty.
- Keep explanations at the behavior level; mnemonics support the claim,
  they are not the claim.

## Common misreadings

- Decoding from a wrong offset and treating the result as real code.
- Applying the System V convention to a Windows binary or vice versa.
- Assuming a 32-bit write preserves the upper 32 bits of the register.
- Treating a jump-table entry as a direct call target.

## Cross-references

- Authoritative ISA reference: `swiftcode/Sources/YcodeDecompiler/Resources/SystemAssets/DecompileAssist/X86_64.md`
- Control-flow recovery: `ControlFlowRecovery.md`
- Function boundaries: `FunctionBoundaryRecovery.md`

## Limits

- Assist explains findings; it does not generate disassembly listings.
  That work lives in DecompileAssist and stays out of the clean room.
- Indirect branches and computed targets cap confidence. Say so plainly.
