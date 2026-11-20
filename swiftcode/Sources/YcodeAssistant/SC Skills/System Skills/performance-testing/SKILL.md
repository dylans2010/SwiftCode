---
name: performance-testing
description: "Measure and guard performance with benchmarks and XCTest metrics."
category: Testing
tags: [performance, benchmarks, measure]
tools: [swiftpm_run_filtered_tests, system_top_processes]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Performance Testing

Measure and guard performance with benchmarks and XCTest metrics.

## When to use this skill
- The user asks for work involving: performance, benchmarks, measure.
- You are about to change code in the Testing area and want SwiftCode's standard workflow.

## Workflow
1. Define the metric and budget (time, memory).
2. Write measure blocks or clock-based benchmarks.
3. Run in release configuration.
4. Record baselines and compare.
5. Investigate regressions with Instruments.

## Rules
- Measure before optimizing.
- Benchmark on representative data.

## Verification
- [ ] Baseline recorded.
- [ ] Regression threshold enforced.

## Avoid
- Debug-build timings.
- Micro-optimizing cold paths.

## Recommended SwiftCode tools
- `swiftpm_run_filtered_tests`
- `system_top_processes`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
