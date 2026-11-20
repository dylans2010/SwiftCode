---
name: swift-6-migration
description: "Migrate a codebase to Swift 6 language mode and strict concurrency."
category: Swift Language
tags: [swift 6, migration, strict concurrency]
tools: [scan_unchecked_sendable, scan_nonisolated_unsafe, swift_list_sendable_types, swiftpm_build_target]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Swift 6 Migration

Migrate a codebase to Swift 6 language mode and strict concurrency.

## When to use this skill
- The user asks for work involving: swift 6, migration, strict concurrency.
- You are about to change code in the Swift Language area and want SwiftCode's standard workflow.

## Workflow
1. Enable complete concurrency checking as warnings per module.
2. Fix Sendable and isolation diagnostics module by module.
3. Annotate globals and singletons.
4. Switch to Swift 6 mode when warning-free.

## Rules
- Fix, don't suppress.
- Migrate leaf modules first.

## Verification
- [ ] Module builds in Swift 6 mode.
- [ ] No new unchecked Sendable.

## Avoid
- Mass @preconcurrency.
- Global nonisolated(unsafe).

## Recommended SwiftCode tools
- `scan_unchecked_sendable`
- `scan_nonisolated_unsafe`
- `swift_list_sendable_types`
- `swiftpm_build_target`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
