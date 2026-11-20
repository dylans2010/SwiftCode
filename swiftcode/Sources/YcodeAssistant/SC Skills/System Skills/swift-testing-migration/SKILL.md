---
name: swift-testing-migration
description: "Migrate XCTest suites to Swift Testing incrementally."
category: Testing
tags: [swift testing, xctest, migration]
tools: [scan_xctassert_usage, scan_swift_testing_macros, swift_list_test_functions]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Swift Testing Migration

Migrate XCTest suites to Swift Testing incrementally.

## When to use this skill
- The user asks for work involving: swift testing, xctest, migration.
- You are about to change code in the Testing area and want SwiftCode's standard workflow.

## Workflow
1. Inventory XCTest cases.
2. Convert one suite at a time: XCTAssertEqual → #expect, XCTUnwrap → #require.
3. Use @Suite and parameterized @Test to remove duplication.
4. Run both frameworks side by side until done.

## Rules
- Keep coverage constant.
- Do not mix frameworks in one type.

## Verification
- [ ] Test count unchanged or higher.
- [ ] All tests pass.

## Avoid
- Big-bang conversion.
- Dropping performance tests (keep XCTest for measure).

## Recommended SwiftCode tools
- `scan_xctassert_usage`
- `scan_swift_testing_macros`
- `swift_list_test_functions`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
