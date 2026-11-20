---
name: app-launch-optimization
description: "Reduce app launch time by deferring work and trimming startup dependencies."
category: Performance
tags: [launch time, startup, performance]
tools: [binary_linked_libraries, scan_singletons]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# App Launch Optimization

Reduce app launch time by deferring work and trimming startup dependencies.

## When to use this skill
- The user asks for work involving: launch time, startup, performance.
- You are about to change code in the Performance area and want SwiftCode's standard workflow.

## Workflow
1. Measure launch with Instruments App Launch.
2. List dynamic libraries with binary_linked_libraries; merge/staticize where possible.
3. Defer non-critical initialization until after first frame.
4. Avoid heavy singletons initialized at launch.
5. Re-measure cold and warm launch.

## Rules
- First frame ASAP.
- Lazy init for services.

## Verification
- [ ] Launch time improved and recorded.
- [ ] No crash from deferred init.

## Avoid
- Network calls blocking launch.
- Large synchronous disk reads at startup.

## Recommended SwiftCode tools
- `binary_linked_libraries`
- `scan_singletons`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
