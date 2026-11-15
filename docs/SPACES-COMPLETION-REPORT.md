# Spaces — completion report

**Date:** 2026-11-14
**Repository:** `dylans2010/SwiftCode`, branch `main`
**Scope:** the full Spaces production-readiness spec — engine core, 60 exclusive
features (A1–F60), §5 CLI parity, UI/settings/detection, §4 hardening,
`tools/clean.py` repo-wide cleanup, validation matrix, integration workflows,
and the §9 30-step end-to-end acceptance scenario.

S10 + coordinator-fix push: 0d330727f4d16e9b3c01c0991946be4573c30353. This SHA line was filled in by the follow-up commit a2599bddd5398b4a1333b1b73f54389c2fab11bc (see git log); the live tip may be newer — verify it with the GitHub API.

## How this report was built

Every number in this report was read off disk by the S10 slice (2026-11-14):
CLI names were enumerated from `swiftcode/Sources/spaces/*.swift` with a
positional script (162 registered in `main.swift`, 162 unique derived names);
`@Test` functions were counted per test file with `grep -c`; UI actions were
mapped by grepping the view sources for `SpacesAPI` calls; Git limitations were
read from `GitMigration.swift`; the re-checks below re-read the flagged engine
files. Nothing in this report is copied from a stale list.

## Verification status — read first

**No Swift toolchain exists in this environment. 0 tests were executed here
and 0 builds ran.** Every test named in this report was written in this slice
and statically verified only: zero comments in the new files, balanced
delimiters, and every referenced `SpacesAPI`/`SpacesEngine` symbol confirmed
to exist by grep. The Xcode build, `swift test`, and the live 30-step E2E run
on Dylan's Mac are the pending gate. No test in this report is claimed as
passing.

Status meanings used below: **COMPLETE** — the deliverable exists as real code
and was verified on disk (statically; see the gate note above).
**PARTIAL** — it exists and works, but a named part deviates from the spec.
**BLOCKED** — it cannot be finished in this environment.
**NOT IMPLEMENTED** — it does not exist.

## Subsystem statuses

| Subsystem | Status | Note |
|---|---|---|
| Engine core (`.spaces/` format, objects, index, staging, branches, merge, rebase, stash, tags, snapshots, history, diff, maintenance, remotes, journal, Git migration, bundles, search) | COMPLETE | One follow-up found in S10 (see §4 follow-up) |
| Intelligence (A1–A10) | COMPLETE | Risk scores are heuristics, labelled as such |
| Advanced version control (B11–B20) | PARTIAL | B19 finalize scoping deviates (see B19) |
| Storage (C21–C30) | COMPLETE | Growth estimate is a projection, not a forecast |
| Collaboration (D31–D40) | COMPLETE | |
| Security (E41–E50) | COMPLETE | |
| Developer tooling (F51–F60) | COMPLETE | |
| CLI parity (§5) | COMPLETE | 162/162 named commands present; `merge-strategy` output is static (see below) |
| UI / settings / detection | COMPLETE | Static only; never opened in Xcode |
| §4 hardening | COMPLETE | 25 tests; one Maintenance follow-up (see below) |
| `tools/clean.py` + repo-wide cleanup | COMPLETE | Exact numbers in §7 |
| Validation matrix | COMPLETE | 30 tests written, 0 executed here |
| Integration workflows | COMPLETE | 4 tests written, 0 executed here |
| §9 E2E scenario (30 steps) | COMPLETE | 1 ordered test written, 0 executed here |
| Git compatibility | PARTIAL | Real import/export; limitations in §8 |
| Build / test verification | BLOCKED | No Swift toolchain in this environment |

## 1. Engine core

COMPLETE. `.spaces/` format v1 (SHA-256 objects `blob`/`tree`/`commit`/`tag`/
`snapshot`, two-level fanout under `objects/xx/<rest>`, JSON stat-cached index,
reflogs, JSONL journal, PID lock file with stale-lock stealing, hooks, LFS,
worktrees). `SpacesAPI` is the single facade used by the CLI and the app:
252 `public func` declarations counted by grep across `SpacesAPI.swift` and its six extensions.
Core operations: init/open/recover, add/stage/move/remove/unstage/restore/clean,
commit/amend, log/show/blame/graph/reflog, branch create/switch/delete/rename/
reset, merge/cherry-pick/revert/rebase, stash, tags, snapshots/timeline,
remotes (local + HTTP `spaces-proto/1`), fsck/gc/repair/rebuild-index,
search, import/export Git, bundles, worktrees.

S10 follow-up (found while writing the recovery tests, **fixed by the
coordinator after S10 reported it**): `MaintenanceOps.rebuildIndex()`
re-read the old index after building the new one, so it threw
`indexCorrupt` when the index file was present but unparseable, and
`repair()` (which calls `rebuildIndex()` first) threw the same way. The
fix is a one-line tolerance in `Maintenance.swift` (the carry-over read
is now `(try? repo.index()) ?? Index()`, so an unreadable old index is
treated as empty and the rebuild proceeds from HEAD). `ValidationMatrixTests.recoveryBrokenIndexRebuilt` now asserts both
paths: rebuild directly on the corrupt-but-present index succeeds, and
the delete-first-then-rebuild path still works. Static verification
only — the Xcode test run on Dylan's Mac is the proof.

