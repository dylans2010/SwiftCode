# Refactoring Legacy Code

<!-- system-index-depends: BuildAndTesting.md -->

Refactoring legacy code means changing its structure without changing its
behavior. The code works today and users depend on it; the refactor earns
its keep by making the next change safer, not by making the code prettier.

## Before touching anything

- Characterize first: run the existing tests, or write a characterization
  test that pins the current behavior, before changing a line.
- Read the callers, not just the function. A legacy function is defined
  by who calls it and what they assume, not by its body.
- Find the seams: the places where the code can be split without changing
  behavior. A seam is a function boundary, a protocol, or a data boundary.
- Commit the characterization tests separately, with the code untouched,
  so the refactor diff contains only the refactor.

## Rules for safe refactors

- One behavior-preserving change per commit. Renaming, extraction, and
  restructuring are separate commits, never one mixed diff.
- Never mix a refactor with a behavior change in the same commit. Reviewers
  cannot tell which lines are safe and which are new behavior.
- Never rename a public symbol and change its behavior in the same step.
- Extract before you rewrite. Pull a block into a named function, verify
  tests pass, then change the function's internals.
- Delete dead code only when you can prove it is dead: no callers, no
  dynamic dispatch, no reflection, no Interface Builder reference.
- Keep the old API working during a migration: add the new API, migrate
  callers one by one, then remove the old one. Never a flag day.

## Dealing with the hard parts

- Global mutable state: introduce a parameter or a small container object
  and pass it explicitly. Do not add another global to fix a global.
- Massive view controllers: extract one responsibility at a time (data
  loading, formatting, navigation), verifying tests after each extraction.
- Stringly-typed code: introduce an enum or a small type for the values
  that are compared in more than one place, and convert at the boundary.
- Implicit ordering dependencies: make the order explicit in the code
  (a sequenced list, a state machine) instead of relying on call order.
- Concurrency hazards: do not refactor threaded code by feel. Add a test
  that reproduces the race, then fix the isolation, then refactor.

## When not to refactor

- Code that is about to be deleted. Let it die unrefactored.
- Code with no tests and no way to verify behavior. Write the tests first,
  or leave the code alone.
- A refactor with no consumer: "cleaner" is not a reason. The reason is
  the next feature, the next bug fix, or a measured performance problem.
- Under a release deadline. Refactors belong in the cycle after the
  release, not the week before it.

## Verification

- All characterization tests pass before and after, unchanged.
- The diff contains no behavior change: no new branches, no changed
  constants, no altered control flow.
- Build and full test suite pass; the app's manual smoke test passes.
