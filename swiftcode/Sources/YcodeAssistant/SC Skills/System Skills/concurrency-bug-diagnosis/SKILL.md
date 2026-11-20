---
name: concurrency-bug-diagnosis
description: "Diagnose data races, deadlocks and priority inversions."
category: Debugging
tags: [data race, deadlock, thread sanitizer]
tools: [scan_dispatch_semaphores, scan_lock_usage, scan_unchecked_sendable, scan_nonisolated_unsafe]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Concurrency Bug Diagnosis

Diagnose data races, deadlocks and priority inversions.

## When to use this skill
- The user asks for work involving: data race, deadlock, thread sanitizer.
- You are about to change code in the Debugging area and want SwiftCode's standard workflow.

## Workflow
1. Enable Thread Sanitizer and strict concurrency.
2. Find blocking primitives with scans.
3. Reproduce under stress (task groups).
4. Fix by isolating state in actors or proper locks.
5. Re-run sanitizer.

## Rules
- Never hold locks across await.
- Avoid semaphores in async code.

## Verification
- [ ] TSan clean.
- [ ] Stress test passes 100 iterations.

## Avoid
- Adding sleeps to 'fix' races.
- @unchecked Sendable band-aids.

## Recommended SwiftCode tools
- `scan_dispatch_semaphores`
- `scan_lock_usage`
- `scan_unchecked_sendable`
- `scan_nonisolated_unsafe`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
