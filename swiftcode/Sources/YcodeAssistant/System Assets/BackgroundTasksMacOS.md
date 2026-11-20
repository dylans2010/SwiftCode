# Background Tasks on macOS

<!-- system-index-depends: AppLifecycleAndScenes.md -->

macOS apps do background work under strict rules: the system decides when
background work runs, for how long, and under what conditions. Assist
designs background work to fit those rules instead of fighting them.

## When to retrieve

- The user wants work to happen while the app is in the background.
- A scheduled refresh, sync, or maintenance task needs designing.
- Background work is unreliable, delayed, or never runs.

## What the system offers

- Short background refresh tasks: brief, scheduled work such as syncing
  or fetching, with no guarantee of exact timing.
- Processing tasks: longer work such as indexing or cleanup, run when the
  machine is idle and on power.
- App refresh driven by the system, not by the app. The app requests; the
  system schedules.
- Background execution tied to a user-visible reason: audio, downloads,
  or a running service the user started. There is no general "run
  forever" mode.

## Design rules

- Work must be interruptible and resumable. The system can end a task at
  any time, and the app must not lose data when it does.
- Break work into small units with checkpoints. A task that cannot resume
  is a task that will repeat or corrupt.
- Respect the budget: the system throttles apps that waste background
  time. Efficient work gets scheduled more often.
- Never use background work to keep the app alive for foreground
  purposes. That is the pattern the system is designed to stop.
- Handle the case where the task never runs. The app must still work when
  opened, with stale data clearly marked as stale.

## Debugging background work

- Log task start, progress, and completion with timestamps. Without logs,
  background behavior is invisible.
- Check the schedule, not just the code: a task that is never scheduled
  is a registration problem, not a logic problem.
- Test on a real machine under real conditions. Simulators and always-on
  developer machines hide scheduling behavior.
- Verify the entitlement and the task identifier match exactly. A typo
  here fails silently.

## Common mistakes

- Assuming a scheduled task runs at the requested time. It runs when the
  system chooses.
- Doing network work without handling offline, captive portals, and
  metered connections.
- Writing partial state and treating it as complete on the next launch.
- Registering the task but never submitting a request for it.

## Cross-references

- App lifecycle: `AppLifecycleAndScenes.md`
- Feature flags and rollout: `FeatureFlagsAndRollout.md`
- Performance budgets: `PerformanceBudgets.md`

## Limits

- Assist designs within the system's scheduling model. It cannot make the
  system run a task on a schedule the system does not offer.
