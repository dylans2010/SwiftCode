---
name: integration-testing
description: "Write integration tests that exercise real components together."
category: Testing
tags: [integration tests, testing, end-to-end]
tools: [swiftpm_run_filtered_tests, http_get_request]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Integration Testing

Write integration tests that exercise real components together.

## When to use this skill
- The user asks for work involving: integration tests, testing, end-to-end.
- You are about to change code in the Testing area and want SwiftCode's standard workflow.

## Workflow
1. Define the boundary under test.
2. Use real implementations with test configuration (temp dirs, in-memory DB, local server).
3. Seed and clean data per test.
4. Run in CI separately if slow.

## Rules
- Isolate from production services.
- Deterministic data.

## Verification
- [ ] Tests pass in CI.
- [ ] Cleanup verified.

## Avoid
- Hitting production APIs.
- Order-dependent tests.

## Recommended SwiftCode tools
- `swiftpm_run_filtered_tests`
- `http_get_request`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
