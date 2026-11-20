---
name: swift-actor-reentrancy
description: "Avoid actor reentrancy bugs when actor methods await."
category: Concurrency
tags: [actors, reentrancy, state]
tools: [swift_list_actors, swift_concurrency_analyzer]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Swift Actor Reentrancy

Avoid actor reentrancy bugs when actor methods await.

## When to use this skill
- The user asks for work involving: actors, reentrancy, state.
- You are about to change code in the Concurrency area and want SwiftCode's standard workflow.

## Workflow
1. Identify actor methods that read state, await, then write state.
2. Re-validate invariants after each await.
3. Coalesce duplicate in-flight work with stored Tasks keyed by request.
4. Keep critical sections synchronous inside the actor.
5. Write concurrent tests that interleave calls.

## Rules
- Assume state may change across await.
- Prefer synchronous mutation.

## Verification
- [ ] Interleaving tests pass.
- [ ] No duplicated work under concurrency.

## Avoid
- Caching checks before await and trusting them after.
- Long awaits inside critical updates.

## Recommended SwiftCode tools
- `swift_list_actors`
- `swift_concurrency_analyzer`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
