---
name: c-interop-unsafe-pointers
description: "Call C APIs and manage unsafe memory correctly."
category: Swift Language
tags: [c interop, unsafe pointers, memory]
tools: [scan_unsafe_pointers, scan_unsafe_pointers]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# C Interop Unsafe Pointers

Call C APIs and manage unsafe memory correctly.

## When to use this skill
- The user asks for work involving: c interop, unsafe pointers, memory.
- You are about to change code in the Swift Language area and want SwiftCode's standard workflow.

## Workflow
1. Use withUnsafe* scoped APIs.
2. Never escape pointers beyond scope.
3. Balance allocate/deallocate and retain/release.
4. Wrap C APIs in safe Swift types.

## Rules
- Unsafe code isolated in small types.
- Document ownership.

## Verification
- [ ] ASan clean.
- [ ] Wrapper tests pass.

## Avoid
- Storing pointers from withUnsafe closures.
- Assuming memory layout.

## Recommended SwiftCode tools
- `scan_unsafe_pointers`
- `scan_unsafe_pointers`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
