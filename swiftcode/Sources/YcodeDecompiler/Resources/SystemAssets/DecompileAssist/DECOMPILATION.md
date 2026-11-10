# Decompilation — Core Concepts

## What decompilation is

Compilation is many-to-one: source constructs collapse into machine code, and
information is destroyed. Decompilation is the inverse *approximation*:
engines lift machine code into an intermediate representation (often called
p-code or microcode), recover functions and control flow, then render
C-like pseudocode.

Key consequences you must internalize:

- **Pseudocode is not source.** Variable names, types, and structure are
  *inferred*. `v1`, `a1`, `param_1` are placeholders, not the original names.
- **Types are guesses.** A 32-bit value used as an index might have been a
  pointer, an enum, or an int. Type recovery is heuristic.
- **Control flow may be approximate.** Obfuscated binaries, computed jumps,
  and exception-based control flow produce graphs that are structurally
  valid but semantically misleading.
- **Inlined code blurs boundaries.** What looks like one function may be
  several inlined callees; what looks like a call may be a tail-call
  optimization.

## The pipeline you are looking at

1. **Parse** — read the container (Mach-O/ELF/PE), segments, sections,
   symbols, imports, exports, strings.
2. **Discover functions** — entry points, symbol table, function-start
   tables, call-graph reachability, heuristics.
3. **Disassemble** — decode instructions per function (cached in the store).
4. **Analyze** — build xrefs, call graphs, CFGs, recover types.
5. **Decompile** — backend produces pseudocode per function (cached).

Each stage can fail partially. If `has_pseudocode` is false for a function,
no decompiler backend has produced output for it yet — `get_function_pseudocode`
will attempt it on demand and may fail if no backend supports the slice.

## Reading pseudocode critically

- Check `provenance`: `formatParser`, `symbolTable`, `engine`, `heuristic`,
  `user`, `aiSuggestion`. Engine output is the strongest evidence; AI
  suggestions are the weakest.
- `warnings` in a `DecompilationResult` flag backend uncertainty — surface
  them to the user.
- Pseudocode that references raw addresses (`DAT_100003f20`, `&UNK_...`) is
  pointing at data the engine couldn't name. Use `navigate_to_address` or
  `inspect_memory_region` to investigate.
- Register/stack artifacts (`in_FS_OFFSET`, stack canaries, red zones) are
  ABI noise, not logic.

## Why source isn't recoverable

Even a perfect decompiler cannot restore: original variable names (unless in
symbols/debug info), comments, preprocessor structure, source formatting,
templates/generics instantiation details, and exact types where the ABI
erased them. Say this plainly when users ask "can I get the source back?"
