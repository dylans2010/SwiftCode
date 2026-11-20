---
name: async-testing-patterns
description: "Test async/await, actors and AsyncSequence code deterministically."
category: Testing
tags: [async tests, actors, concurrency testing]
tools: [swift_list_async_functions, scan_thread_sleep]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Async Testing Patterns

Test async/await, actors and AsyncSequence code deterministically.

## When to use this skill
- The user asks for work involving: async tests, actors, concurrency testing.
- You are about to change code in the Testing area and want SwiftCode's standard workflow.

## Workflow
1. Write async test functions and await results directly.
2. Inject clocks to control time-based logic.
3. Collect AsyncSequence values with bounded loops or prefix.
4. Test cancellation by cancelling tasks and asserting cleanup.
5. Use confirmation() in Swift Testing for event counts.

## Rules
- No sleeps.
- Deterministic ordering.

## Verification
- [ ] Tests pass 50 times in a row.
- [ ] Cancellation tested.

## Avoid
- Polling loops with timeouts.
- Unstructured tasks escaping tests.

## Recommended SwiftCode tools
- `swift_list_async_functions`
- `scan_thread_sleep`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
