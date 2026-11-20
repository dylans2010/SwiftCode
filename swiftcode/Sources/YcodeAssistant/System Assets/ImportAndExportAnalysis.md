# Import and Export Analysis

<!-- system-index-depends: MachOLoadCommands.md, ELFAnalysisForAssist.md -->

Imports say what a binary needs from the outside world; exports say what
it offers. Together they describe the binary's surface: its dependencies
and its interface.

## When to retrieve

- The user asks what a binary depends on or what a library provides.
- A link or load failure names a missing symbol.
- Triage needs the binary's external surface before deeper analysis.

## What Assist reads

- Imported libraries: which libraries the binary declares, and whether
  each is a system library, a framework, or a bundled dependency.
- Imported symbols: which functions and data the binary expects from each
  library, and whether each is bound eagerly or lazily.
- Exported symbols: what a library or executable offers, with visibility
  and binding. An export is a promise to callers.
- Weak imports: symbols the binary can live without. A weak import that
  fails to resolve is expected behavior, not an error.
- Re-exports and umbrella frameworks: libraries that forward to other
  libraries. The declared import and the real provider can differ.
- Versioned symbols where the format supports them: which version of a
  symbol the binary expects.

## How to report imports and exports

- Group imports by library, and say for each whether it resolves.
- For a missing symbol, name the library, the symbol, and the binding
  kind. A missing lazy symbol and a missing eager symbol fail at
  different times.
- For exports, summarize by purpose rather than dumping the table: which
  capabilities the library offers, and which are public versus private.
- Flag private or underscored exports that look like implementation
  details being used as API. That is a finding about fragility, not a
  usage guide.

## Common mistakes

- Treating an import as proof of use. Imports can be unused, lazy, or
  dead.
- Treating a missing weak import as a failure.
- Assuming the import table is complete. Dynamically loaded libraries do
  not appear in it.
- Reading an export as a guarantee of stability. Exports can be removed
  in the next version.

## Cross-references

- Mach-O load commands: `MachOLoadCommands.md`
- dyld and shared cache: `DyldAndSharedCache.md`
- ELF analysis: `ELFAnalysisForAssist.md`
- PE analysis: `PEAnalysisForAssist.md`

## Limits

- Static import and export tables describe declared dependencies. Dynamic
  loading, plugins, and runtime-resolved symbols are invisible here, and
  Assist must say so when they could matter.
