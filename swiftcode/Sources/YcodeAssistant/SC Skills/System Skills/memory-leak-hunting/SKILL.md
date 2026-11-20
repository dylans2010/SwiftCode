---
name: memory-leak-hunting
description: "Find and fix retain cycles and leaks in Swift apps."
category: Performance
tags: [memory, leaks, retain cycles]
tools: [scan_closure_self_capture, scan_strong_delegates, scan_timer_usage, scan_combine_sinks]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Memory Leak Hunting

Find and fix retain cycles and leaks in Swift apps.

## When to use this skill
- The user asks for work involving: memory, leaks, retain cycles.
- You are about to change code in the Performance area and want SwiftCode's standard workflow.

## Workflow
1. Run leak-prone scans to find candidates.
2. Use Memory Graph Debugger to confirm cycles.
3. Break cycles with weak/unowned captures or weak delegates.
4. Invalidate timers and cancel tasks/subscriptions.
5. Add deinit logging in debug to verify release.

## Rules
- Delegates weak by default.
- Closures stored by self capture self weakly.

## Verification
- [ ] Memory graph shows no cycles for the flow.
- [ ] deinit called on dismiss.

## Avoid
- Unowned where lifetime is uncertain.
- Ignoring growing memory.

## Recommended SwiftCode tools
- `scan_closure_self_capture`
- `scan_strong_delegates`
- `scan_timer_usage`
- `scan_combine_sinks`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
