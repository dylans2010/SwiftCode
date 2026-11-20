---
name: combine-to-async-migration
description: "Migrate Combine pipelines to async sequences and Observation."
category: Concurrency
tags: [combine, async sequence, migration]
tools: [scan_combine_sinks, scan_observable_state]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Combine To Async Migration

Migrate Combine pipelines to async sequences and Observation.

## When to use this skill
- The user asks for work involving: combine, async sequence, migration.
- You are about to change code in the Concurrency area and want SwiftCode's standard workflow.

## Workflow
1. Inventory publishers and sinks.
2. Replace @Published+ObservableObject with @Observable.
3. Convert pipelines to AsyncStream/AsyncSequence with for await loops in .task.
4. Remove AnyCancellable storage once replaced.

## Rules
- Keep behavior identical (debounce, ordering).
- Migrate one feature at a time.

## Verification
- [ ] Feature tests pass after migration.
- [ ] No leaked subscriptions.

## Avoid
- Mixing both systems for the same state.
- Dropping debounce semantics.

## Recommended SwiftCode tools
- `scan_combine_sinks`
- `scan_observable_state`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
