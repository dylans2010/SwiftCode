---
name: naming-conventions-swift
description: "Name types, functions and variables following Swift API Design Guidelines."
category: Code Quality
tags: [naming, api design, readability]
tools: [swift_list_public_api, text_case_convert, file_rename_identifier]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Naming Conventions Swift

Name types, functions and variables following Swift API Design Guidelines.

## When to use this skill
- The user asks for work involving: naming, api design, readability.
- You are about to change code in the Code Quality area and want SwiftCode's standard workflow.

## Workflow
1. Read call sites, not just declarations.
2. Types/protocols UpperCamelCase, everything else lowerCamelCase.
3. Functions read as English phrases at the call site; omit needless words.
4. Booleans read as assertions (isEnabled, hasItems).
5. Rename consistently across the codebase.

## Rules
- Clarity at the point of use.
- Avoid abbreviations.

## Verification
- [ ] All references updated; builds.
- [ ] Names consistent within module.

## Avoid
- Hungarian notation.
- Ambiguous names like data, manager, helper.

## Recommended SwiftCode tools
- `swift_list_public_api`
- `text_case_convert`
- `file_rename_identifier`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