## 2. The 60 features

All 60 exist as engine operations plus a `SpacesAPI` extension method, with
on-disk JSON storage under `.spaces/` and Swift Testing coverage. Per-feature
status follows; "CLI" names the top-level command where one exists.

### A. Intelligence (10) — COMPLETE

| # | Feature | CLI | Note |
|---|---|---|---|
| A1 | Time Machine | — | Derived from commits, snapshots, reflogs |
| A2 | Recovery Checkpoints | — | `.spaces/checkpoints/index.json` |
| A3 | Semantic Search | `semantic-search` | Literal/prefix symbol matching, no ML ranking |
| A4 | Historical Search | `history-search` | Up to 500 commits, optional regex |
| A5 | Change Impact | — | Derived from history + dependency index |
| A6 | Dependency Graph | `dependencies` | `.spaces/intelligence/dependencies.json` |
| A7 | File Evolution | `file-evolution` | Follows renames (see S10 re-check (a)) |
| A8 | Knowledge Index | — | `.spaces/intelligence/knowledge.json` |
| A9 | Change Risk | — | Scored per-factor measurements, labelled heuristic |
| A10 | Health History | — | `.spaces/intelligence/health-history.jsonl` |

### B. Advanced version control (10) — PARTIAL (B19)

| # | Feature | CLI | Note |
|---|---|---|---|
| B11 | Multi-Repo Commit | — | Best-effort per-repo outcomes; if a repo fails to open, the transaction record lives in the primary repo only |
| B12 | Branch Checkpoints | `branch-checkpoint` | Refs under `refs/checkpoints/<branch>/<name>` |
| B13 | Branch Time Travel | — | Moves the tip by creating a new commit |
| B14 | Branch Stacks | `branch-stack` | `.spaces/stacks/` |
| B15 | Change Sets | `changeset` | `.spaces/changesets/` |
| B16 | Commit Graph Dependencies | — | Declared dependencies between commits |
| B17 | Partial Restore | — | Selected paths only |
| B18 | Validation Policies | — | `.spaces/policies.json`; enforced by `commit`/`commitValidated` |
| B19 | Multi-Stage Commit | — | **PARTIAL:** `finalizeStagedCommit` commits the whole index, not only the paths recorded at `prepare` time |
| B20 | Operation Undo | `operation-undo` | Append-only log; refuses history rewrites |

### C. Storage (10) — COMPLETE

| # | Feature | CLI | Note |
|---|---|---|---|
| C21 | Continuous Snapshots | — | `.spaces/storage/continuous.json` |
| C22 | Snapshot Branching | — | Branch from / check out a snapshot |
| C23 | Snapshot Deduplication | — | Derived from the object store |
| C24 | Retention Policy | — | `.spaces/storage/retention.json` |
| C25 | Snapshot Integrity | — | ObjectStore re-verification per snapshot |
| C26 | Storage Heatmap | `storage-heatmap` | By type, size band, age band |
| C27 | Predictive Storage | — | Growth samples + 30-day projection (a projection, not a forecast) |
| C28 | Recovery Vault | — | `.spaces/vault/` + `manifest.json` |
| C29 | Compaction Profiles | `storage-profile` | `.spaces/storage/compaction.json` |
| C30 | Incremental Backup | `backup`, `backup-verify`, `backup-restore` | SPBD bundle format; manifests under `.spaces/storage/backups/` |

### D. Collaboration (10) — COMPLETE

| # | Feature | CLI | Note |
|---|---|---|---|
| D31 | Reviews | `review`, `review-status` | `.spaces/reviews/` |
| D32 | Discussions | `discussion` | Line-anchored comments, edit history, resolve |
| D33 | Review Tracking | `review approve`, `review-status` | Approvals + changes since approval |
| D34 | Review Policy | — | `.spaces/reviews/policy.json`; merge check |
| D35 | Conflict Sessions | — | `.spaces/conflicts/sessions` |
| D36 | Activity Feed | — | Derived from reflogs + review records |
| D37 | Ownership | `ownership` | IgnoreEngine globs + history fallback |
| D38 | Workspace Templates | `workspace-template` | `.spaces/templates/` |
| D39 | Cross-Branch Tracking | — | Parent-walk ancestry |
| D40 | Notifications | `notifications` | `.spaces/notifications.json` + last-seen marker |

### E. Security (10) — COMPLETE

