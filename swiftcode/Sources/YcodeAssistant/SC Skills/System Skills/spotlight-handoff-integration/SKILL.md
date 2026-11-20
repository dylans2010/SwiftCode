---
name: spotlight-handoff-integration
description: "Integrate Core Spotlight, NSUserActivity and Handoff."
category: Platform
tags: [spotlight, handoff, user activity]
tools: [swift_list_types, project_entitlements]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Spotlight Handoff Integration

Integrate Core Spotlight, NSUserActivity and Handoff.

## When to use this skill
- The user asks for work involving: spotlight, handoff, user activity.
- You are about to change code in the Platform area and want SwiftCode's standard workflow.

## Workflow
1. Index content with CSSearchableItem and update/delete on changes.
2. Advertise NSUserActivity for current screens.
3. Handle continuation by routing to the right screen.
4. Keep indexed data minimal and private-aware.
5. Test search results and Handoff between devices.

## Rules
- Index only user-meaningful content.
- Remove items when data is deleted.

## Verification
- [ ] Search result opens the right screen.
- [ ] Handoff continues state.

## Avoid
- Indexing sensitive data.
- Stale index entries.

## Recommended SwiftCode tools
- `swift_list_types`
- `project_entitlements`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
