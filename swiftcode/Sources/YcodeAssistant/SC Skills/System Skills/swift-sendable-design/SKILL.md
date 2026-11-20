---
name: swift-sendable-design
description: "Design Sendable-safe types and APIs for Swift 6 strict concurrency."
category: Concurrency
tags: [sendable, swift 6, concurrency]
tools: [swift_list_sendable_types, scan_unchecked_sendable]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Swift Sendable Design

Design Sendable-safe types and APIs for Swift 6 strict concurrency.

## When to use this skill
- The user asks for work involving: sendable, swift 6, concurrency.
- You are about to change code in the Concurrency area and want SwiftCode's standard workflow.

## Workflow
1. Prefer immutable value types that are implicitly Sendable.
2. Isolate mutable reference types in actors or @MainActor.
3. Use sending/consuming parameters for ownership transfer where appropriate.
4. Use Mutex/Atomic from the Synchronization module for low-level state.
5. Document any @unchecked Sendable with the invariant that makes it safe.

## Rules
- Sendable conformance must be true, not asserted.
- Minimize shared mutable state.

## Verification
- [ ] Strict concurrency build is clean.
- [ ] No new unchecked conformances without justification.

## Avoid
- Sprinkling @unchecked Sendable.
- Global mutable singletons.

## Recommended SwiftCode tools
- `swift_list_sendable_types`
- `scan_unchecked_sendable`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