| # | Feature | CLI | Note |
|---|---|---|---|
| E41 | Policy Engine | `policy` | `.spaces/security/policy.json` |
| E42 | Secret History | `secret-history` | Same 5 scan regexes across history (up to 200 commits) |
| E43 | Data Classification | — | `.spaces/security/classification.json` |
| E44 | Provenance | `provenance` | Real SigningOps verification |
| E45 | Access Audit | — | `.spaces/security/audit.jsonl` |
| E46 | Operation Permissions | — | `.spaces/security/permissions.json`, `role.json` |
| E47 | Signed Snapshots | — | Signatures at `.spaces/snapshots/signatures/<oid>.json` |
| E48 | Protected History | — | `.spaces/security/protected.json`; enforced on force-push and branch delete |
| E49 | Dependency Audit | — | Manifest/lockfile changes per commit |
| E50 | Security Report | `security-report` | Generated on demand, not persisted |

### F. Developer tooling (10) — COMPLETE

| # | Feature | CLI | Note |
|---|---|---|---|
| F51 | Language-Aware Diff | — | Declaration-level structural diff |
| F52 | Symbol History | `symbol-history` | |
| F53 | API Compatibility | `api-compatibility` | Public surface per revision + breaking changes |
| F54 | Build Impact | `build-impact` | `.spaces/tooling/builds.jsonl` |
| F55 | Test Provenance | `test-provenance` | `.spaces/tooling/tests.jsonl` |
| F56 | Change Validation | — | Affected components + validation plan |
| F57 | Automation Pipelines | `automation` | Allow-listed command set |
| F58 | Patch Collections | `patch-collection` | `.spaces/tooling/patches/<name>.json` |
| F59 | Attribution | — | Line/symbol origin tracing |
| F60 | Performance Profiler | `performance` | `.spaces/tooling/profile.jsonl` |

## 3. CLI parity

COMPLETE. 162 top-level commands registered in `swiftcode/Sources/spaces/
main.swift`, enumerated from the sources by S10 (not copied from docs).
Every one of the 29 §5 commands named in the spec is present, plus the
`snapshots` and `history` aliases.

All 162 registered top-level names, in registration order:

`init status changes stage add remove move restore clean unstage reset commit
amend log show describe diff patch ancestry graph blame annotate branch switch
checkout merge merge-abort merge-continue merge-preview merge-strategies
rebase rebase-continue rebase-abort rebase-skip cherry-pick
cherry-pick-continue cherry-pick-abort revert reflog tag stash snapshot
timeline checkpoint recover restore-point recovery-list recovery-prune remote
fetch pull push sync publish unpublish upstream transfer clone doctor fsck gc
prune compact optimize repack count count-objects storage integrity diagnostics
health repair repair-index rebuild-index maintenance migrate upgrade config
version info inspect validate open discover explain impact compare benchmark
trace events notes sign verify-signature identities credentials permissions
audit search find find-file find-commit find-change find-branch find-history
hooks hook-install hook-remove lfs extensions import-git import export-git
export archive bundle worktree worktrees worktree-add worktree-list
worktree-remove workspace workspaces create workspace-switch workspace-remove
workspace-list ls-files ls-tree cat-file merge-strategy semantic-search
history-search dependencies file-evolution branch-stack branch-checkpoint
changeset provenance policy security-report secret-history ownership review
review-status discussion notifications backup backup-verify backup-restore
storage-heatmap storage-profile workspace-template automation patch-collection
symbol-history api-compatibility test-provenance build-impact performance
operation-undo snapshots history`

Uniqueness: S10 re-ran a positional uniqueness check over all derived
top-level names (explicit `commandName:` where present, kebab-cased struct
name otherwise): **162 registered, 162 unique, 0 duplicates.** The earlier
"git" duplicate is refuted again: `import-git`/`export-git` are the top-level
names; the `git` names belong to `ImportGitCmd`/`ExportGitCmd`, which are
subcommands of the `import`/`export` groups only, not top-level commands.
**Whether ArgumentParser traps on duplicates at launch is UNVERIFIED** — no
`spaces` binary was built or run in this environment (no toolchain), so the
duplicate-name question is settled only statically.

Known CLI issues, pre-existing and not fixed in this slice:

- `merge-strategy` prints a static string (`"ort (default); recursive
  available via --strategy"`, `CommandsCore.swift`) without consulting the
  engine or the repository. `merge-strategies` is a thin forwarding wrapper
  that delegates to it, so both commands produce the same static output.
  The audit's "functionally identical bodies" wording is corrected here:
  the bodies are not duplicated text — one is a forwarder — but the
  observable behaviour is identical, and neither performs real work.
- Dual-role worktree/workspace structs (open decision, recorded in
  `docs/SPACES.md`): the structs are registered both as top-level commands
  and as subcommands of the `worktree`/`workspace` groups, so the group
  paths read redundantly (`spaces worktree worktree-add`,
  `spaces workspace workspace-switch`). The alternative — de-registering the
  top-level aliases to restore the documented group paths — is left open.
- `spaces create` is the derived top-level name of `WorkspaceCreate`
  (unique, no conflict, but a generic name).

Fixed in earlier waves and re-confirmed present: `spaces trace` really
executes `status`/`log`/`fsck`/`storage`/`search` between before/after object
counts (it was a no-op wrapper at the audit baseline).

