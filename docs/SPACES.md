# Spaces — native source control

Spaces is SwiftCode's independent source-control system: its own repository
format, object database, operations engine, CLI, and networking protocol. It
is **not** a Git wrapper — Git support is unchanged and remains the default.

## Repository format (`.spaces/`)

```
.spaces/
  config.json          repository configuration (format version, user, remotes)
  HEAD                 symbolic ref (refs/heads/<branch>) or detached OID
  objects/xx/<rest>    content-addressed objects, SHA-256, two-level fanout
  refs/heads/…         branch tips
  refs/tags/…          tag targets
  refs/remotes/…       remote-tracking refs
  refs/snapshots/…     snapshot refs
  index                staged index (JSON, stat-cached)
  logs/…               reflogs (append-only)
  journal               transaction journal (JSONL: begin/step/commit/abort)
  lock                  cross-process PID lock (stale locks auto-stolen)
  MERGE_HEAD, MERGE_MSG, CHERRY_PICK_HEAD, REVERT_HEAD, REBASE_HEAD, rebase-merge/
  conflicts.json       in-progress merge conflict records
  stash.json           stash stack
  hooks/               repository hooks
  lfs/objects/         large-file storage
  worktrees/           linked-worktree metadata
  tmp/                 scratch space
```

### Objects

Every object is `SHA-256(type ‖ payload)` stored under `objects/<2 hex>/<62
hex>`. Types: `blob`, `tree`, `commit`, `tag`, `snapshot`. Reads re-verify the
cryptographic ID, so corruption is detected on access (`fsck` checks all).

- **tree** — sorted entries `{name, mode, oid}`; modes `100644`, `100755`,
  `120000` (symlink), `040000` (directory).
- **commit** — `{tree, parents[], author, committer, message, metadata}`.
- **tag** — annotated tag object `{object, objectType, name, tagger, message}`.
- **snapshot** — point-in-time capture `{tree, indexTree?, parents[], …}` used
  by the timeline/recovery features.

### Index

`index` records staged entries with stat cache (mtime/ctime/device/inode) so
`status` can skip re-hashing unchanged files. `spaces rebuild-index` regenerates
it from the worktree.

## Engine layout (`swiftcode/Sources/SpacesEngine`)

| Area | Contents |
|---|---|
| `Core/` | `ObjectID` (SHA-256), `RepositoryConfig`, `RepositoryFormat`, `SpacesError` |
| `Objects/` | `ObjectStore`, `StoredObject`, `TreeBuilder`, models |
| `Index/` | staged index + stat cache |
| `WorkingTree/` | scanner, `.gitignore`-style ignore engine |
| `Operations/` | staging/commit, branches, merge, rebase, stash, tags, snapshots, history, diff, maintenance, remotes |
| `Diff/` | Myers line diff, unified patches, stats |
| `Networking/` | `spaces-proto/1` transports (local filesystem, HTTP) |
| `Transactions/` | `Journal` — append-only JSONL transaction log |
| `Migration/` | Git import/export, bundles, tar archives |
| `Search/` | filename/commit/content search |
| `API/` | `SpacesAPI` — the single facade used by CLI and app |

## CLI

`spaces` (SwiftPM executable, `swiftcode/Sources/spaces`) shares `SpacesAPI`
with the app — identical engine, identical data.

```
spaces init [path]        create .spaces/
spaces status|scan        working-tree status
spaces add|stage|rm|mv    index operations
spaces commit|amend       commits
spaces log|show|describe|blame|graph|rebase-base
spaces branch|switch|merge|rebase|cherry-pick|revert
spaces tag|stash|snapshot|reset|restore|clean
spaces diff|apply|format-patch
spaces remote|fetch|push|pull|clone|bundle|archive
spaces worktree add|remove|list
spaces fsck|gc|count|storage|diagnose|health|repair|rebuild-index
spaces search|history
spaces hook|sign|verify
spaces import git <path>  import a git repository
spaces export-git <path>  write a real .git repository
```

## App integration

- **Settings → Source Control → Source Control System**: `Git` (default) or
  `Spaces (native)`. Persisted in `Preferences.sourceControlSystem`.
- `GitViewModel` routes status/branch/commit/diff/remote operations to
  `SpacesService` (SwiftCodeSDK) when Spaces is selected, so the existing
  Changes/Branches/History/Tags views work unchanged.
- The **Spaces (Native)** sidebar group appears when Spaces is selected and
  opens `SpacesWorkspaceView`: overview, changes, branches, history,
  merge/rebase/stash/snapshot operations, remotes, maintenance (fsck/gc/
  rebuild-index/worktrees), and Git migration.

## Networking

Protocol `spaces-proto/1`: newline-delimited JSON messages. Local transport
operates directly on `.spaces/` directories; HTTP transport targets a
compatible Spaces server. Credentials: `~/.config/spaces/credentials.json`
(mode 0600) or macOS Keychain (service `dev.swiftcode.spaces`).

Operations: `clone`, `fetch`, `push`, `pull` with remote-tracking refs
(`refs/remotes/<remote>/*`) and fast-forward enforcement.

## Migration

- **Import** reads a git repository via `git cat-file --batch-all-objects` +
  `for-each-ref`, converts SHA-1 git objects to SHA-256 Spaces objects
  (blobs/trees bottom-up, commits parent-first, annotated tags), and maps refs.
- **Export** writes a real `.git` via `git init` + `hash-object`/`mktree`/
  `commit-tree`/`mktag`/`update-ref`, preserving history, authors, and tags.
- Bundles (`spaces bundle`) and tar archives (`spaces archive`) provide
  offline transfer formats.

## Transactions & recovery

Mutations run inside `performTransaction`, guarded by a reentrant
cross-process lock (`index.lock`-style PID file) and recorded in
`journal`. On open, `recoverIfNeeded()` replays/abandons unfinished
transactions. `spaces doctor`/`diagnose` reports lock, journal, and integrity
state.
