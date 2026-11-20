---
name: swift-access-control
description: "Apply access control to minimize API surface and protect invariants."
category: Swift Language
tags: [access control, encapsulation, api]
tools: [swift_list_public_api, swift_list_private_members]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Swift Access Control

Apply access control to minimize API surface and protect invariants.

## When to use this skill
- The user asks for work involving: access control, encapsulation, api.
- You are about to change code in the Swift Language area and want SwiftCode's standard workflow.

## Workflow
1. Default to internal; make public only what clients need.
2. Use private(set) for read-only exposure.
3. Use fileprivate sparingly.
4. Use package access for cross-module internals.

## Rules
- Public API is a commitment.
- Hide mutable state.

## Verification
- [ ] Public API list reviewed.
- [ ] Builds across modules.

## Avoid
- Making everything public.
- Exposing mutable collections.

## Recommended SwiftCode tools
- `swift_list_public_api`
- `swift_list_private_members`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
