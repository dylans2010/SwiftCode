---
name: error-messages-ux
description: "Write helpful, human error messages and recovery actions."
category: UI Design
tags: [errors, copywriting, ux]
tools: [scan_empty_catch_blocks, localization_audit]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Error Messages Ux

Write helpful, human error messages and recovery actions.

## When to use this skill
- The user asks for work involving: errors, copywriting, ux.
- You are about to change code in the UI Design area and want SwiftCode's standard workflow.

## Workflow
1. Say what happened in plain language.
2. Say why if known and what to do next.
3. Offer retry or alternative actions.
4. Log technical details separately.

## Rules
- No blame on users.
- No raw codes as the only info.

## Verification
- [ ] Each error has a recovery path.
- [ ] Messages localized.

## Avoid
- 'Something went wrong' only.
- Stack traces in UI.

## Recommended SwiftCode tools
- `scan_empty_catch_blocks`
- `localization_audit`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
