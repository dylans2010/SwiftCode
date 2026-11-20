---
name: performance-profiling-instruments
description: "Profile CPU, memory and hangs with Instruments and fix the hottest paths."
category: Performance
tags: [performance, instruments, profiling]
tools: [system_top_processes, file_long_functions_report, scan_formatter_allocations]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Performance Profiling Instruments

Profile CPU, memory and hangs with Instruments and fix the hottest paths.

## When to use this skill
- The user asks for work involving: performance, instruments, profiling.
- You are about to change code in the Performance area and want SwiftCode's standard workflow.

## Workflow
1. Reproduce the slow scenario in a Release build.
2. Record Time Profiler / Hangs / Allocations.
3. Identify the top frames by self time.
4. Fix the biggest cost first; re-measure.
5. Add a performance test to prevent regression.

## Rules
- Measure, don't guess.
- Change one thing at a time.

## Verification
- [ ] Before/after numbers recorded.
- [ ] No functional regressions.

## Avoid
- Profiling Debug builds.
- Premature micro-optimizations.

## Recommended SwiftCode tools
- `system_top_processes`
- `file_long_functions_report`
- `scan_formatter_allocations`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
