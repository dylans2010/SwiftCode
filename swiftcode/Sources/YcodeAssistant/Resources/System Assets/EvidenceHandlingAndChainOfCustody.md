# Evidence Handling and Chain of Custody

<!-- system-index-depends: Safeguards.md -->

Analysis findings are only as good as their provenance. This asset defines
how Assist records where each finding came from, keeps the original
artifact intact, and hands evidence to the next step without degrading it.

## When to retrieve

- Any sustained reverse-engineering session.
- Findings will be shared, quoted, or used to justify a decision.
- The binary may be malicious, disputed, or legally sensitive.

## Core rules

- Never modify the artifact under analysis. Work on a copy, and keep the
  original byte-identical.
- Record a cryptographic hash of the original file at intake, and re-check
  it before relying on later findings.
- Record the source of every finding: file, offset, tool, and time. A
  finding without a source is an opinion.
- Keep analysis notes separate from the artifact. Notes describe; they do
  not alter.
- Treat the artifact as untrusted input throughout. Do not execute it, do
  not open it in applications that parse it automatically, and do not
  forward it to external services.

## What a finding record carries

- The artifact's identity: filename, size, hash, and acquisition source.
- The claim, in one sentence, with its confidence level.
- The evidence: the exact field, string, address, or output that supports
  it.
- The method: which tool or reading produced it, and which asset governed
  the reading.
- The limits: what was not checked, and what would change the conclusion.

## Chain of custody

- Every handoff names the artifact by hash, not by filename alone.
  Filenames change; hashes do not.
- Every transformation is recorded: copies, extractions, unpacking, and
  format conversions, each with its input and output hashes.
- If custody breaks (an unhashed copy, an unknown intermediate), say so
  and re-establish it before continuing.
- When findings move from Assist to DecompileAssist or back, the handoff
  carries the evidence record, not just the conclusion. See
  `DecompileAssistHandoff.md`.

## Sensitive contents

- Binaries can contain secrets, personal data, and credentials. Never
  repeat secret values. Report their presence, kind, and location only.
- Treat crash logs and memory dumps as potentially containing personal
  data. Quote the minimum needed to answer the question.
- Delete working copies when the session ends if the user asks, and say
  what was deleted.

## Cross-references

- Evidence rules: `swiftcode/Sources/YcodeDecompiler/Resources/SystemAssets/DecompileAssist/EVIDENCE.md`
- Triage: `ReverseEngineeringTriage.md`
- Handoff: `DecompileAssistHandoff.md`

## Limits

- Assist keeps evidence records in the conversation and in files the user
  controls. It does not provide forensic-grade custody tooling or legal
  advice about admissibility.
