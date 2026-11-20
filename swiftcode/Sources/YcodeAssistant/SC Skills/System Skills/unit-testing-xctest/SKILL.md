---
name: unit-testing-xctest
description: "Write and maintain XCTest unit tests including async tests and setup/teardown."
category: Testing
tags: [xctest, unit tests, async tests]
tools: [scan_xctassert_usage, scan_test_expectations, test_run_single]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Unit Testing Xctest

Write and maintain XCTest unit tests including async tests and setup/teardown.

## When to use this skill
- The user asks for work involving: xctest, unit tests, async tests.
- You are about to change code in the Testing area and want SwiftCode's standard workflow.

## Workflow
1. Create XCTestCase subclasses per unit.
2. Use async throws test methods instead of expectations where possible.
3. Use setUp/tearDown for fresh fixtures.
4. Use XCTAssertEqual with accuracy for floats and XCTUnwrap for optionals.
5. Run with xcodebuild test or swift test.

## Rules
- No shared mutable state between tests.
- Fail with messages that explain the expectation.

## Verification
- [ ] Tests isolated and deterministic.
- [ ] CI runs them.

## Avoid
- wait(for:timeout:) with large timeouts.
- Force unwraps in tests.

## Recommended SwiftCode tools
- `scan_xctassert_usage`
- `scan_test_expectations`
- `test_run_single`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
