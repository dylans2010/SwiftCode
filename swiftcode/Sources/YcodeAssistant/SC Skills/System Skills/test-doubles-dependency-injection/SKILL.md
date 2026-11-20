---
name: test-doubles-dependency-injection
description: "Use protocols and dependency injection to isolate units with fakes, stubs and spies."
category: Testing
tags: [dependency injection, fakes, stubs, testing]
tools: [swift_generate_protocol_from_type, scan_singletons]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Test Doubles Dependency Injection

Use protocols and dependency injection to isolate units with fakes, stubs and spies.

## When to use this skill
- The user asks for work involving: dependency injection, fakes, stubs, testing.
- You are about to change code in the Testing area and want SwiftCode's standard workflow.

## Workflow
1. Find hard dependencies (singletons, URLSession, Date()).
2. Extract protocols with swift_generate_protocol_from_type.
3. Inject via initializer with production defaults.
4. Write in-memory fakes that behave like the real thing.
5. Assert outcomes, use spies only for interactions that matter.

## Rules
- Fakes must model real behavior.
- Do not mock what you do not own—wrap it.

## Verification
- [ ] Units testable without network.
- [ ] Production wiring unchanged.

## Avoid
- Mocking every method.
- Global swizzling.

## Recommended SwiftCode tools
- `swift_generate_protocol_from_type`
- `scan_singletons`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
