---
name: test-driven-development
description: "Apply red-green-refactor TDD for new features and bug fixes."
category: Testing
tags: [tdd, testing, refactoring]
tools: [swiftpm_run_filtered_tests, swift_generate_test_skeleton]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Test Driven Development

Apply red-green-refactor TDD for new features and bug fixes.

## When to use this skill
- The user asks for work involving: tdd, testing, refactoring.
- You are about to change code in the Testing area and want SwiftCode's standard workflow.

## Workflow
1. Write a failing test describing the behavior.
2. Run it and confirm it fails for the right reason.
3. Write the minimum code to pass.
4. Refactor with tests green.
5. Repeat for the next behavior.

## Rules
- Never skip the red step.
- Commit at green.

## Verification
- [ ] Each behavior has a test.
- [ ] All tests pass.

## Avoid
- Writing all tests after the code.
- Huge steps.

## Recommended SwiftCode tools
- `swiftpm_run_filtered_tests`
- `swift_generate_test_skeleton`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
