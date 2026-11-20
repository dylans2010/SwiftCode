---
name: swiftui-sheets-alerts-dialogs
description: "Present sheets, alerts, confirmation dialogs and popovers correctly in SwiftUI."
category: UI Design
tags: [sheets, alerts, dialogs]
tools: [swift_list_swiftui_views, scan_swiftui_property_wrappers]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Swiftui Sheets Alerts Dialogs

Present sheets, alerts, confirmation dialogs and popovers correctly in SwiftUI.

## When to use this skill
- The user asks for work involving: sheets, alerts, dialogs.
- You are about to change code in the UI Design area and want SwiftCode's standard workflow.

## Workflow
1. Drive presentation with item-based or boolean state owned by the presenting view.
2. Use confirmationDialog for destructive choices with role: .destructive.
3. Use presentationDetents for partial sheets.
4. Dismiss with @Environment(\.dismiss) inside presented views.
5. Avoid stacking multiple presentations from one view.

## Rules
- Destructive actions always confirm.
- Presentation state is not global.

## Verification
- [ ] Each presentation path tested in previews.
- [ ] Keyboard and VoiceOver can dismiss.

## Avoid
- Alerts for non-critical info.
- Multiple .sheet modifiers fighting on one view.

## Recommended SwiftCode tools
- `swift_list_swiftui_views`
- `scan_swiftui_property_wrappers`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
