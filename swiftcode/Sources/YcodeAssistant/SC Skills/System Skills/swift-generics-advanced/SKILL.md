---
name: swift-generics-advanced
description: "Use generics, opaque types, primary associated types and parameter packs effectively."
category: Swift Language
tags: [generics, opaque types, existentials]
tools: [swift_list_protocols, scan_any_type_usage]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Swift Generics Advanced

Use generics, opaque types, primary associated types and parameter packs effectively.

## When to use this skill
- The user asks for work involving: generics, opaque types, existentials.
- You are about to change code in the Swift Language area and want SwiftCode's standard workflow.

## Workflow
1. Identify duplicated code across types.
2. Extract a generic function/type with minimal constraints.
3. Use some for return types to hide implementation.
4. Use primary associated types (any Collection<Int>) when existential is needed.
5. Measure compile time impact.

## Rules
- Constraints as weak as possible.
- Readable error messages matter.

## Verification
- [ ] Builds without type-checker timeouts.
- [ ] Call sites read naturally.

## Avoid
- Over-abstracting single uses.
- Any to dodge typing.

## Recommended SwiftCode tools
- `swift_list_protocols`
- `scan_any_type_usage`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
