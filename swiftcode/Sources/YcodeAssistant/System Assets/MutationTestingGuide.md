<!-- system-index-depends: UnitTestingBestPractices.md -->
# Mutation Testing & Assertion Coverage Verification

Methodology for assessing the true semantic strength of a test suite by introducing synthetic mutants into production source code.

---

## 1. What is Mutation Testing?
Line coverage alone can be deceptive: a test might execute 100% of the lines in a function without asserting any meaningful outputs.
- **Mutant:** A synthetically altered copy of production code (e.g. flipping `>` to `<`, changing `+` to `-`, removing a function call).
- **Killed Mutant:** A test fails when run against the mutated code. (Desired outcome).
- **Surviving Mutant:** All tests pass despite the corrupted logic. (Indicates missing assertions or dead code).

---

## 2. Common Mutation Operators
- **Conditional Boundary:** Change `<` to `<=`, `>` to `>=`.
- **Inverted Negatives:** Change `if condition` to `if !condition`.
- **Return Value Replacement:** Replace return values with `nil`, `false`, `0`, or `""`.
- **Statement Deletion:** Delete critical notification dispatches or cache write statements.

---

## 3. Workflow for Verifying Test Suite Robustness
1. Identify high-risk business logic (e.g., authentication checks, licensing validation, file mutation parsers).
2. Manually or programmatically introduce a mutation into the method.
3. Execute `project_test` or run targeted unit tests.
4. Verify that the test suite fails immediately.
5. If tests pass, identify the missing assertion and write a new unit test targeting the boundary condition.
6. Revert the mutation and verify green tests.
