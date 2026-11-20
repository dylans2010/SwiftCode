---
name: swift-value-types-modeling
description: "Model domain data with structs and enums, Codable, and immutability."
category: Swift Language
tags: [structs, enums, codable, modeling]
tools: [swift_list_structs, swift_list_codable_types, json_to_swift_codable, swift_generate_coding_keys]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Swift Value Types Modeling

Model domain data with structs and enums, Codable, and immutability.

## When to use this skill
- The user asks for work involving: structs, enums, codable, modeling.
- You are about to change code in the Swift Language area and want SwiftCode's standard workflow.

## Workflow
1. Start from real payloads (json_to_swift_codable).
2. Use structs for data, enums for states and variants.
3. Prefer let properties; mutate via copies.
4. Add Codable with explicit CodingKeys when names differ.
5. Validate invariants in init.

## Rules
- Make illegal states unrepresentable.
- Equatable/Hashable for testability.

## Verification
- [ ] Round-trip encode/decode tests.
- [ ] No optional-everything models.

## Avoid
- Classes for plain data.
- Stringly-typed fields.

## Recommended SwiftCode tools
- `swift_list_structs`
- `swift_list_codable_types`
- `json_to_swift_codable`
- `swift_generate_coding_keys`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
