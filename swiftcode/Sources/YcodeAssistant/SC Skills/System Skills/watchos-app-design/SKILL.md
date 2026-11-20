---
name: watchos-app-design
description: "Design watchOS apps for glanceable, short interactions."
category: Platform
tags: [watchos, complications, design]
tools: [swift_list_swiftui_views, scan_fixed_font_sizes]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Watchos App Design

Design watchOS apps for glanceable, short interactions.

## When to use this skill
- The user asks for work involving: watchos, complications, design.
- You are about to change code in the Platform area and want SwiftCode's standard workflow.

## Workflow
1. Identify the 1-2 core tasks.
2. Use NavigationStack with simple lists.
3. Add complications/widgets.
4. Sync data with WatchConnectivity or shared backend.
5. Test on small and large watch sizes.

## Rules
- Interactions under 5 seconds.
- Large tap targets.

## Verification
- [ ] Usable on smallest watch.
- [ ] Complications update.

## Avoid
- Dense iPhone screens.
- Long forms.

## Recommended SwiftCode tools
- `swift_list_swiftui_views`
- `scan_fixed_font_sizes`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
