---
name: memory-graph-debugging
description: "Use Xcode's Memory Graph and malloc stack logging to find leaks and cycles."
category: Debugging
tags: [memory graph, leaks, debugging]
tools: [scan_closure_self_capture, scan_strong_delegates]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Memory Graph Debugging

Use Xcode's Memory Graph and malloc stack logging to find leaks and cycles.

## When to use this skill
- The user asks for work involving: memory graph, leaks, debugging.
- You are about to change code in the Debugging area and want SwiftCode's standard workflow.

## Workflow
1. Reproduce the flow that should release memory.
2. Capture a memory graph and filter for your types.
3. Inspect retain paths to find the cycle.
4. Fix with weak/unowned captures or invalidation.
5. Re-capture to confirm release.

## Rules
- Confirm with evidence, not guesses.
- Fix the owning reference.

## Verification
- [ ] Objects released after the flow.
- [ ] Graph shows no cycle.

## Avoid
- Adding weak everywhere blindly.
- Ignoring growth in instruments.

## Recommended SwiftCode tools
- `scan_closure_self_capture`
- `scan_strong_delegates`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
