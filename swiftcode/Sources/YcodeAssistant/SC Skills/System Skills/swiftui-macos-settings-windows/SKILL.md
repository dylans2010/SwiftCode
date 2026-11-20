---
name: swiftui-macos-settings-windows
description: "Build macOS Settings scenes, multiple windows and menu bar extras in SwiftUI."
category: UI Design
tags: [macos, settings, windows, menu bar]
tools: [swift_list_swiftui_views, file_read]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Swiftui Macos Settings Windows

Build macOS Settings scenes, multiple windows and menu bar extras in SwiftUI.

## When to use this skill
- The user asks for work involving: macos, settings, windows, menu bar.
- You are about to change code in the UI Design area and want SwiftCode's standard workflow.

## Workflow
1. Add a Settings scene with TabView panes.
2. Use WindowGroup(id:) and openWindow for secondary windows.
3. Use MenuBarExtra for status items.
4. Persist preferences with @AppStorage.

## Rules
- Follow macOS settings conventions.
- Windows restore state.

## Verification
- [ ] Cmd-, opens settings.
- [ ] Windows reopen correctly.

## Avoid
- Modal sheets for settings.
- Hardcoded window sizes.

## Recommended SwiftCode tools
- `swift_list_swiftui_views`
- `file_read`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
