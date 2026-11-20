---
name: swift-optionals-safety
description: "Eliminate crash-prone force unwraps and IUOs with safe optional handling."
category: Swift Language
tags: [optionals, force unwrap, safety]
tools: [scan_force_unwrap, scan_implicitly_unwrapped_optionals, scan_force_cast]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Swift Optionals Safety

Eliminate crash-prone force unwraps and IUOs with safe optional handling.

## When to use this skill
- The user asks for work involving: optionals, force unwrap, safety.
- You are about to change code in the Swift Language area and want SwiftCode's standard workflow.

## Workflow
1. List force unwraps and casts.
2. Replace with guard let/if let and early exits.
3. Use nil-coalescing with meaningful defaults.
4. Convert IUO properties to lets initialized in init or real optionals.
5. Add tests for nil paths.

## Rules
- Unwrap once near the boundary.
- Make invalid states unrepresentable.

## Verification
- [ ] Scans show reduced counts in touched files.
- [ ] Nil paths tested.

## Avoid
- Replacing ! with ?? "" blindly.
- Optional chaining that silently drops errors.

## Recommended SwiftCode tools
- `scan_force_unwrap`
- `scan_implicitly_unwrapped_optionals`
- `scan_force_cast`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
