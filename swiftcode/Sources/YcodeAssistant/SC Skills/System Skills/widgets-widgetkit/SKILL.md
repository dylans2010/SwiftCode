---
name: widgets-widgetkit
description: "Build WidgetKit widgets with timelines, intents and deep links."
category: Platform
tags: [widgets, widgetkit, app intents]
tools: [swift_list_swiftui_views, project_entitlements]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Widgets Widgetkit

Build WidgetKit widgets with timelines, intents and deep links.

## When to use this skill
- The user asks for work involving: widgets, widgetkit, app intents.
- You are about to change code in the Platform area and want SwiftCode's standard workflow.

## Workflow
1. Create a widget extension and shared App Group.
2. Implement TimelineProvider with real data snapshots.
3. Support families and placeholders.
4. Use App Intents for configuration/interactivity.
5. Deep link with widgetURL.

## Rules
- Widgets are glanceable.
- Reload timelines efficiently.

## Verification
- [ ] Previews for each family.
- [ ] Data shared via App Group works.

## Avoid
- Network calls on every refresh.
- Heavy views in widgets.

## Recommended SwiftCode tools
- `swift_list_swiftui_views`
- `project_entitlements`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
