# String and Constant Analysis

<!-- system-index-depends: ReverseEngineeringTriage.md -->

Strings and constants are the most readable part of a binary. They name
features, endpoints, file paths, error messages, and keys. Assist reads
them to orient an investigation before any deeper analysis begins.

## When to retrieve

- The user asks what a binary does and no source is available.
- A specific string, URL, path, or error message needs tracing to its use.
- Triage needs a quick orientation pass over an unknown binary.

## What Assist looks for

- User-facing strings: UI text, error messages, and prompts. These name
  features in the user's own language.
- Paths and filenames: configuration locations, bundled resources, and
  expected directories.
- URLs and network identifiers: endpoints, hosts, and schemes the binary
  may contact. A string is a declaration, not proof of contact.
- Identifiers: bundle IDs, team IDs, keys, and format markers.
- Format strings and templates: how the binary builds messages, which
  hints at its logging and error paths.
- Constants: magic numbers, version markers, limits, and table values that
  pin down behavior or protocol versions.

## How to report strings

- Group by purpose, not by address order: interface, network, filesystem,
  diagnostics, identifiers.
- Quote strings exactly. A paraphrase loses the detail that makes a string
  searchable.
- Say where each string lives when it matters: a string in a constant
  section is data; a string built at runtime may not appear at all.
- Flag strings that look sensitive (tokens, passwords, keys) without
  repeating their values. Report their presence and location, never the
  secret itself.

## Common mistakes

- Treating every string as live code. Binaries carry dead strings from
  libraries, templates, and old features.
- Assuming a URL string means the binary contacts that host. It may be a
  default, a fallback, or dead code.
- Reading a string out of context: the same error text can serve many call
  sites.
- Missing strings that are encoded, split, or built at runtime. Absence
  from a string table proves nothing about runtime behavior.

## Cross-references

- Binary diffing: `BinaryDiffing.md`
- Data-flow reasoning: `DataFlowAndTaintReasoning.md`
- Evidence handling: `EvidenceHandlingAndChainOfCustody.md`

## Limits

- Strings orient; they do not prove behavior. A string's use must be
  confirmed by the code that references it, which usually belongs in
  DecompileAssist.
- Never repeat secrets found in a binary. Report their presence, kind, and
  location only, and advise rotation if they look like live credentials.
