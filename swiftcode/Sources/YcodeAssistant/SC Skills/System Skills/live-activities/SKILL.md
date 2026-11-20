---
name: live-activities
description: "Implement Live Activities and Dynamic Island with ActivityKit."
category: Platform
tags: [live activities, dynamic island, activitykit]
tools: [swift_list_swiftui_views, project_info_plist]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Live Activities

Implement Live Activities and Dynamic Island with ActivityKit.

## When to use this skill
- The user asks for work involving: live activities, dynamic island, activitykit.
- You are about to change code in the Platform area and want SwiftCode's standard workflow.

## Workflow
1. Define ActivityAttributes and ContentState.
2. Build Lock Screen and Dynamic Island presentations in a widget extension.
3. Start, update and end activities from the app or push updates.
4. Respect staleness and end activities promptly.
5. Test on device.

## Rules
- Glanceable, minimal content.
- Respect user settings.

## Verification
- [ ] Start/update/end tested.
- [ ] Layouts fit all presentations.

## Avoid
- Using activities for ads.
- Never ending activities.

## Recommended SwiftCode tools
- `swift_list_swiftui_views`
- `project_info_plist`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
