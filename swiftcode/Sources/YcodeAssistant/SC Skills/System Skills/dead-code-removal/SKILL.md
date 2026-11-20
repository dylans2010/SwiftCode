---
name: dead-code-removal
description: "Find and remove unused code, files and resources safely."
category: Code Quality
tags: [dead code, cleanup, unused]
tools: [swift_symbol_references, workspace_empty_files, swift_list_private_members]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Dead Code Removal

Find and remove unused code, files and resources safely.

## When to use this skill
- The user asks for work involving: dead code, cleanup, unused.
- You are about to change code in the Code Quality area and want SwiftCode's standard workflow.

## Workflow
1. List candidate declarations.
2. Confirm zero references with swift_symbol_references (check dynamic uses: selectors, KVC, reflection).
3. Remove in small commits.
4. Build and run tests.
5. Remove orphaned assets and files.

## Rules
- When unsure, ask or deprecate first.
- Keep public API removal behind a major version.

## Verification
- [ ] Builds and tests pass.
- [ ] No runtime crash from removed dynamic references.

## Avoid
- Removing code used via @objc selectors.
- Mass deletion without verification.

## Recommended SwiftCode tools
- `swift_symbol_references`
- `workspace_empty_files`
- `swift_list_private_members`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
