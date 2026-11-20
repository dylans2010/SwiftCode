---
name: flaky-test-stabilization
description: "Find and fix flaky tests caused by timing, order and shared state."
category: Testing
tags: [flaky tests, stability, testing]
tools: [scan_thread_sleep, scan_test_expectations, swiftpm_run_filtered_tests]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Flaky Test Stabilization

Find and fix flaky tests caused by timing, order and shared state.

## When to use this skill
- The user asks for work involving: flaky tests, stability, testing.
- You are about to change code in the Testing area and want SwiftCode's standard workflow.

## Workflow
1. Re-run the test many times to measure flakiness.
2. Look for sleeps, shared state, real clocks and network.
3. Inject clocks and fakes; await conditions.
4. Re-run 50 times to confirm.

## Rules
- Never just raise timeouts.
- Quarantine with a ticket if not fixable now.

## Verification
- [ ] 50 consecutive passes.
- [ ] Root cause documented.

## Avoid
- Retry-until-pass wrappers.
- Deleting flaky tests silently.

## Recommended SwiftCode tools
- `scan_thread_sleep`
- `scan_test_expectations`
- `swiftpm_run_filtered_tests`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
