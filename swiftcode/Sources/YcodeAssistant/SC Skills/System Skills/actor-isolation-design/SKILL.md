---
name: actor-isolation-design
description: "Design actor boundaries, avoid reentrancy bugs and keep the main actor responsive."
category: Concurrency
tags: [actors, isolation, reentrancy]
tools: [swift_list_actors, scan_main_actor_annotations]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Actor Isolation Design

Design actor boundaries, avoid reentrancy bugs and keep the main actor responsive.

## When to use this skill
- The user asks for work involving: actors, isolation, reentrancy.
- You are about to change code in the Concurrency area and want SwiftCode's standard workflow.

## Workflow
1. Identify shared mutable state and its owner.
2. Wrap it in an actor with intention-revealing methods.
3. Re-check invariants after every await (reentrancy).
4. Move heavy work off the main actor with nonisolated async functions.
5. Test concurrent access with task groups.

## Rules
- Keep actor methods small.
- Don't hold assumptions across await.

## Verification
- [ ] Concurrent stress test passes.
- [ ] Main actor work under 16ms per frame.

## Avoid
- Making everything @MainActor.
- Nested actor hops in loops.

## Recommended SwiftCode tools
- `swift_list_actors`
- `scan_main_actor_annotations`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
