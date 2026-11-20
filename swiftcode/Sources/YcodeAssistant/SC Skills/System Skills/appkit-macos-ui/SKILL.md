---
name: appkit-macos-ui
description: "Design native macOS interfaces: menus, toolbars, sidebars, keyboard shortcuts and window behavior."
category: UI Design
tags: [macos, appkit, menus, toolbar, keyboard shortcuts]
tools: [swift_list_swiftui_views, scan_objc_attributes]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Appkit Macos Ui

Design native macOS interfaces: menus, toolbars, sidebars, keyboard shortcuts and window behavior.

## When to use this skill
- The user asks for work involving: macos, appkit, menus, toolbar, keyboard shortcuts.
- You are about to change code in the UI Design area and want SwiftCode's standard workflow.

## Workflow
1. Use NavigationSplitView/Sidebar style and Settings scene.
2. Add commands (CommandMenu/CommandGroup) with standard shortcuts.
3. Support multiple windows and state restoration.
4. Use toolbars with labels and help tooltips.
5. Respect system accent color, materials and full keyboard access.

## Rules
- Follow platform conventions (Cmd-, for Settings).
- Every action reachable by keyboard.

## Verification
- [ ] Menu items have shortcuts where expected.
- [ ] Window resizes gracefully.

## Avoid
- iOS-style tab bars on macOS.
- Custom title bars that break dragging.

## Recommended SwiftCode tools
- `swift_list_swiftui_views`
- `scan_objc_attributes`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