## 4. UI, settings, detection

COMPLETE (static verification only; the views were never opened in Xcode).

- **Settings** (`NativeSettingsViews.swift`): Settings → Source Control →
  Source Control System picker — `Git` (default) or `Spaces (native)`,
  persisted in `Preferences.sourceControlSystem`.
- **Routing:** `GitViewModel` routes to `SpacesService` (414 lines,
  `SwiftCodeSDK/Kits/SourceControlKit/SpacesService.swift`) when Spaces is
  selected or a `.spaces/` directory exists, so the existing Changes /
  Branches / History / Tags views work unchanged. Its surface: status,
  stage/unstage/stage-all/discard/commit, clone, log, branches
  (create/checkout/delete/rename), diff, fetch/pull/push/force-push, rollback,
  merge, stash, remotes, tags, worktrees, commit file stats, rebase
  (continue/abort), merge continue/abort.
- **Detection:** `Repository.detect(at:)` / `SpacesAPI.detectRepository(at:)`
  classify a directory as `.spaces(valid:)`, `.spacesInvalid(reason:)`,
  `.git`, `.empty`, or `.unsupportedVersion(version:)`; a broken `.spaces/`
  is never reported as Git. Covered by 8 `DetectionTests`.
- **SpacesWorkspaceView** (936 lines): sidebar sections plus a console.
  Buttons call the model, which calls `SpacesAPI` directly:
  initialize → `Repository.create`; Clean → `clean()`; Stage All →
  `stageAll()`; Stage/Unstage/Discard per entry → `add`/`unstage`/`restore`;
  Commit/Amend → `commit(message:amend:)`; Create branch → `createBranch`;
  Switch/Delete → `switchTo`/`deleteBranch`; Merge → `merge`;
  Abort/Continue merge → `mergeAbort`/`mergeContinue`; Rebase →
  `rebase(onto:)`; Abort/Skip/Continue rebase → `rebaseAbort`/`rebaseSkip`/
  `rebaseContinue`; Cherry-Pick → `cherryPick`; Stash → `stash`;
  Apply/Pop/Drop stash → `stashApply`/`stashDrop`; Create Snapshot →
  `snapshot`; Restore snapshot → `restoreSnapshot`; Add/Remove remote →
  `addRemote`/`removeRemote`; Fetch/Pull/Push → `fetch`/`pull`/`push`;
  GC → `gc`; Rebuild Index → `rebuildIndex`; Git import/export →
  `importGit`/`exportGit`. Refresh paths call `status`, `log`, `branches`,
  `tags`, `stashes`, `snapshots`, `timeline`, `health`, `fsck`, `info`,
  `diff`. The console no longer prints fake success: an unknown console
  command shows `spaces: unknown command '<cmd>'` (fixed in S8).
- **SpacesIntelligenceView** (379 lines): loads time-machine states
  (`timeMachineStates`), recovery checkpoints (`recoveryCheckpoints`),
  health history (`healthHistory`), dependency graph (`dependencyGraph` /
  `refreshDependencyGraph`), knowledge index (`refreshKnowledgeIndex` /
  `searchKnowledge`), semantic search (`semanticSearch`), history search
  (`historySearch`), file evolution (`fileEvolution`), change impact
  (`changeImpact`), change risk (`changeRisk`); actions restore time-machine
  state (`restoreTimeMachineState`), create/restore recovery checkpoint
  (`createRecoveryCheckpoint` / `restoreRecoveryCheckpoint`), refresh
  symbol index (`refreshSymbolIndex`), record health snapshot
  (`recordHealthSnapshot`).
- **SpacesReviewsView** (566 lines): loads reviews (`listReviews`), review
  policy (`reviewPolicy`), activity feed (`activityFeed`), ownership rules
  (`ownershipRules`), workspace templates (`workspaceTemplates`),
  notification rules (`notificationRules`), pending notifications
  (`pendingNotifications`), review status / comments / changes since
  approval / merge check (`reviewStatus`, `listComments`,
  `changesSinceApproval`, `reviewMergeCheck`), owners of path (`ownersOf`),
  session status (`sessionStatus`); actions create/approve review
  (`createReview` / `approveReview`), add/edit/resolve comment
  (`addComment` / `editComment` / `resolveComment`), save review policy
  (`setReviewPolicy`), save ownership rules (`setOwnershipRules`), create /
  apply workspace template (`createWorkspaceTemplate` /
  `applyWorkspaceTemplate`), create session / claim path / record
  resolution (`createSession` / `claimPath` / `recordResolution`), track
  change across branches (`trackChangeAcrossBranches` /
  `crossBranchStatus`), save notification rules (`setNotificationRules`),
  mark notifications seen (`markNotificationsSeen`).
