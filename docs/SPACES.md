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
spaces worktree-add|worktree-remove|worktree-list
spaces workspace-switch|workspace-remove|workspace-list
spaces merge-strategy|merge-strategies
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

## Wave-1 features (60)

Sixty features in six categories of ten, all backed by the engine above.
Each line names the feature, its real on-disk storage, and its real CLI
command; "no CLI command" means the feature is reachable only through
`SpacesAPI` and the Spaces workspace UI, not through `spaces`.

### Intelligence (10)

- Time Machine — browse and restore any recorded commit/snapshot/reflog state. Storage: derived from commits, snapshots, and reflogs in `.spaces/objects/`, `.spaces/refs/`, `.spaces/logs/`. CLI: no CLI command.
- Recovery Checkpoints — explicit pre-operation restore points. Storage: `.spaces/checkpoints/index.json`. CLI: no CLI command.
- Semantic Search — declaration-aware search over indexed Swift symbols (literal/prefix matching, no ML ranking). Storage: `.spaces/intelligence/symbols.json`. CLI: `spaces semantic-search <query> [--kind <kind>]`.
- Historical Search — search file contents across commit history, optionally as a regex. Storage: derived from history objects in `.spaces/objects/`. CLI: `spaces history-search <query> [--limit N] [--regex]`.
- Change Impact — files, declared symbols, reverse dependents, and directories affected by a revision. Storage: derived from history objects and `.spaces/intelligence/dependencies.json`. CLI: no CLI command.
- Dependency Graph — file-to-module import graph. Storage: `.spaces/intelligence/dependencies.json`. CLI: `spaces dependencies [--refresh]`.
- File Evolution — per-commit change history of one file. Storage: derived from history objects in `.spaces/objects/`. CLI: `spaces file-evolution <path> [--limit N]`.
- Knowledge Index — per-file symbol/import/commit-count index. Storage: `.spaces/intelligence/knowledge.json`. CLI: no CLI command.
- Change Risk — scored risk of a revision with per-factor measurements. Storage: derived from history objects and the symbol index. CLI: no CLI command.
- Health History — recorded health snapshots over time. Storage: `.spaces/intelligence/health-history.jsonl`. CLI: no CLI command.

### Advanced version control (10)

- Multi-Repo Commit — one commit across several repositories with a recovery report. Storage: per-transaction records in `.spaces/multirepo/<tx>.json`. CLI: no CLI command.
- Branch Checkpoints — named restore points on a branch. Storage: refs `refs/checkpoints/<branch>/<name>` plus reflogs. CLI: `spaces branch-checkpoint create|list|restore`.
- Branch Time Travel — move a branch tip to an earlier state. Storage: derived from refs and reflogs. CLI: no CLI command.
- Branch Stacks — ordered stacks of branches on a shared base. Storage: `.spaces/stacks/`. CLI: `spaces branch-stack create|list|status|update`.
- Change Sets — named groups of paths staged together. Storage: `.spaces/changesets/`. CLI: `spaces changeset create|list|add|stage`.
- Partial Restore — restore only selected paths from a revision. Storage: derived from history objects. CLI: no CLI command.
- Commit Graph Dependencies — declared dependencies between commits. Storage: `.spaces/commit-graph.json`. CLI: no CLI command.
- Validation Policies — commit-message/path policies checked before commit. Storage: `.spaces/policies.json`. CLI: no CLI command.
- Multi-Stage Commit — prepare, validate, preview, finalize, or abort a commit in stages. Storage: `.spaces/staging/`. CLI: no CLI command.
- Operation Undo — undoable operations with an append-only log. Storage: `.spaces/undo/log.jsonl`. CLI: `spaces operation-undo list|undo`.

### Storage (10)

- Continuous Snapshots — scheduled workspace snapshots. Storage: `.spaces/storage/continuous.json`. CLI: no CLI command.
- Snapshot Branching — create a branch from, or check out, a snapshot. Storage: snapshots live in `.spaces/refs/snapshots/` and `.spaces/objects/`. CLI: no CLI command.
- Snapshot Deduplication — report of naive vs shared bytes across snapshots. Storage: derived from the object store. CLI: no CLI command.
- Retention Policy — age/count/byte limits and pinned snapshots, applied on demand. Storage: `.spaces/storage/retention.json`. CLI: no CLI command.
- Snapshot Integrity — per-snapshot and whole-store verification. Storage: derived from the object store. CLI: no CLI command.
- Storage Heatmap — object counts and bytes by type, size band, and age band. Storage: derived from the object store. CLI: `spaces storage-heatmap`.
- Predictive Storage — growth samples and a 30-day projection. Storage: derived from the object store (samples are computed, not persisted). CLI: no CLI command.
- Recovery Vault — retain worktree files outside history for later restore. Storage: `.spaces/vault/` with `manifest.json`. CLI: no CLI command.
- Compaction Profiles — named gc/rebuild/prune profiles. Storage: `.spaces/storage/compaction.json`. CLI: `spaces storage-profile list|apply`.
- Incremental Backup — create, verify, restore, and list object backups. Storage: backups under `.spaces/storage/backups/`. CLI: `spaces backup create|verify|restore|list` (also `spaces backup-verify`, `spaces backup-restore`).

