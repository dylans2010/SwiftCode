---
name: swiftui-toolbar-menus-commands
description: "Build toolbars, context menus and keyboard commands in SwiftUI apps."
category: UI Design
tags: [toolbar, context menu, commands]
tools: [swift_list_swiftui_views]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Swiftui Toolbar Menus Commands

Build toolbars, context menus and keyboard commands in SwiftUI apps.

## When to use this skill
- The user asks for work involving: toolbar, context menu, commands.
- You are about to change code in the UI Design area and want SwiftCode's standard workflow.

## Workflow
1. Place toolbar items with semantic placements (primaryAction, navigation, status).
2. Add contextMenu for secondary actions on items.
3. Expose app commands with CommandMenu and keyboardShortcut.
4. Keep the same action reachable from toolbar, menu and shortcut.
5. Provide help text for toolbar buttons on macOS.

## Rules
- Primary actions are discoverable.
- Shortcuts follow platform conventions.

## Verification
- [ ] Every command has a shortcut or menu entry.
- [ ] VoiceOver reads toolbar items.

## Avoid
- Hidden critical actions only in context menus.
- Conflicting shortcuts.

## Recommended SwiftCode tools
- `swift_list_swiftui_views`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
