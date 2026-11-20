<!-- system-index-depends: BuildAndTesting.md, AgentMode.md -->
# Autonomous Verification Protocols & Quality Gates

Mandatory verification procedures every autonomous agent turn must complete before marking an objective resolved.

---

## 1. Pre-Flight Verification
- Verify workspace path validity and active project selection.
- Snapshot initial git status or create a project snapshot.

---

## 2. Post-Flight Verification
- **Compilation Gate:** Ensure exit code 0 on `project_build`.
- **Test Gate:** Execute `project_test` across all affected test suites.
- **Diff Hygiene:** Check `git diff` to confirm zero unintended whitespace or syntax pollution.
- **Reporting Gate:** Provide structured, evidence-grounded summary to the user.