### Collaboration (10)

- Reviews — create and list change reviews with approvals. Storage: `.spaces/reviews/`. CLI: `spaces review create|list|status|approve` (also `spaces review-status <id>`).
- Discussions — line-anchored review comments with edit/resolve. Storage: `.spaces/reviews/<review-id>/discussions.json`. CLI: `spaces discussion add|list|resolve`.
- Review Tracking — approvals recorded per review, with changes since approval. Storage: `.spaces/reviews/`. CLI: `spaces review approve`, `spaces review-status <id>`.
- Review Policy — required approvals, required reviewers, validation gate, and merge check. Storage: `.spaces/reviews/policy.json`. CLI: no CLI command.
- Conflict Sessions — claim paths and record resolutions for shared edits. Storage: `.spaces/conflicts/sessions`. CLI: no CLI command.
- Activity Feed — recent repository events. Storage: derived from reflogs and review records. CLI: no CLI command.
- Ownership — path-pattern to owner rules and owner lookup. Storage: `.spaces/ownership.json`. CLI: `spaces ownership rules|owners`.
- Workspace Templates — named workspace setups (branch, policy, ownership, ignores). Storage: `.spaces/templates/`. CLI: `spaces workspace-template create|list|apply`.
- Cross-Branch Tracking — track one change across several branches. Storage: `.spaces/cross-branch/`. CLI: no CLI command.
- Notifications — per-event notification rules and pending notifications. Storage: `.spaces/notifications.json` and `.spaces/notifications/last-seen`. CLI: `spaces notifications rules|pending|seen`.

### Security (10)

- Policy Engine — repository rules (protected branches, max file size, signed commits, forbidden paths, message patterns) with a check operation. Storage: `.spaces/security/policy.json`. CLI: `spaces policy show|check`.
- Secret History — secrets found across history. Storage: derived from history blobs. CLI: `spaces secret-history`.
- Data Classification — path/content pattern categories and per-path or whole-repo classification. Storage: `.spaces/security/classification.json`. CLI: no CLI command.
- Provenance — per-revision provenance checks and a trusted-signer policy. Storage: `.spaces/security/trust.json`. CLI: `spaces provenance <rev>`.
- Access Audit — append-only audit event log. Storage: `.spaces/security/audit.jsonl`. CLI: no CLI command.
- Operation Permissions — per-operation role allow-lists and the current role. Storage: `.spaces/security/permissions.json`, `.spaces/security/role.json`. CLI: no CLI command.
- Signed Snapshots — sign a snapshot and verify its signature. Storage: signature records at `.spaces/snapshots/signatures/<oid>.json`. CLI: no CLI command.
- Protected History — per-ref force-push/delete/review rules with a check. Storage: `.spaces/security/protected.json`. CLI: no CLI command.
- Dependency Audit — manifest/lockfile changes per commit. Storage: derived from history blobs (manifest and lockfile contents). CLI: no CLI command.
- Security Report — generated report combining secrets, classification, provenance, audit, and policy violations. Storage: generated on demand, not persisted. CLI: `spaces security-report`.

### Developer tooling (10)

- Language-Aware Diff — structural (declaration-level) diff between revisions. Storage: derived from history blobs. CLI: no CLI command.
- Symbol History — history of one symbol in one file. Storage: derived from history blobs. CLI: `spaces symbol-history`.
- API Compatibility — public API surface per revision and breaking changes between revisions. Storage: derived from history blobs. CLI: `spaces api-compatibility`.
- Build Impact — recorded build results per commit. Storage: `.spaces/tooling/builds.jsonl`. CLI: `spaces build-impact record|history`.
- Test Provenance — recorded test results per commit. Storage: `.spaces/tooling/tests.jsonl`. CLI: `spaces test-provenance record|list`.
- Change Validation — affected components and validation plan for a revision. Storage: derived from history objects. CLI: no CLI command.
- Automation Pipelines — event-triggered pipelines with an allow-listed command set. Storage: `.spaces/tooling/automation.json`. CLI: `spaces automation list|run`.
- Patch Collections — named patch sets created from a revision range. Storage: `.spaces/tooling/patches/<name>.json`. CLI: `spaces patch-collection create|list|apply`.
- Attribution — trace a line or symbol back to its originating commit. Storage: derived from history objects. CLI: no CLI command.
- Performance Profiler — profiled operation samples and summaries. Storage: `.spaces/tooling/profile.jsonl`. CLI: `spaces performance`.

