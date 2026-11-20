---
name: regression-test-for-bugs
description: "Reproduce every bug with a failing regression test before fixing it."
category: Testing
tags: [bugs, regression, debugging]
tools: [swiftpm_run_filtered_tests, git_log_pickaxe, git_file_history]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Regression Test For Bugs

Reproduce every bug with a failing regression test before fixing it.

## When to use this skill
- The user asks for work involving: bugs, regression, debugging.
- You are about to change code in the Testing area and want SwiftCode's standard workflow.

## Workflow
1. Reproduce the bug manually and capture inputs.
2. Write a minimal failing test.
3. Find the root cause (git_log_pickaxe/git_file_history help).
4. Fix and confirm the test passes.
5. Run the full suite.

## Rules
- The regression test name references the bug.
- Fix the cause, not the symptom.

## Verification
- [ ] Test fails on old code, passes on new.
- [ ] No unrelated tests broke.

## Avoid
- Fixing without reproducing.
- Deleting failing tests.

## Recommended SwiftCode tools
- `swiftpm_run_filtered_tests`
- `git_log_pickaxe`
- `git_file_history`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
