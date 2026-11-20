---
name: swift-macros-authoring
description: "Author Swift macros with swift-syntax including tests and diagnostics."
category: Swift Language
tags: [macros, swift-syntax, metaprogramming]
tools: [swift_list_macros, swiftpm_describe_package]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Swift Macros Authoring

Author Swift macros with swift-syntax including tests and diagnostics.

## When to use this skill
- The user asks for work involving: macros, swift-syntax, metaprogramming.
- You are about to change code in the Swift Language area and want SwiftCode's standard workflow.

## Workflow
1. Decide macro role (freestanding/attached).
2. Create a macro target depending on swift-syntax.
3. Implement expansion with SwiftSyntaxBuilder.
4. Emit diagnostics with fix-its for misuse.
5. Test with assertMacroExpansion.

## Rules
- Macros must be deterministic.
- Expansion output must be readable.

## Verification
- [ ] Expansion tests cover edge cases.
- [ ] Diagnostics tested.

## Avoid
- Macros for things functions can do.
- Network or file access in macros.

## Recommended SwiftCode tools
- `swift_list_macros`
- `swiftpm_describe_package`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
