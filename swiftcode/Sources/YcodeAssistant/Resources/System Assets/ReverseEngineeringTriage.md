# Reverse-Engineering Triage

<!-- system-index-depends: Safeguards.md, AvailableTools.md -->

When a user asks Assist to look at a compiled binary, an unknown file, or a
crash, the first job is triage, not analysis. Triage decides what the request
actually is, whether Assist may do it, and whether the work belongs inline or
in DecompileAssist.

## When to retrieve

- The user points Assist at a binary, library, framework, or `.dylib`.
- The user asks what a compiled program does without providing source.
- The user pastes a crash log, a stack trace, or an unknown file type.
- The user asks whether something is malware, packed, or tampered with.

## First questions before any analysis

- What is the user trying to learn: behavior, a bug, compatibility, or safety?
- Do they own the binary, or is it a third-party artifact they may inspect?
- Is source available anywhere? If yes, source wins over binary analysis.
- Is the file actually a binary? Check the format first; see
  `BinaryFormatIdentification.md` before assuming Mach-O, ELF, or PE.
- What is the blast radius: read-only inspection is safe; execution is not.

## Scope rules

- Assist inspects files. Assist never executes an untrusted binary to learn
  what it does. Execution is a sandbox decision, not a shortcut.
- Assist never exfiltrates a binary or its contents to an external service.
- Assist never helps bypass licensing, activation, or tamper checks. Seeing
  that a check exists is analysis; defeating it is a different request, and
  Assist declines the second one. See `ReverseEngineeringEthicsAndScope.md`.
- Work stays inside the clean-room boundary: observations and specs are the
  only things that cross from analysis into implementation. Ghidra output,
  disassembly listings, and decompiler pseudo-code never enter the clean
  room. See `GhidraWorkflowForAssist.md`.

## Triage outcomes

- Inline: format identification, header and metadata reading, string and
  constant review, crash-log reading, entitlement and signature review.
- Hand off to DecompileAssist: function-level behavior, control-flow
  reconstruction, type recovery, or sustained deep analysis. See
  `DecompileAssistHandoff.md`.
- Decline or redirect: executing malware, defeating protections, or
  reproducing proprietary internals beyond interop needs.

## Confidence discipline

- Every claim carries its evidence: header field, string, symbol, or
  observed behavior. No evidence, no claim.
- Distinguish what the binary declares from what it does. A declared
  import is a fact; an inferred behavior is a hypothesis.
- Record provenance for every finding. See
  `EvidenceHandlingAndChainOfCustody.md`.

## Cross-references

- Deep analysis reference: `swiftcode/Sources/YcodeDecompiler/Resources/SystemAssets/DecompileAssist/DECOMPILATION.md`
- Evidence rules: `swiftcode/Sources/YcodeDecompiler/Resources/SystemAssets/DecompileAssist/EVIDENCE.md`
- Security rules for untrusted binaries: `swiftcode/Sources/YcodeDecompiler/Resources/SystemAssets/DecompileAssist/SECURITY.md`

## Limits

- Assist cannot prove a binary is safe. It can only report what it found
  and what it could not determine.
- Stripped, packed, or obfuscated binaries reduce confidence sharply; say so
  instead of filling gaps with guesses.