### Worktree and workspace command names

The canonical top-level commands are `spaces worktree-add`,
`spaces worktree-remove`, `spaces worktree-list`,
`spaces workspace-switch`, `spaces workspace-remove`, and
`spaces workspace-list`, plus `spaces merge-strategies` (the
`spaces merge-strategy` command keeps its existing name). Do not use the
older `spaces worktree add|remove|list` forms.

Known wart, recorded as a follow-up decision rather than fixed here: the
worktree/workspace command structs are dual-role — they are registered both
as top-level commands and as subcommands of the `worktree`/`workspace`
groups — so the group paths are now redundantly named
(`spaces worktree worktree-add`, `spaces workspace workspace-switch`, and
so on). The alternative is de-registering the top-level aliases to restore
the documented group paths; that choice is left to the coordinator's final
report.

## Repository detection

`Repository.detect(at:)` (and `SpacesAPI.detectRepository(at:)`) classifies a
directory without searching upward:

| Outcome | Meaning |
|---|---|
| `.spaces(valid: true)` | `.spaces/` exists, `config.json` parses, format version is supported, and `objects/` and `refs/` directories exist |
| `.spacesInvalid(reason:)` | `.spaces/` exists but fails validation; the reason names the concrete problem (missing `config.json`, unparseable `config.json`, missing `objects/` or `refs/` directory, or `.spaces` not being a directory). A broken `.spaces/` is never reported as Git, even when a `.git/` directory is also present |
| `.git` | No `.spaces/` directory, but a `.git/` directory exists |
| `.empty` | Neither `.spaces/` nor `.git/` exists |
| `.unsupportedVersion(version:)` | `config.json` parses but its format version is newer than `RepositoryFormat.formatVersion` |

Detection never infers Spaces from a similarly named folder alone: only a
directory literally named `.spaces` is considered, and it must pass every
check above.

## App integration (Wave-1 UI)

- `SpacesWorkspaceView` gains sidebar sections Intelligence, Reviews,
  Security, and Storage, backed by `SpacesIntelligenceView`,
  `SpacesReviewsView`, `SpacesSecurityView`, and `SpacesStorageView`. Each
  view calls real `SpacesAPI` operations and surfaces real errors in the
  view; there is no Git fallback on Spaces errors.
- The workspace console no longer prints fake success for unknown commands:
  an unknown console command now shows `spaces: unknown command '<cmd>'`.

## Project wiring

- `project.yml` declares the `SpacesEngine` static-library target
  (`swiftcode/Sources/SpacesEngine`, depends on the Crypto package product),
  the `spaces` tool target (`swiftcode/Sources/spaces`, depends on
  `SpacesEngine` and the ArgumentParser package product), and the
  `SpacesEngineTests` unit-test target
  (`swiftcode/Tests/SpacesEngineTests`, depends on `SpacesEngine`). It also
  declares the `SwiftArgumentParser` package (from 1.5.0) and adds
  `SpacesEngine` to the `YcodeUI` and `SwiftCodeSDK` target dependencies.
  `Package.swift` already declares the same three targets for SwiftPM.
- `SwiftCode.xcodeproj/project.pbxproj` contains the `SpacesEngine` target
  with every `.swift` file under `swiftcode/Sources/SpacesEngine` in its
  Sources phase, the `spaces` tool target with every `.swift` file under
  `swiftcode/Sources/spaces`, the `SpacesEngineTests` unit-test target with
  every `.swift` file under `swiftcode/Tests/SpacesEngineTests`, and the
  four new views in the YcodeUI SourceControl group's Sources phase. The
  `spaces` target also links the ArgumentParser product through an
  `XCRemoteSwiftPackageReference` for swift-argument-parser 1.5.0.
- Pre-existing note: the `SourceControl` group's children list in
  `project.pbxproj` already closed with its final entry and the closing
  paren on one line (`SpacesWorkspaceView.swift */,);`) before this work;
  the new view entries were appended in the normal one-entry-per-line form
  and the closing paren is on its own line.

## Transactions & recovery

Mutations run inside `performTransaction`, guarded by a reentrant
cross-process lock (`index.lock`-style PID file) and recorded in
`journal`. On open, `recoverIfNeeded()` replays/abandons unfinished
transactions. `spaces doctor`/`diagnose` reports lock, journal, and integrity
state.
