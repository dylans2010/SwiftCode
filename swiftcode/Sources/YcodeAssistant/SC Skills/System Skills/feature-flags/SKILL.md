---
name: feature-flags
description: "Implement feature flags for safe rollout and experimentation."
category: Architecture
tags: [feature flags, rollout, configuration]
tools: [scan_userdefaults_usage, swift_symbol_references]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Feature Flags

Implement feature flags for safe rollout and experimentation.

## When to use this skill
- The user asks for work involving: feature flags, rollout, configuration.
- You are about to change code in the Architecture area and want SwiftCode's standard workflow.

## Workflow
1. Define flags in one typed enum with defaults.
2. Back flags with local overrides plus remote config.
3. Check flags at the boundary, not deep in logic.
4. Log exposure for analytics.
5. Remove flags after full rollout.

## Rules
- Every flag has an owner and removal date.
- Default to safe behavior.

## Verification
- [ ] Both flag states tested.
- [ ] Stale flags removed.

## Avoid
- Flags controlling security.
- Nested flag checks.

## Recommended SwiftCode tools
- `scan_userdefaults_usage`
- `swift_symbol_references`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
