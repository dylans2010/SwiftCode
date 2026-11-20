---
name: macos-menu-bar-apps
description: "Build macOS menu bar utilities with MenuBarExtra."
category: Platform
tags: [macos, menu bar, utility]
tools: [swift_list_swiftui_views, project_info_plist]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Macos Menu Bar Apps

Build macOS menu bar utilities with MenuBarExtra.

## When to use this skill
- The user asks for work involving: macos, menu bar, utility.
- You are about to change code in the Platform area and want SwiftCode's standard workflow.

## Workflow
1. Use MenuBarExtra with menu or window style.
2. Set LSUIElement for agent apps without a Dock icon when appropriate.
3. Provide settings and a quit command.
4. Launch at login with SMAppService if the user opts in.
5. Keep resource use minimal.

## Rules
- Low CPU when idle.
- Clear way to quit.

## Verification
- [ ] Works after login launch.
- [ ] Accessible via keyboard.

## Avoid
- Polling timers.
- No quit option.

## Recommended SwiftCode tools
- `swift_list_swiftui_views`
- `project_info_plist`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
