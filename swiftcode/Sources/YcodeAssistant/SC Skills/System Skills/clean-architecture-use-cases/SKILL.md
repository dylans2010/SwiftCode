---
name: clean-architecture-use-cases
description: "Separate domain use cases from frameworks for testable business logic."
category: Architecture
tags: [clean architecture, use cases, domain]
tools: [swift_generate_protocol_from_type, swift_list_protocols]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Clean Architecture Use Cases

Separate domain use cases from frameworks for testable business logic.

## When to use this skill
- The user asks for work involving: clean architecture, use cases, domain.
- You are about to change code in the Architecture area and want SwiftCode's standard workflow.

## Workflow
1. Identify business rules entangled with UI/network.
2. Extract use-case types with single execute methods.
3. Define repository protocols in the domain.
4. Implement repositories in infrastructure.
5. Test use cases with in-memory repositories.

## Rules
- Domain has no framework imports.
- Dependencies point inward.

## Verification
- [ ] Use cases fully unit tested.
- [ ] UI depends only on use cases.

## Avoid
- Layers for their own sake.
- Anemic pass-through use cases everywhere.

## Recommended SwiftCode tools
- `swift_generate_protocol_from_type`
- `swift_list_protocols`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
