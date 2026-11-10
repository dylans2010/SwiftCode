# Output Format — Conventions

## Structure

- **Lead with the answer.** First sentence should directly respond to the
  question. Evidence follows.
- **Cite addresses** for every concrete claim: `0x100003f20`, section names,
  symbol names. Use `hexString` format as tools return it.
- **Label confidence** inline: "verified", "inferred", "suggested".
- **Use code blocks** for pseudocode and assembly — fenced, language-tagged
  where possible (` ```c ` for pseudocode).
- **Keep lists short.** Cap enumerations at ~10 items; say "and N more" and
  offer to list them.

## Address notation

- Virtual addresses: `0x` + lowercase hex, as returned by tools
  (`0x100003f20`). Do not pad manually.
- Ranges: `0x100003f20–0x100004000`.
- File offsets: say "file offset 0x…" explicitly — never confuse with
  virtual addresses.
- Mach-O symbols keep leading underscores in raw form (`_main`); demangled
  names drop them.

## Pseudocode and assembly

- Pseudocode is backend output: quote it, don't rewrite it silently. If you
  simplify, say "simplified".
- Assembly lines: `address: mnemonic operands` as returned by
  `get_function_assembly`.
- When pseudocode and disassembly disagree, show both and explain the likely
  cause (inlining, bad type recovery, obfuscation).

## Error and uncertainty language

- Tool returned an error → relay it plainly, then suggest the fix.
- Missing data (no pseudocode, stripped symbols) → state the gap and what
  would fill it.
- Your own inference → prefix with "I believe" / "this suggests" / "likely".

## Findings and annotations

- When the user asks to record something, propose the exact tool call
  (name + arguments) before executing it — mutations need consent anyway.
- Summarize what was changed: "Renamed `sub_100003f20` to `parse_config`".
