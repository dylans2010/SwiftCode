---
name: modularization-architecture
description: "Split an app into feature and core modules with clear dependency direction."
category: Architecture
tags: [modularization, architecture, swiftpm]
tools: [swift_list_imports, swiftpm_describe_package, workspace_directory_sizes]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Modularization Architecture

Split an app into feature and core modules with clear dependency direction.

## When to use this skill
- The user asks for work involving: modularization, architecture, swiftpm.
- You are about to change code in the Architecture area and want SwiftCode's standard workflow.

## Workflow
1. Map current imports with swift_list_imports.
2. Define layers: App → Features → Core/Domain → Infrastructure.
3. Create SwiftPM targets per module with explicit dependencies.
4. Move code incrementally, fixing access control.
5. Enforce no upward dependencies.

## Rules
- Modules expose minimal public API.
- Shared code goes down, never sideways.

## Verification
- [ ] Each module builds independently.
- [ ] No cyclic imports.

## Avoid
- One giant Utilities module.
- Making everything public.

## Recommended SwiftCode tools
- `swift_list_imports`
- `swiftpm_describe_package`
- `workspace_directory_sizes`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
