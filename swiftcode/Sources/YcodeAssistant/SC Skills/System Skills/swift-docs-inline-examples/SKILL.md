---
name: swift-docs-inline-examples
description: "Add accurate code examples to API documentation that compile and stay current."
category: Documentation
tags: [examples, api docs, snippets]
tools: [swift_undocumented_public_api, swift_typecheck_file]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Swift Docs Inline Examples

Add accurate code examples to API documentation that compile and stay current.

## When to use this skill
- The user asks for work involving: examples, api docs, snippets.
- You are about to change code in the Documentation area and want SwiftCode's standard workflow.

## Workflow
1. Pick primary entry points that need examples.
2. Write minimal, realistic examples using public API only.
3. Verify examples compile (snippets or doc tests).
4. Show error handling where relevant.
5. Keep examples short.

## Rules
- Examples use public API.
- Examples are tested.

## Verification
- [ ] Snippets compile.
- [ ] Docs build without warnings.

## Avoid
- Pseudo-code in docs.
- Examples relying on internals.

## Recommended SwiftCode tools
- `swift_undocumented_public_api`
- `swift_typecheck_file`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
