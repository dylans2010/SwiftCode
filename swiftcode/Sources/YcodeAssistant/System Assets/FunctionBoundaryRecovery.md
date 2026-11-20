# Function Boundary Recovery

<!-- system-index-depends: ControlFlowRecovery.md -->

A function boundary is a claim about where a function starts and ends.
Everything downstream (control flow, types, behavior) rests on that claim,
so Assist must know how boundaries are found and how they fail.

## When to retrieve

- The user asks where a function starts or ends.
- A DecompileAssist result seems to merge two functions or split one.
- A crash frame lands at an address that does not match any known symbol.

## How boundaries are established

- Symbols first: a symbol table entry names a function's start and size.
  This is the strongest evidence available.
- Metadata second: Objective-C method lists and Swift metadata name
  function entry points directly.
- Prologue patterns third: the conventional setup sequence at a function's
  start. Patterns suggest a boundary; they do not prove one.
- Call targets fourth: addresses that are called from elsewhere are
  likely function starts. An address nobody calls may still be a function,
  but the evidence is weaker.
- End detection: a return instruction, a jump outside the function, or
  the start of the next known function. Ends are harder than starts, and
  the uncertainty is usually at the tail.

## How boundaries fail

- Merged functions: two functions with no gap between them, where the
  analysis reads them as one.
- Split functions: one function with a distant block the analysis treats
  as separate, often after outlining or a cold path.
- Thunks and wrappers: tiny functions that only jump elsewhere. They are
  real functions, but their behavior lives at the target.
- Tail calls: a jump that replaces a call, which looks like a fall out of
  the function.
- Stripped binaries: no symbols, so every boundary is inferred, and
  inference near shared blocks is unreliable.

## How to report boundary claims

- State the evidence for the boundary: symbol, metadata, call target, or
  pattern, and its strength.
- Say what would change the boundary: a newly found call target, a
  symbol from another source, or a conflicting prologue.
- When two readings exist (one function or two), present both with their
  evidence instead of picking one silently.
- Flag tail calls and thunks explicitly; they are the usual source of
  "this function does nothing" confusion.

## Cross-references

- Control flow: `ControlFlowRecovery.md`
- Symbolication: `SymbolicationForAssist.md`
- ARM64 reading: `ARM64ReadingForAssist.md`
- x86-64 reading: `X86_64ReadingForAssist.md`

## Limits

- Boundary recovery is inference without symbols. Assist reports the
  boundary and its confidence together, never the boundary alone.
- A wrong boundary corrupts everything built on it. When the boundary is
  uncertain, every downstream claim inherits that uncertainty.
