# Reading ARM64 Disassembly Findings for Assist

<!-- system-index-depends: ReverseEngineeringTriage.md -->

ARM64 (AArch64) is the instruction set of Apple Silicon Macs and iOS
devices. Assist does not produce disassembly listings as answers; it reads
disassembly findings, usually from DecompileAssist, and explains what they
mean in plain language.

## When to retrieve

- A DecompileAssist result mentions ARM64 instructions, registers, or
  branches and the user wants an explanation.
- The user asks how a function behaves on Apple Silicon.
- Triage needs to judge whether an ARM64 finding is credible.

## Concepts Assist must get right

- Registers: general-purpose registers carry values and pointers; the
  stack pointer and frame pointer anchor the call frame; the link register
  holds the return address. A value in a register is evidence only for the
  moment it is read.
- Calling convention: arguments arrive in registers first, then on the
  stack; the return value leaves in a specific register. Misreading which
  register holds an argument is the most common explanation error.
- Branches: conditional branches choose paths; unconditional branches and
  calls transfer control. A branch target is a claim about control flow,
  not about what the target does.
- Loads and stores: the difference between reading a constant, reading
  from a table, and reading through a pointer. Each has different
  confidence attached.
- Arithmetic and comparison: flags record the result of a comparison for
  the branch that follows. The comparison and the branch must be read
  together; either alone misleads.
- Address computation: addresses are often built in steps from a base plus
  an offset. Report the final address and the steps, not just one step.

## How to explain findings

- Translate instructions into behavior: what value moves where, what is
  compared, and which path is taken.
- Never present a single instruction as proof of a function's purpose. A
  function's purpose comes from its whole body plus its callers.
- Say what is unknown: an unresolvable indirect branch, a computed target,
  or a value that arrives from outside the function.
- Keep the vocabulary at the behavior level. The user asked what the code
  does, not for a recital of mnemonics.

## Common misreadings

- Assuming a register still holds a value set many instructions earlier.
  Registers are reused constantly.
- Treating a branch to a shared block as a call to a separate function.
- Confusing the link register with a return value.
- Reading a 32-bit operation as if it preserved the full 64-bit register.

## Cross-references

- Authoritative ISA reference: `swiftcode/Sources/YcodeDecompiler/Resources/SystemAssets/DecompileAssist/ARM64.md`
- Control-flow recovery: `ControlFlowRecovery.md`
- Function boundaries: `FunctionBoundaryRecovery.md`

## Limits

- Assist explains findings; it does not generate disassembly listings or
  decompiler output. That work lives in DecompileAssist and stays out of
  the clean room.
- If the disassembly is truncated or the function boundaries are uncertain,
  say so and lower the confidence of every claim built on them.
