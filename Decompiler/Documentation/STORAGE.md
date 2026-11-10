# YcodeDecompiler — Storage

Persistence for `.scdecomp` projects: a bundle directory containing a JSON
manifest, the imported binary, the analysis store (SQLite when available,
JSON otherwise), and a content-addressed result cache.

## `.scdecomp` bundle layout

Created by `DecompilerProjectManager.create(name:session:)` under
`~/Documents/SwiftCode/DecompilerProjects/<sanitized-name>.scdecomp/`:

```
<name>.scdecomp/
├── Project.json                  # manifest (ProjectManifest)
├── Analysis.sqlite               # analysis store (SwiftPM builds w/ CSQLite)
├── Analysis.json                 # analysis store (fallback / JSON path)
├── Binaries/
│   └── <stableID>.bin            # self-contained copy of the imported binary
├── Cache/
│   ├── Metadata/
│   ├── Disassembly/              # CacheManager: <key>.bin (JSON [Instruction])
│   ├── Decompilation/            # CacheManager: <key>.json (pseudocode entries)
│   ├── Graphs/                   # CacheManager: <key>.json (basic-block graphs)
│   └── <engine caches>           # reserved (e.g. Ghidra projects — currently
│                                 #   Ghidra uses NSTemporaryDirectory instead)
├── Exports/
├── Reports/
└── Resources/
```

`DecompilerProject` exposes `manifestURL`, `databaseURL`, `jsonStoreURL`,
`binariesDir`, `cacheDir`, `exportsDir`, `bundledBinaryURL` /
`binaryURL` (bundled copy preferred, original location fallback) and
`selectedSliceIndex`.

## Project.json schema (`ProjectManifest`)

| Key | Type | Notes |
|---|---|---|
| `projectUUID` | string | `UUID().uuidString` |
| `name` | string | display name |
| `schemaVersion` | int | `projectSchemaVersion` (= 1); `open` rejects newer |
| `createdAt` / `modifiedAt` | ISO-8601 | `JSONEncoder.decompiler` |
| `binaries` | `[BinaryIdentity]` | content-hash keyed identities |
| `selectedSlices` | `[String: Int]` | slice index per binary `stableID` |
| `activeBinaryID` | string? | `stableID` of active binary |
| `analysisConfiguration` | `AnalysisConfiguration` | autoAnalyze, bulk limits, engine prefs, timeout |
| `engineVersions` | `[String: String]` | engine id → version at save |
| `selectedMode` | string | `"friendly"` / `"master"` |
| `workspacePreferences` | object | sidebar selection, layout, pane visibility |

`syncManifest` refreshes `modifiedAt` and re-syncs binaries, active id,
slice selection, mode and configuration from the live session before save.

## Analysis store: `Analysis.sqlite` vs `Analysis.json`

`AnalysisPersistence.save(store:project:image:)` compiles one of two
backends:

- **SQLite** (`#if canImport(CSQLite)` — SwiftPM): opens `Analysis.sqlite`
  (`READWRITE|CREATE|FULLMUTEX`, busy timeout 5 s) and creates:

  ```sql
  CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT);
  CREATE TABLE entities (kind TEXT NOT NULL, id TEXT NOT NULL,
                         payload TEXT NOT NULL, PRIMARY KEY (kind, id));
  ```

  Each entity kind is a row whose `payload` is the entity's JSON encoding
  (`function`, `symbol`, `string`, `xref`, `type`, `finding`, `history`,
  `pseudocode`, `comment`, `label`, `binary` — plus `instruction` reserved
  in `DecompilerDatabaseSchema.EntityKind`). A full `AnalysisSnapshot` is
  stored under `meta('snapshot')`; `load` reads **that snapshot row** and
  hydrates the store (per-entity rows are a queryable denormalisation, not
  the load path). Save is delete-all + re-insert.
  `DecompilerDatabaseSchema.migrations()` documents the ordered DDL
  (including `idx_entities_kind`/`idx_entities_id` indexes and the
  `schema_version` meta row) as the reviewable migration history.

