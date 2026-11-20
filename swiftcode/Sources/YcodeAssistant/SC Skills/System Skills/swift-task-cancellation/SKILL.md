---
name: swift-task-cancellation
description: "Make long-running async work cancellable and responsive."
category: Concurrency
tags: [cancellation, tasks, async]
tools: [scan_task_detached, swift_list_async_functions]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Swift Task Cancellation

Make long-running async work cancellable and responsive.

## When to use this skill
- The user asks for work involving: cancellation, tasks, async.
- You are about to change code in the Concurrency area and want SwiftCode's standard workflow.

## Workflow
1. Check Task.isCancelled or call try Task.checkCancellation() in loops.
2. Use withTaskCancellationHandler for callback-based APIs.
3. Propagate cancellation by keeping work structured.
4. Clean up resources in defer blocks.
5. Test cancellation timing.

## Rules
- Cancellation is cooperative; check often.
- Never swallow CancellationError as a failure for users.

## Verification
- [ ] Cancel stops work within a bounded time.
- [ ] Resources released.

## Avoid
- Detached tasks ignoring cancellation.
- Showing errors for user-initiated cancels.

## Recommended SwiftCode tools
- `scan_task_detached`
- `swift_list_async_functions`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
