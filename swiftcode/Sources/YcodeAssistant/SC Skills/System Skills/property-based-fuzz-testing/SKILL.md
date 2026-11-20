---
name: property-based-fuzz-testing
description: "Use property-based and fuzz testing to find edge cases."
category: Testing
tags: [property testing, fuzzing, edge cases]
tools: [swift_generate_test_skeleton, text_regex_test]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Property Based Fuzz Testing

Use property-based and fuzz testing to find edge cases.

## When to use this skill
- The user asks for work involving: property testing, fuzzing, edge cases.
- You are about to change code in the Testing area and want SwiftCode's standard workflow.

## Workflow
1. Identify invariants (round-trip, idempotence, ordering).
2. Generate random inputs with a seeded generator.
3. Shrink failures to minimal cases.
4. Add failing cases as regression tests.

## Rules
- Seed for reproducibility.
- Bound input sizes.

## Verification
- [ ] Properties hold for 1000 runs.
- [ ] Failures reproducible.

## Avoid
- Unseeded randomness.
- Properties that restate implementation.

## Recommended SwiftCode tools
- `swift_generate_test_skeleton`
- `text_regex_test`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
