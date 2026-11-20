---
name: refactoring-safely
description: "Refactor code in small, behavior-preserving steps backed by tests."
category: Code Quality
tags: [refactoring, clean code, tests]
tools: [file_long_functions_report, file_nesting_depth_report, swift_symbol_references, file_rename_identifier]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Refactoring Safely

Refactor code in small, behavior-preserving steps backed by tests.

## When to use this skill
- The user asks for work involving: refactoring, clean code, tests.
- You are about to change code in the Code Quality area and want SwiftCode's standard workflow.

## Workflow
1. Ensure tests cover the code (add characterization tests if not).
2. Pick one smell (long function, deep nesting, duplication).
3. Apply one refactoring at a time (extract, rename, move).
4. Build and test after each step.
5. Commit frequently.

## Rules
- No behavior changes during refactors.
- Keep public API stable unless agreed.

## Verification
- [ ] Tests green after each step.
- [ ] Metrics improved.

## Avoid
- Big-bang rewrites.
- Refactor + feature in one commit.

## Recommended SwiftCode tools
- `file_long_functions_report`
- `file_nesting_depth_report`
- `swift_symbol_references`
- `file_rename_identifier`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
