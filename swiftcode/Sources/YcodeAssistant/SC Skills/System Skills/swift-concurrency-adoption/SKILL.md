---
name: swift-concurrency-adoption
description: "Adopt async/await, actors and Sendable safely in existing Swift code."
category: Concurrency
tags: [concurrency, async await, actors, sendable]
tools: [scan_dispatch_main_queue, scan_dispatch_semaphores, scan_unchecked_sendable, scan_task_detached]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Swift Concurrency Adoption

Adopt async/await, actors and Sendable safely in existing Swift code.

## When to use this skill
- The user asks for work involving: concurrency, async await, actors, sendable.
- You are about to change code in the Concurrency area and want SwiftCode's standard workflow.

## Workflow
1. Inventory GCD usage with dispatch scans.
2. Convert completion handlers to async with withCheckedThrowingContinuation.
3. Isolate UI state with @MainActor and shared mutable state in actors.
4. Fix Sendable warnings by making types immutable or actor-isolated.
5. Enable strict concurrency checking and fix diagnostics.

## Rules
- Never block threads waiting for async work.
- Resume continuations exactly once.

## Verification
- [ ] Strict concurrency builds clean.
- [ ] No semaphores bridging async code.

## Avoid
- @unchecked Sendable to silence warnings.
- Task.detached by default.

## Recommended SwiftCode tools
- `scan_dispatch_main_queue`
- `scan_dispatch_semaphores`
- `scan_unchecked_sendable`
- `scan_task_detached`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
