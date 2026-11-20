---
name: main-thread-ui-updates
description: "Guarantee UI updates happen on the main actor without blocking it."
category: Concurrency
tags: [main actor, ui thread, responsiveness]
tools: [scan_main_thread_checks, scan_dispatch_main_queue, scan_main_actor_annotations]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Main Thread Ui Updates

Guarantee UI updates happen on the main actor without blocking it.

## When to use this skill
- The user asks for work involving: main actor, ui thread, responsiveness.
- You are about to change code in the Concurrency area and want SwiftCode's standard workflow.

## Workflow
1. Annotate UI models with @MainActor.
2. Move CPU work into nonisolated async functions or actors.
3. Replace DispatchQueue.main.async with MainActor.run or isolation.
4. Enable Main Thread Checker.

## Rules
- Nothing over a few ms on main.
- No sync waits on main.

## Verification
- [ ] Main Thread Checker clean.
- [ ] No hangs reported.

## Avoid
- DispatchQueue.main.sync.
- Heavy JSON parsing on main.

## Recommended SwiftCode tools
- `scan_main_thread_checks`
- `scan_dispatch_main_queue`
- `scan_main_actor_annotations`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
