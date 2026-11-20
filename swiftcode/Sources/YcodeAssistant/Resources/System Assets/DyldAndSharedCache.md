# dyld and the Shared Cache

<!-- system-index-depends: MachOFileLayoutForAssist.md -->

On Apple platforms, dyld loads executables and their libraries, and the
dyld shared cache holds most system libraries in a pre-linked form. Assist
needs this model to explain why a binary loads, fails to load, or resolves
a symbol to a place the user did not expect.

## When to retrieve

- A launch failure mentions dyld, a missing library, or a symbol.
- The user asks where a system framework actually lives at runtime.
- A binary's library dependency does not match what the user sees on disk.

## How loading works, at the level Assist needs

- dyld reads the executable's load commands, maps its segments, and loads
  each declared library in dependency order.
- Libraries can be loaded lazily: a symbol is bound when first used, not
  at launch. A missing symbol may therefore crash later, not at startup.
- Search paths decide where libraries are found: the executable's run
  path, the loader path, and system locations, in a defined order.
- The shared cache replaces most system libraries on disk with a single
  pre-built image. A framework that appears absent from `/System/Library`
  may simply live in the cache.
- Cache state is per OS version. A symbol that exists on one version may
  not exist on another, and the cache must match the running system.

## Common failure patterns

- Library not found: the declared path does not exist, the run path is
  wrong, or the library is missing from the bundle.
- Symbol not found: the library loaded, but it is a different version than
  the binary was built against.
- Incompatible architecture: a library slice does not match the executable.
- Code-signing mismatch: the loader refuses a library whose signature does
  not satisfy the executable's requirements.
- Cache staleness after an OS update: the cache and the on-disk stubs
  disagree until the system rebuilds it.

## How to report loading questions

- Name the exact library path dyld was asked for, and where it actually
  looked.
- Distinguish a missing file from a found-but-unusable file; the fixes
  differ completely.
- Say whether the library is a system library (cache), a bundled library,
  or a third-party install. Each has a different owner and a different fix.
- Never claim a symbol is missing from the system based on one machine;
  version differences are the usual cause.

## Cross-references

- Load commands: `MachOLoadCommands.md`
- Import and export analysis: `ImportAndExportAnalysis.md`
- Entitlements and signing: `EntitlementsAndCodeSigningAnalysis.md`

## Limits

- Assist reasons statically about loading. It does not run dyld, launch
  the binary, or inspect a live process to watch resolution happen.
- Shared-cache contents are system internals; Assist describes behavior
  and failure modes, not cache internals beyond what is needed to explain
  a finding.
