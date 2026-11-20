# Concurrency Debugging

<!-- system-index-depends: ActorsAndIsolation.md, Swift6Concurrency.md -->

Concurrency bugs are timing bugs: they appear under load, disappear under
a debugger, and return in production. This asset covers how Assist
diagnoses races, deadlocks, and isolation violations systematically.

## When to retrieve

- A crash or wrong result appears intermittently or under load.
- A data race, deadlock, or actor-isolation error needs diagnosis.
- A concurrency fix needs verification, not just a hopeful edit.

## First steps

- Reproduce under the sanitizer before reading code. Thread Sanitizer
  finds races a code review will miss, and it names the accesses.
- Get the exact failure: the crash report, the sanitizer output, or the
  wrong value, with the thread and the access pattern.
- Reduce the reproduction: fewer threads, fewer operations, and a smaller
  input, until the failure is reliable or the reduction itself reveals
  the cause.
- Check the isolation boundary first: which actor, task, or queue owns
  the shared state, and who else touches it.

## Bug families and their signatures

- Data race: two threads access the same mutable state, at least one
  writes, and there is no synchronization. The symptom is a wrong value
  or a crash that moves.
- Deadlock: two or more parties wait on each other forever. The symptom
  is a hang with threads parked on locks or actor isolation.
- Main-actor violation: UI state touched from a background context. The
  symptom is a runtime warning, a crash, or a UI that updates late.
- Unstructured task leak: tasks that outlive their purpose and keep
  running, holding resources or writing stale results.

## Diagnosis discipline

- Name the shared state, its owner, and every accessor before proposing
  a fix. A fix for the wrong state is a new bug.
- Prefer the smallest synchronization that is correct: an actor, a lock,
  or a serial queue, chosen for the access pattern, not by habit.
- Verify the fix under the sanitizer with the same reproduction that
  found the bug. A fix that is not re-tested is a guess.

## Common mistakes

- Treating a crash in system code as a system bug when the app's thread
  handed it bad state.
- Adding a lock around one access and leaving the other accesses
  unprotected.
- Sharing mutable state through a capture list and forgetting the capture
  is the sharing.
- Assuming Swift 6's compiler checks catch every race. They catch
  isolation errors; logic races still need review and sanitizers.

## Cross-references

- Actors and isolation: `ActorsAndIsolation.md`
- Swift 6 concurrency: `Swift6Concurrency.md`
- Memory safety: `MemorySafetyAndPointers.md`

## Limits

- Assist diagnoses from evidence: sanitizer output, crash logs, and code.
  It cannot prove a concurrent program correct; it can only show that the
  known failure is fixed and no new failure appears under test.
