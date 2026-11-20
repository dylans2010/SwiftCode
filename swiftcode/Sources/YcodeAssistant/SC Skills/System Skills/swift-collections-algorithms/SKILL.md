---
name: swift-collections-algorithms
description: "Choose appropriate collections and algorithms for correctness and performance."
category: Swift Language
tags: [collections, algorithms, performance]
tools: [file_long_functions_report, scan_formatter_allocations]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Swift Collections Algorithms

Choose appropriate collections and algorithms for correctness and performance.

## When to use this skill
- The user asks for work involving: collections, algorithms, performance.
- You are about to change code in the Swift Language area and want SwiftCode's standard workflow.

## Workflow
1. Pick Array/Set/Dictionary by access pattern.
2. Use lazy, reduce(into:), first(where:), contains(where:).
3. Reserve capacity for large builds.
4. Consider swift-collections (Deque, OrderedDictionary) when needed.

## Rules
- Know the complexity of each call.
- Avoid nested linear searches.

## Verification
- [ ] Large-input test stays fast.
- [ ] Results correct for empty input.

## Avoid
- contains in loops over arrays for membership.
- Sorting repeatedly.

## Recommended SwiftCode tools
- `file_long_functions_report`
- `scan_formatter_allocations`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