- **SpacesSecurityView** (496 lines): loads repository policy
  (`repositoryPolicy`), secret history (`secretHistory`), classification
  rules (`classificationRules`), trust policy (`trustPolicy`), audit events
  (`auditEvents`), operation permissions / current role
  (`operationPermissions` / `currentRole`), protected history rules
  (`protectedHistoryRules`), dependency change audit
  (`dependencyChangeAudit`), security report (`generateSecurityReport`);
  actions save repository policy (`setRepositoryPolicy`), check policy
  (`checkPolicy`), classify path / repository (`classifyPath` /
  `classifyRepository`), verify provenance (`verifyProvenance`), save trust
  policy (`setTrustPolicy`), record audit event (`recordAuditEvent`), set
  role (`setRole`), check operation permission
  (`checkOperationPermission`), sign snapshot (`signSnapshot`), verify
  snapshot signature (`verifySnapshotSignature`), save protected history
  rules (`setProtectedHistoryRules`), check protected history
  (`checkProtectedHistory`).
- **SpacesStorageView** (539 lines): loads continuous snapshot config
  (`continuousSnapshotConfig`), snapshots (`snapshots`), retention policy
  (`retentionPolicy`), storage heatmap (`storageHeatmap`), vault entries
  (`vaultEntries`), compaction profiles (`compactionProfiles`), backups
  (`backups`), storage growth estimate (`storageGrowthEstimate`); actions
  save continuous snapshot config (`setContinuousSnapshotConfig`), capture
  workspace snapshot if due (`captureWorkspaceSnapshotIfDue`), branch from
  snapshot / check out snapshot (`branchFromSnapshot` / `checkoutSnapshot`),
  verify snapshot / all snapshots (`verifySnapshot` / `verifyAllSnapshots`),
  snapshot deduplication report (`snapshotDeduplicationReport`), save
  retention policy (`setRetentionPolicy`), apply retention policy
  (`applyRetentionPolicy`), record storage sample / growth estimate
  (`recordStorageSample` / `storageGrowthEstimate`), vault retain / restore
  (`vaultRetain` / `restoreFromVault`), apply compaction profile
  (`applyCompactionProfile`), create / verify / restore backup
  (`createBackup` / `verifyBackup` / `restoreBackup`).
- Every view surfaces real engine errors in the UI; there is no Git fallback
  on Spaces errors.

