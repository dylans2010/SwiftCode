---
name: api-client-sdk-design
description: "Design Swift SDK/client libraries with ergonomic, stable public APIs."
category: Architecture
tags: [sdk, api design, library]
tools: [swift_list_public_api, swift_undocumented_public_api]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Api Client Sdk Design

Design Swift SDK/client libraries with ergonomic, stable public APIs.

## When to use this skill
- The user asks for work involving: sdk, api design, library.
- You are about to change code in the Architecture area and want SwiftCode's standard workflow.

## Workflow
1. Define core use cases and write call-site examples first.
2. Keep the public surface small with async APIs.
3. Use typed errors and configuration structs.
4. Document and version semantically.

## Rules
- Source-stable public API.
- No leaking dependencies' types.

## Verification
- [ ] Examples compile.
- [ ] Docs complete.

## Avoid
- Exposing internal types.
- Breaking changes in minors.

## Recommended SwiftCode tools
- `swift_list_public_api`
- `swift_undocumented_public_api`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
