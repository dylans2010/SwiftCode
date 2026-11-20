---
name: swift-error-handling
description: "Model and handle errors with typed domains, recovery and user messaging."
category: Swift Language
tags: [errors, throws, result]
tools: [scan_empty_catch_blocks, scan_try_optional, scan_force_try, scan_fatal_error_calls]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Swift Error Handling

Model and handle errors with typed domains, recovery and user messaging.

## When to use this skill
- The user asks for work involving: errors, throws, result.
- You are about to change code in the Swift Language area and want SwiftCode's standard workflow.

## Workflow
1. Find swallowed errors with scan_empty_catch_blocks and scan_try_optional.
2. Define error enums per domain conforming to LocalizedError.
3. Throw at the failure site; catch where you can recover or present.
4. Log with context (no secrets).
5. Show actionable messages to users.

## Rules
- No empty catch blocks.
- fatalError only for programmer errors.

## Verification
- [ ] Each error path tested.
- [ ] Users see clear messages.

## Avoid
- try! in production paths.
- Catch-all that hides causes.

## Recommended SwiftCode tools
- `scan_empty_catch_blocks`
- `scan_try_optional`
- `scan_force_try`
- `scan_fatal_error_calls`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
