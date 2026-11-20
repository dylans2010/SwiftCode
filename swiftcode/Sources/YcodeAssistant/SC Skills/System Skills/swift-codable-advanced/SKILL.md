---
name: swift-codable-advanced
description: "Handle complex Codable cases: polymorphism, defaults, dates and unknown keys."
category: Swift Language
tags: [codable, json, decoding]
tools: [json_to_swift_codable, swift_generate_coding_keys, json_list_keys]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Swift Codable Advanced

Handle complex Codable cases: polymorphism, defaults, dates and unknown keys.

## When to use this skill
- The user asks for work involving: codable, json, decoding.
- You are about to change code in the Swift Language area and want SwiftCode's standard workflow.

## Workflow
1. Capture real payload samples.
2. Use custom init(from:) for defaults and polymorphic types with a discriminator.
3. Configure date/key decoding strategies once.
4. Write decode tests with fixtures.

## Rules
- Fail loudly on required fields, default optional ones.
- Never decode money as Double.

## Verification
- [ ] Fixture tests cover all variants.
- [ ] Unknown enum cases handled.

## Avoid
- try? decoding that hides errors.
- Duplicating models per endpoint.

## Recommended SwiftCode tools
- `json_to_swift_codable`
- `swift_generate_coding_keys`
- `json_list_keys`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
