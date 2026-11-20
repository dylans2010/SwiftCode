---
name: structured-concurrency-patterns
description: "Use task groups, async let and cancellation correctly."
category: Concurrency
tags: [task group, async let, cancellation]
tools: [scan_task_detached, scan_view_lifecycle_tasks]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Structured Concurrency Patterns

Use task groups, async let and cancellation correctly.

## When to use this skill
- The user asks for work involving: task group, async let, cancellation.
- You are about to change code in the Concurrency area and want SwiftCode's standard workflow.

## Workflow
1. Use async let for fixed parallel work.
2. Use withThrowingTaskGroup for dynamic fan-out with limits.
3. Check Task.isCancelled / try Task.checkCancellation in loops.
4. Tie UI work to .task so it cancels on disappear.
5. Propagate errors; don't swallow them.

## Rules
- Prefer structured over unstructured tasks.
- Bound concurrency for network fan-out.

## Verification
- [ ] Cancellation stops work promptly.
- [ ] Errors propagate.

## Avoid
- Fire-and-forget Tasks in loops.
- Ignoring cancellation.

## Recommended SwiftCode tools
- `scan_task_detached`
- `scan_view_lifecycle_tasks`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
