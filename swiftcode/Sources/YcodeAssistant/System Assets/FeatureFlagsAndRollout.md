# Feature Flags and Rollout

<!-- system-index-depends: BuildAndTesting.md, ExecutionPlans.md -->

Feature flags separate deployment from release: code ships dark, then
turns on for a cohort, a percentage, or everyone. This asset covers how
Assist designs flags and rollouts that can be reversed safely.

## When to retrieve

- The user is adding a flag or planning a phased rollout.
- A feature needs a kill switch or an experiment.
- A rollout went wrong and needs a post-mortem.

## Flag discipline

- Every flag has a name, an owner, a default, and a removal date. A flag
  without a removal date becomes permanent configuration.
- Flags are typed and validated. A flag that can hold any value will
  eventually hold a wrong value.
- The default is the safe state. If the flag system is unreachable, the
  app behaves as if the flag were off.
- Flags are read once per decision point, not cached forever. A stale
  cached flag defeats the kill switch.
- Old flags are removed. A codebase full of dead flags is a codebase
  nobody understands.

## Rollout design

- Roll out in stages: internal, a small percentage, half, then everyone.
  Each stage has a check before the next begins.
- Define the rollback condition before the rollout starts: which metric,
  which threshold, and who decides.
- Keep the old path working until the new path has proven itself. A
  rollout without a working old path is a migration, not a rollout.
- Segment deliberately: by build, by user group, or by capability, and
  say which. Random percentage alone is a weak segmentation.

## Failure handling

- A flag evaluation failure defaults to off and logs the failure. It
  never crashes and never enables an untested path.
- A bad rollout is reversed by the flag, not by a new release. If reversal
  needs a release, the flag was not a kill switch.
- Record what was rolled out, to whom, and when. A rollout without a
  record cannot be audited or repeated.

## Common mistakes

- Shipping a flag that is never removed and becomes load-bearing.
- Rolling out to everyone at once because the stages were skipped.
- Caching a flag value for the app's lifetime.
- Using a flag to hide unfinished work instead of finishing it.

## Cross-references

- Build and testing: `BuildAndTesting.md`
- Execution plans: `ExecutionPlans.md`
- Release notes and versioning: `ReleaseNotesAndVersioning.md`

## Limits

- Flags manage risk; they do not remove it. A flag cannot make an
  untested feature safe, only unexposed.
