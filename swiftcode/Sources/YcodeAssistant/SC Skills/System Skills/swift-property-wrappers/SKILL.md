---
name: swift-property-wrappers
description: "Create and use property wrappers responsibly."
category: Swift Language
tags: [property wrappers, swift, attributes]
tools: [scan_swiftui_property_wrappers, swift_list_structs]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Swift Property Wrappers

Create and use property wrappers responsibly.

## When to use this skill
- The user asks for work involving: property wrappers, swift, attributes.
- You are about to change code in the Swift Language area and want SwiftCode's standard workflow.

## Workflow
1. Confirm a wrapper removes real repetition.
2. Implement wrappedValue and optional projectedValue.
3. Document thread-safety.
4. Test wrapper behavior directly.

## Rules
- Wrappers should be obvious.
- No hidden I/O.

## Verification
- [ ] Wrapper tests pass.
- [ ] Call sites remain readable.

## Avoid
- Wrappers doing network calls.
- Stacking many wrappers.

## Recommended SwiftCode tools
- `scan_swiftui_property_wrappers`
- `swift_list_structs`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
