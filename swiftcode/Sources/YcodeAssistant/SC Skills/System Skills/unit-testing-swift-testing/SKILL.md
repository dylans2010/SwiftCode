---
name: unit-testing-swift-testing
description: "Write focused unit tests with Swift Testing (@Test, #expect, parameterized tests)."
category: Testing
tags: [testing, swift testing, unit tests]
tools: [swift_list_test_functions, swift_generate_test_skeleton, swiftpm_run_filtered_tests, scan_swift_testing_macros]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Unit Testing Swift Testing

Write focused unit tests with Swift Testing (@Test, #expect, parameterized tests).

## When to use this skill
- The user asks for work involving: testing, swift testing, unit tests.
- You are about to change code in the Testing area and want SwiftCode's standard workflow.

## Workflow
1. Identify the unit's public behavior and edge cases.
2. Generate a suite with swift_generate_test_skeleton and fill real assertions.
3. Use @Test(arguments:) for input tables and #require for preconditions.
4. Inject dependencies via protocols; avoid network and clock.
5. Run only the new tests with swiftpm_run_filtered_tests, then the full suite.

## Rules
- One behavior per test; descriptive names.
- Tests must fail before the fix and pass after.

## Verification
- [ ] New tests pass and fail when the code is broken.
- [ ] No sleeps in tests.

## Avoid
- Asserting implementation details.
- Tests that depend on order.

## Recommended SwiftCode tools
- `swift_list_test_functions`
- `swift_generate_test_skeleton`
- `swiftpm_run_filtered_tests`
- `scan_swift_testing_macros`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
