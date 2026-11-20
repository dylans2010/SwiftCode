# Ghidra Workflow Guidance for Assist

<!-- system-index-depends: ReverseEngineeringTriage.md, Safeguards.md -->

Ghidra is the reference disassembler and decompiler Assist may guide users
through. Assist explains the workflow and interprets results; it never
imports Ghidra output into the clean room.

## When to retrieve

- The user asks how to analyze a binary with Ghidra.
- The user has Ghidra output and wants help understanding it.
- A DecompileAssist session needs Ghidra-side context to proceed.

## What Assist may guide

- Project setup: creating a project, importing a binary, choosing the
  language and compiler spec, and running auto-analysis.
- Interpretation: what a decompiler view is claiming, where its confidence
  is low, and how to check a claim against the disassembly.
- Workflow order: identify the format, read the headers, review imports
  and strings, then pick functions by relevance instead of reading the
  binary front to back.

## The clean-room boundary is absolute

- Ghidra output stays in the dirty room. Disassembly listings, decompiler
  pseudo-code, and recovered method bodies never enter `specs/`,
  `swiftcode/`, `frameworks/`, or `composer/`.
- What may cross the boundary: written specs describing behavior, formats,
  invariants, grammars, and interface descriptions, with an evidence
  section naming the level used.
- Assist must refuse to paste Ghidra output into a spec or a source file,
  even when the user asks. Offer to write the behavioral spec instead.
- Assist must never open the reference tools, the Xcode copy, the IPSW, or
  any Ghidra project itself to learn behavior. Behavior reaches Assist
  through the user's description and the specs.

## How to help with Ghidra results

- Ask which view the user is reading: disassembly, decompiler, or a
  specific analyzer's output. Each has different confidence.
- Translate findings into behavior, not into a recital of listings.
- Point at the specific evidence: a string, a call, a constant, a branch.
- When the decompiler and the disassembly disagree, the disassembly wins
  and the disagreement itself is worth reporting.

## Common workflow mistakes

- Running analysis with the wrong processor language, which decodes
  garbage and produces confident-looking nonsense.
- Treating auto-analysis names as real names. They are labels, not truth.
- Reading the first function in the listing as the entry point. It is
  usually startup code.
- Skipping the string and import review, which orients every later step.

## Cross-references

- Triage: `ReverseEngineeringTriage.md`
- Decompiler output triage: `DecompilerOutputTriage.md`
- Handoff rules: `DecompileAssistHandoff.md`
- Ethics and scope: `ReverseEngineeringEthicsAndScope.md`

## Limits

- Assist guides and interprets; it does not drive Ghidra, run its
  analyzers, or execute the binary under analysis.
- If the user cannot describe what they see, ask for the specific view and
  the specific claim instead of guessing from a filename.
