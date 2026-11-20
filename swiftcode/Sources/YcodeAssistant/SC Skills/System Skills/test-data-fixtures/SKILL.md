---
name: test-data-fixtures
description: "Build maintainable test fixtures and factories."
category: Testing
tags: [fixtures, test data, factories]
tools: [json_to_swift_codable, file_read]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Test Data Fixtures

Build maintainable test fixtures and factories.

## When to use this skill
- The user asks for work involving: fixtures, test data, factories.
- You are about to change code in the Testing area and want SwiftCode's standard workflow.

## Workflow
1. Store real-shaped fixtures in test resources.
2. Create factory helpers with sensible defaults.
3. Override only fields relevant to each test.
4. Keep fixtures small and documented.

## Rules
- Fixtures reflect real data shapes.
- No production data with PII.

## Verification
- [ ] Fixtures load in tests.
- [ ] Tests read clearly.

## Avoid
- Giant shared fixtures.
- Copying production dumps.

## Recommended SwiftCode tools
- `json_to_swift_codable`
- `file_read`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