Project wiring: `project.yml` declares the `SpacesEngine` static-library
target, the `spaces` tool target, and the `SpacesEngineTests` unit-test
target, plus the ArgumentParser package; `Package.swift` declares the same
three targets for SwiftPM. `project.pbxproj` contains the `SpacesEngine`
target, the `spaces` target, and the `SpacesEngineTests` target with the
four new views in the YcodeUI SourceControl group — **structurally verified
only, never opened by Xcode** (S8's 123/123 file coverage claim is taken from
that slice's verification, not re-checked here). Regenerating the xcodeproj
from `project.yml` would still drop Spaces if run without care, per the
audit baseline.

## 5. §4 hardening

COMPLETE. Present in the engine and covered by 25 `HardeningTests`:
`commitWithMetadata`, commit validation pipeline, `signCommit` /
`signingIdentities` (HMAC identities, default + named keys under
`.spaces/signing-*.key`, mode 0600), branch owners / expirations / protection
/ activity / sync reports, conflict provenance / categorization / history /
resolution policies, binary diff, rename detection (same-OID delete+add
pairs, similarity fallback ≥ 0.5), directory comparison, transfer progress /
resume / reports / cancellation, `gcWithBudget`, vault + audit wiring
(`force-push` denials and branch deletes are audit-logged).
See §9 for the one follow-up found in S10.

## 6. Validation matrix, integration workflows, E2E scenario

All three new suites were written by S10 and statically verified only
(zero comments, balanced delimiters, every referenced symbol confirmed to
exist by grep). **0 tests executed here.**

### Validation matrix — `swiftcode/Tests/SpacesEngineTests/ValidationMatrixTests.swift` (578 lines, 30 `@Test`s)

One test per matrix row, all against real temp repos via `TestSupport`
(`Repository.create`, real filesystem operations, real assertions):

1. `initCreatesRepositoryAndReopens`
2. `initRejectsSecondInitAtSamePath`
3. `stageAddTracksFile`
4. `commitCreatesLogEntry`
5. `commitRejectsEmptyChange`
6. `branchCreateSwitchAndDelete`
7. `diffBetweenCommitsShowsChange`
8. `mergeCleanThreeWay`
9. `mergeConflictLeavesMarkers`
10. `conflictResolutionRestoresCleanTree` (provenance, history, resolved flag)
11. `historyLogShowAndBlame`
12. `snapshotCreateAndRestore`
13. `recoveryCorruptObjectDetectedByFsck` (corrupt a blob, fsck flags it,
    re-derive the object from the worktree copy, fsck clean)
14. `recoveryBrokenIndexRebuilt` (garbage index breaks `status`; delete the
    index file, `rebuildIndex` repopulates it from HEAD)
15. `repairReportsRebuiltIndex`
16. `searchContentFindsLine`
17. `searchHistoryFindsCommit`
18. `cliPathEquivalenceSpotCheck` (the same engine ops the CLI commands
    invoke: semantic search, history search, dependency graph, file
    evolution, branch stack + checkpoint, secret history, storage heatmap,
    backup create/verify, review create/status, policy check, performance
    profile, snapshot verification)
19. `gitImportSmallRepo` (skips with a reason via `Test.skip` when no git
    executable is present — never fakes success)
20. `gitExportRoundTrip` (same skip behaviour; verifies with the real git
    CLI: log messages, tag list, clean status)
21. `remotePushPullOverLocalPath` (push to a local-path remote, clone,
    commit on the remote, pull the clone)
22. `remoteCloneMatchesLog`
23. `integrityFsckCleanOnHealthyRepo`
24. `restartPersistence` (drop the repo object, `Repository.open`, head /
    log / snapshots intact)
25. `concurrentReadsDoNotCorrupt` (8 parallel `log()` calls, same count,
    fsck still clean)
26. `lockContentionFailsCleanly` (second `Repository` instance's
    `acquireLock` throws `repositoryLocked` while the first holds the lock;
    the repo stays usable afterwards)
27. `securitySecretScanFindsPlantedSecret` (planted `AKIA…` key found by
    `secretHistory` and counted by `generateSecurityReport`)
28. `protectedHistoryBlocksForcePush` (rule denies the force-push at the
    check and at a real divergent force-push)
29. `policyCheckRejectsBadCommit` (message-pattern rule blocks a bad commit
    via `validateCommit` and `commitValidated`, allows a good one)
30. `renameStagingPreservesObjectID` (move + commit yields a `.renamed`
    diff with identical old/new OIDs — the S1 assumption, now a test)

Git-test skip note: tests 19–20 use swift-testing's `Test.skip` when no git
executable is found (`/usr/bin/git`, `/opt/homebrew/bin/git`,
`/usr/local/bin/git`, then `PATH`). This relies on `Test.skip` existing in
the toolchain's swift-testing (Swift 6.x); if it does not, those two tests
fail to compile and the Mac gate must replace the skip with an explicit
recorded issue.

### Integration workflows — `swiftcode/Tests/SpacesEngineTests/IntegrationWorkflowTests.swift` (117 lines, 4 `@Test`s)

- `branchMergeSnapshotRestoreWorkflow`: init → add → commit → branch →
  commit on branch → merge back → snapshot → corrupt a worktree file →
  restore from snapshot → content verified, status clean.
- `tagBundleExportImportWorkflow`: init → commit → tag → bundle export →
  fresh directory → bundle import → log OIDs, tag, and checked-out file
  contents match.
- `reviewApproveMergeWorkflow`: create review → add discussion → approve →
  merge check passes → merge; the pre-approval merge check is asserted to
  fail first.
- `remoteBackupRestoreWorkflow`: push to a local-path remote → backup create
  + verify → restore the backup into a fresh repo → clone the remote and
  verify the file.

### E2E scenario — `swiftcode/Tests/SpacesEngineTests/EndToEndScenarioTests.swift` (340 lines, 1 `@Test`, 30 steps)

`thirtyStepAcceptanceScenario` runs steps 1–30 in sequence, each step a
labelled sub-check; a failure throws `StepFailure`, which names the step
number and label: 1 init, 2 add files, 3 commit, 4 branch, 5 switch, 6 edit +
commit on branch, 7 switch back, 8 merge, 9 deliberate conflict + resolve,
10 tag, 11 snapshot, 12 modify + restore snapshot, 13 timeline, 14
semantic/symbol search, 15 history search, 16 impact analysis, 17 checkpoint
create + restore, 18 review create + approve, 19 security scan + report,
20 backup create + verify, 21 storage report, 22 fsck clean, 23 export
bundle, 24 import bundle into fresh repo, 25 remote add + push +
clone-equivalent pull, 26 Git import of a small git repo, 27 Git export,
28 reopen repo, 29 concurrent read safety, 30 full log/history intact.

Steps 26–27 do **not** skip the whole scenario when git is missing: they
record an `Issue` naming the step and let the remaining steps run, so the
test fails honestly naming the missing step instead of silently passing.
No step depends on an API that does not exist; every step uses a real API
verified on disk. The one design compromise is in step 18: the review's head
is the current HEAD (a merge commit), which is what makes
`changesSinceApproval` empty and the merge check pass — the review workflow
with a diverging head is covered separately by
`reviewApproveMergeWorkflow`.

### Test counts

| File | `@Test` funcs |
|---|---|
| AdvancedVCTests | 10 |
| CLIContractTests | 30 |
| CollaborationTests | 11 |
| CoreFlowTests | 9 |
| DetectionTests | 8 |
| EndToEndScenarioTests | 1 |
| HardeningTests | 25 |
| InfraTests | 11 |
| IntegrationWorkflowTests | 4 |
| IntelligenceTests | 10 |
| MergeTests | 12 |
| ObjectStoreTests | 6 |
| SecurityTests | 10 |
| StorageTests | 10 |
| ToolingTests | 11 |
| ValidationMatrixTests | 30 |
| TestSupport | 0 |
| **Total** | **198** |

163 existed before this slice; 35 are new (30 + 4 + 1).

## 7. `tools/clean.py` and the repo-wide cleanup

COMPLETE. `tools/clean.py` (505 lines, executable) is a string-aware Swift
comment stripper built on the `comments.py` Stripper engine, with
`--dry-run` / `--check` / `--diff` / `--target` / `--verbose`, per-file and
count reporting, and idempotence. Verified run results (exactly as recorded
by S9 and re-stated here without change):

- Scanned **4,636 files**, modified **213**, removed **3,418 comments**.
- Line counts unchanged on all 213 modified files; 4,423 unmodified files
  byte-identical.
- Second run: **0 changes**, `--check` exit **0**.
- Brace/paren/bracket balance identical before/after; license headers and
  `swift-tools-version` preserved.
- Sample review of 14 files (raw strings, multiline strings, URLs in
  strings, the only 2 real block comments in the repo) showed comment-only
  changes. `EditorTextCommandsTests.swift` was correctly untouched
  (`//` and `/*` inside `"""` fixtures).
- Real bug found and fixed by S9 in the inherited `comments.py` engine:
  its line-comment branch emitted the terminator newline twice, doubling
  newlines after every `//` comment; `clean.py` does not emit the
  terminator. `comments.py` itself was not modified (prior art only).
- Caveats: no genuine nested block comment exists in the repo (nesting
  proven by synthetic tests only); no regex literals in the modified set
  (regex handling synthetic-tested only); no Swift build/test of the cleaned
  sources (no toolchain here).

Dylan's absolute rule (zero comments in new Swift files) is honoured by
every file written in Waves 1–4: the three new S10 test files contain
0 `//` and 0 `/*` occurrences (verified by grep).

## 8. Git compatibility limitations

PARTIAL. Git interop is real (shells out to the git CLI), not a wrapper
around a fake format, but it has these evidenced limits:

- **Requires a git executable.** `GitMigration.findGit` looks in
  `/usr/bin/git`, `/opt/homebrew/bin/git`, `/usr/local/bin/git`, then
  `PATH`; without one, import/export throw `migrationError`. Spaces itself
  needs no git.
- **Import is lossy by design.** SHA-1 git objects are converted to SHA-256
  Spaces objects (blobs/trees bottom-up, commits parent-first, annotated
  tags), refs are mapped, authors/committers (name, email, timestamp) are
  preserved. Import reports warnings instead of failing on unconvertible
  trees, unparseable commits, unresolved parents, and unimported ref
  targets. No submodule/gitlink handling, no GPG-signature handling, no
  notes, and no LFS handling were found in `GitMigration.swift` — a repo
  using those will import without them, silently, apart from the warnings
  above.
- **Export writes a fresh `.git`.** `git init` + `hash-object` /
  `mktree` / `commit-tree` / `mktag` / `update-ref`, preserving history,
  authors, and tags. It does not preserve the source repo's remotes,
  configuration, hooks, or reflogs, and it produces a new repository rather
  than updating an existing one.
- **Untested here.** Import/export are covered by the new matrix tests
  (`gitImportSmallRepo`, `gitExportRoundTrip`) and E2E steps 26–27, none of
  which have been executed (no toolchain). A live git repo with branches,
  tags, and merges has not been round-tripped and compared by hand.

## 9. S10 re-checks

### (a) S1 rename assumption — HOLDS

`StagingOps.move` removes the old index entry and re-inserts the **same**
`IndexEntry` (same blob OID) under the new path after moving the file.
`DiffOps` pairs a same-OID delete+add as a rename (similarity 1.0, with a
≥ 0.5 byte-similarity fallback for edited renames), and
`FileEvolutionOps` surfaces that as `.renamed`. The assumption in
`IntelligenceTests.fileEvolutionFollowsRename` is therefore correct, and
S10 now pins it with `renameStagingPreservesObjectID`, which asserts the
diff is `.renamed` with identical old/new OIDs.

### (b) S3 compile risks — judged not real (Swift 6 rules), still Mac-gate

- `StorageHeatmapOps`: `sizeBands[sizeLabel]?.count += 1` (dictionary
  subscript + optional chaining + compound assignment). Not a real risk:
  `Dictionary`'s subscript is get/set, and assignment through optional
  chaining writes back through the subscript — this idiom compiles.
- `IncrementalBackupOps` / `BundleOps`: `withUnsafeBytes(of: version.bigEndian)`
  and `withUnsafeBytes(of: &headerLen)`. Not a real risk: the standard
  library provides both a by-value and an `inout` overload of
  `withUnsafeBytes(of:)`; the identical pattern already exists in Dylan's
  own `BundleOps`.
- `StorageTests` `Thread.sleep(forTimeInterval: 1.1)` in the growth test:
  real, but trivial — it slows the suite by ~1 second; it is not a compile
  risk and not worth changing.

### (c) S4 risks — judged not real (Swift 6 rules), still Mac-gate

- Implicit-return `performTransaction` calls: not a real risk. Every
  inspected call site is a single-expression closure whose only statement
  is a `Void`-returning save, so no `return` is required.
- `WorkspaceTemplateOps.applyTemplate` method/local shadowing
  (`let template = try template(name)`): not a real error — the local is
  not in scope inside its own initializer, so the right-hand side resolves
  to the `template(_:)` method.
- `for ... in ... where` in `NotificationOps.pendingNotifications`: valid
  Swift, not a risk.

### (d) S6 risks

None were recorded in the audit for S6, and S10 found none on re-read.

### (e) CLI duplicate names — re-verified statically

162 registered, 162 unique derived top-level names, 0 duplicates
(positional script; the first regex-based attempt cross-matched
`commandName:` across struct boundaries and was discarded). The `git`
group-subcommand question is refuted again (see §3). Whether ArgumentParser
traps on duplicates at launch remains UNVERIFIED without a toolchain.

### (f) Counts

- Engine: 99 Swift files, 15,526 lines (`swiftcode/Sources/SpacesEngine/`).
- CLI: 6 files, 3,989 lines (`swiftcode/Sources/spaces/`).
- Tests: 17 files, 3,538 lines, 198 `@Test` funcs
  (`swiftcode/Tests/SpacesEngineTests/`).
- UI views: 5 files, 2,916 lines (`SpacesWorkspaceView` + 4 feature views).
- `SpacesService`: 414 lines. Docs: `SPACES.md` 284 lines;
  `tools/clean.py` 505 lines.
- Total Spaces Swift: 26,383 lines across engine, CLI, tests, views, and
  `SpacesService`.

### Fixes made by S10 and the coordinator

**S10:** none. No engine, CLI, UI, or project file was edited in this slice.
The re-checks judged every flagged compile risk not real, and the one real
finding (`rebuildIndex` on a corrupt-but-present index, §1) sat in
`Maintenance.swift`, outside the S10 fix scope, so it was recorded as a
Mac-gate item instead of patched. New files only: the three test suites and
this report.

**Coordinator (after S10):** applied the one-line `rebuildIndex` tolerance
fix in `Maintenance.swift` (`(try? repo.index()) ?? Index()` for the
carry-over read) and extended `ValidationMatrixTests.recoveryBrokenIndexRebuilt`
to assert the direct rebuild on a corrupt-but-present index as well as the
delete-first path. Statically verified only; the Xcode test run is the proof.

## 10. Open decisions and Mac-gate checklist

Open decisions (for Dylan / the coordinator, not decided here):

1. Dual-role worktree/workspace structs: de-register the top-level aliases
   or keep the redundant group paths (`spaces worktree worktree-add`)?
2. `merge-strategy` / `merge-strategies`: implement a real engine-backed
   strategy listing, or remove the commands?
3. B19 multi-stage finalize: scope `finalizeStagedCommit` to the recorded
   paths, or document whole-index finalization as the behaviour?

Mac gate (Dylan's Mac, in order):

1. Open the project in Xcode (never done for the Spaces targets;
   `project.pbxproj` was only structurally verified). If Xcode flags the
   edited project file, stop there.
2. Confirm the `SpacesEngine`, `spaces`, and `SpacesEngineTests` targets
   build (including the `CQuickJS`-style question for any new target
   reference — note the Spaces targets are declared in `project.yml` and
   `Package.swift`; confirm Xcode picks them up).
3. Run `swift test` / the Xcode test target: 198 `@Test` funcs, including
   the 30-step E2E scenario. Investigate any failure by step number
   (E2E) or matrix-row name.
4. Run the `spaces` binary: `spaces --help` (confirm no duplicate-name
   trap at launch), then a live E2E pass of steps 1–30 against a real
   directory, plus a real Git import/export round-trip.
5. Confirm the flagged compile risks (§9b–c) and the `Test.skip` usage
   compile cleanly under Swift 6.2 / Xcode 27, and confirm the
   `rebuildIndex` tolerance fix behaves as the extended recovery test
   expects.
6. Visual check of the four new views and the Spaces sidebar in the app,
   and the Settings source-control picker.

## 11. Files delivered by S10

- `swiftcode/Tests/SpacesEngineTests/ValidationMatrixTests.swift` — 578
  lines, 30 `@Test` funcs, 0 comments.
- `swiftcode/Tests/SpacesEngineTests/IntegrationWorkflowTests.swift` — 117
  lines, 4 `@Test` funcs, 0 comments.
- `swiftcode/Tests/SpacesEngineTests/EndToEndScenarioTests.swift` — 340
  lines, 1 `@Test` func (30 steps), 0 comments.
- `docs/SPACES-COMPLETION-REPORT.md` — this report.

No other files were created, modified, committed, or pushed by this slice.
