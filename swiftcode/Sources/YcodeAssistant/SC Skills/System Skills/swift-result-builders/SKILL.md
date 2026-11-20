---
name: swift-result-builders
description: "Write result builders for DSLs with clear diagnostics."
category: Swift Language
tags: [result builders, dsl, swift]
tools: [swift_list_types, file_read]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Swift Result Builders

Write result builders for DSLs with clear diagnostics.

## When to use this skill
- The user asks for work involving: result builders, dsl, swift.
- You are about to change code in the Swift Language area and want SwiftCode's standard workflow.

## Workflow
1. Define @resultBuilder with buildBlock/buildOptional/buildEither/buildArray.
2. Use buildExpression to accept components.
3. Provide buildFinalResult for conversion.
4. Test DSL output.

## Rules
- Keep the DSL small.
- Readable compiler errors.

## Verification
- [ ] Unit tests for each builder branch.
- [ ] Compile time acceptable.

## Avoid
- Overly clever DSLs.
- Untested branches.

## Recommended SwiftCode tools
- `swift_list_types`
- `file_read`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
