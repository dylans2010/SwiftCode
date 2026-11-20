---
name: agent-code-generation-quality
description: "Generate production-quality code that fits the existing codebase."
category: Agent Behavior
tags: [code generation, conventions, quality]
tools: [file_read, swift_file_outline, swift_format_lint_check]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Agent Code Generation Quality

Generate production-quality code that fits the existing codebase.

## When to use this skill
- The user asks for work involving: code generation, conventions, quality.
- You are about to change code in the Agent Behavior area and want SwiftCode's standard workflow.

## Workflow
1. Read neighboring code for conventions.
2. Reuse existing utilities.
3. Write the minimal complete implementation with error handling.
4. Add tests.
5. Lint and build.

## Rules
- No placeholders or fake data.
- Match style and naming.

## Verification
- [ ] Builds, lints and tests pass.
- [ ] No TODO stubs.

## Avoid
- Inventing new patterns.
- Mock implementations.

## Recommended SwiftCode tools
- `file_read`
- `swift_file_outline`
- `swift_format_lint_check`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