- **JSON** (XcodeGen app build): the same `AnalysisSnapshot` written
  atomically to `Analysis.json`.

`AnalysisPersistence.load(project:)` prefers `Analysis.sqlite` when
`CSQLite` is importable **and** the file exists, then `Analysis.json`,
then returns an empty `AnalysisStore`.

### `AnalysisSnapshot` contents

`schemaVersion`, optional `binary`, `functions`, `symbols`, `strings`,
`crossReferences`, `types`, `comments`/`userLabels` (hex-keyed),
`findings`, `history`, `pseudocode` (address-hex keyed), `savedAt`.
Hydration routes everything through the store's mutation API, preserving
sorting/dedup/`hasPseudocode` invariants.

## CacheManager — content-addressed result cache

`Storage/CacheManager.swift` (actor) caches expensive results under the
project's `Cache/` directory:

- Buckets: `Disassembly/<key>.bin`, `Decompilation/<key>.json`,
  `Graphs/<key>.json` (`CacheKind`).
- **Key composition** (`cacheKey(binaryHash:sliceIndex:backendID:
  backendVersion:configFingerprint:)`):
  `"<binaryHash[0..16]>-<fnv1a64(binaryHash|sliceIndex|backendID|
  backendVersion|configFingerprint)>"`. `configFingerprint` is itself an
  FNV-1a hash of the relevant `AnalysisConfiguration` fields, so changing
  backend or options invalidates correctly. The binary-hash prefix is
  embedded verbatim so `invalidate(binaryHash:)` finds every entry for a
  binary without an index.
- Typed accessors: `cachedDisassembly`/`storeDisassembly` (`[Instruction]`),
  `cachedPseudocode`/`storePseudocode` (`[DecompilationResult]`, wrapped in
  `PseudocodeCacheEntry` for Codable), `cachedGraphData`/`storeGraphData`
  (`GraphCachePayload` = function address + `[BasicBlock]`).
- `invalidate(binaryHash:)` / `invalidateAll()` remove matching files.
- **Status**: implemented but not yet instantiated by
  `DecompilerSession`/`AnalysisCoordinator` — the coordinator currently
  persists straight to `AnalysisPersistence`; wiring the cache in front
  of disassembly/decompilation calls is pending.

## Migrations & versioning

- `ProjectManifest.schemaVersion`, `AnalysisSnapshot.schemaVersion` and
  the SQLite schema version all equal `DecompilerCapabilities.
  projectSchemaVersion` / `databaseSchemaVersion` (= 1).
- `open(url:)` rejects manifests with a **newer** `schemaVersion`
  (forward-incompatible projects are refused, not guessed).
- `DecompilerDatabaseSchema.migrations()` is the ordered migration list
  for future revisions; `Storage/DatabaseMigrations/` remains a reserved
  directory. Persistence currently performs full-rewrite saves rather
  than incremental upgrades.

## Lifecycle

- `openProject(at:)` → manifest → session → `attachProject` → re-import
  `project.binaryURL` at `selectedSliceIndex`.
- `newProject(named:binaryAt:)` → import → `create` copies the binary
  into `Binaries/` (self-contained bundle).
- `validate(_:)` reports missing `Project.json` / unreadable binary.

## Evidence

| Claim | Level |
|---|---|
| Bundle layout, manifest schema, store formats, cache keys, versioning | 1 — `ProjectManifest.swift`, `DecompilerProjectManager.swift`, `AnalysisPersistence.swift`, `CacheManager.swift`, `DecompilerDatabase.swift` |
| CacheManager unwired status | 1 — grep-verified (no instantiation sites) |
| Ghidra temp-cache location (outside `.scdecomp`) | 1 — `GhidraDecompiler.swift` uses `NSTemporaryDirectory()/SwiftCodeDecompiler` |
