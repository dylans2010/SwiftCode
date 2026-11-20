---
name: swift-protocol-oriented-design
description: "Design with protocols, generics and extensions instead of deep inheritance."
category: Swift Language
tags: [protocols, generics, pop]
tools: [swift_list_protocols, swift_find_conformers, swift_list_classes]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Swift Protocol Oriented Design

Design with protocols, generics and extensions instead of deep inheritance.

## When to use this skill
- The user asks for work involving: protocols, generics, pop.
- You are about to change code in the Swift Language area and want SwiftCode's standard workflow.

## Workflow
1. Identify behaviors shared across types.
2. Define small protocols with associated types where needed.
3. Provide default implementations in extensions sparingly.
4. Use generics/some for static dispatch, any for heterogeneous storage.
5. Keep conformance in extensions for organization.

## Rules
- Protocols model capabilities, not hierarchies.
- Avoid protocols with one conformer unless for testing.

## Verification
- [ ] Callers depend on protocols at boundaries.
- [ ] No unnecessary existentials in hot paths.

## Avoid
- God protocols.
- Inheritance chains > 2 levels.

## Recommended SwiftCode tools
- `swift_list_protocols`
- `swift_find_conformers`
- `swift_list_classes`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
