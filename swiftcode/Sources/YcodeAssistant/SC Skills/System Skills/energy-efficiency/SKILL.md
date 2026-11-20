---
name: energy-efficiency
description: "Reduce battery and CPU usage from timers, location, networking and background work."
category: Performance
tags: [energy, battery, background]
tools: [scan_timer_usage, scan_thread_sleep, system_top_processes]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Energy Efficiency

Reduce battery and CPU usage from timers, location, networking and background work.

## When to use this skill
- The user asks for work involving: energy, battery, background.
- You are about to change code in the Performance area and want SwiftCode's standard workflow.

## Workflow
1. Find polling timers and busy loops.
2. Replace polling with push/notifications/async sequences.
3. Coalesce network requests and use background URLSession for transfers.
4. Lower location accuracy and stop updates when idle.
5. Verify with Energy gauge.

## Rules
- No timers without tolerance.
- Stop work when not visible.

## Verification
- [ ] Energy impact low in Xcode gauge.
- [ ] Idle CPU near 0%.

## Avoid
- Polling every second.
- Continuous GPS.

## Recommended SwiftCode tools
- `scan_timer_usage`
- `scan_thread_sleep`
- `system_top_processes`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
