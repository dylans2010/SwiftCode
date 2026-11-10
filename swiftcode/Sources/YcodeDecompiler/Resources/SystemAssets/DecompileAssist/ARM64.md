# ARM64 Reference

ARM64 (AArch64) is the dominant mobile/desktop ISA: iOS devices, Apple
Silicon Macs, most Android phones, and growing server share.

## Instruction traits

- **Fixed 4-byte little-endian instructions.** No variable length; every
  instruction is exactly one 32-bit word. This makes linear disassembly
  reliable but means data-in-code must be detected explicitly.
- **31 general-purpose registers** `x0`–`x30` (64-bit) / `w0`–`w30` (32-bit
  views), plus `sp`, `xzr`/`wzr` (zero register), `pc`-relative addressing.
- **Link register `x30` (`lr`)** holds the return address; `bl` writes it,
  `ret` jumps to it. `blr`/`br` use register targets.
- **Conditional execution is rare** — most ARM64 code uses conditional
  *selects* (`csel`) and conditional branches (`b.eq`, `cbz`, `tbz`) rather
  than predicated instructions (unlike ARM32).
- **Load/store architecture**: all memory access goes through explicit
  `ldr`/`str`/`ldp`/`stp`; arithmetic can't touch memory.

## Common patterns to recognize

- `stp x29, x30, [sp, #-N]!` … `ldp x29, x30, [sp], #N` + `ret`: function
  prologue/epilogue (frame setup/teardown).
- `adrp x8, page` + `add x8, x8, offset` / `ldr x8, [x8, #off]`: materialize
  a 64-bit address — the ARM64 equivalent of RIP-relative addressing. Two
  instructions often combine to reference a global/string.
- `mov x0, …` before `bl`: first argument in `x0` (then `x1`–`x7`); return
  value in `x0`. `x8` is the indirect-result register for large structs.
- `cbz`/`cbnz`/`tbz`/`tbnz`: compare-and-branch (null checks, bit tests) —
  the idiomatic "if" in optimized code.
- `svc #0x80` (Linux) / `svc #0x80` with `x16` syscall number: system calls.

## ARM64e / pointer authentication (Apple)

- `pacibsp`/`paciasp` in prologues sign the return address; `autibsp`/
  `autiasp` verify before `retab`/`retaa`.
- Authenticated pointers use high bits for the signature — masks like
  `xpaci` strip them. Treat unexplained high bits on pointers as PAC
  signatures, not bugs.
- `blraa`/`braa` authenticate indirect branch targets (vtable calls,
  function pointers).

## Reading decompiled ARM64

- Pseudocode loses the register-level story: `adrp+add` pairs become plain
  address constants; `csel` becomes ternaries; `ldp/stp` pairs become
  struct copies.
- When pseudocode looks odd, check `get_function_assembly` — ARM64's
  regularity makes manual reading fast.
- Watch for `br`/`blr` with computed targets: switch statements and vtable
  dispatch. The CFG tool marks these as indirect branches.
