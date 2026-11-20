---
name: ios-privacy-permissions
description: "Request permissions at the right time with clear purpose strings and graceful denial."
category: Security
tags: [permissions, privacy, usage descriptions]
tools: [info_plist_audit, project_info_plist]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Ios Privacy Permissions

Request permissions at the right time with clear purpose strings and graceful denial.

## When to use this skill
- The user asks for work involving: permissions, privacy, usage descriptions.
- You are about to change code in the Security area and want SwiftCode's standard workflow.

## Workflow
1. List every permission the app needs and why.
2. Add specific NS*UsageDescription strings.
3. Request in context, after explaining the benefit.
4. Handle denied/restricted states with a path to Settings.
5. Re-check status on foreground.

## Rules
- Request the minimum.
- Never block core features unnecessarily.

## Verification
- [ ] Denied paths tested.
- [ ] Descriptions reviewed.

## Avoid
- Requesting everything at launch.
- Vague descriptions.

## Recommended SwiftCode tools
- `info_plist_audit`
- `project_info_plist`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
