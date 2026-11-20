---
name: swiftui-adaptive-iphone-ipad
description: "Design SwiftUI layouts that adapt across iPhone, iPad and multitasking sizes."
category: UI Design
tags: [adaptive layout, ipad, size classes]
tools: [swift_list_swiftui_views, scan_geometry_reader]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Swiftui Adaptive Iphone Ipad

Design SwiftUI layouts that adapt across iPhone, iPad and multitasking sizes.

## When to use this skill
- The user asks for work involving: adaptive layout, ipad, size classes.
- You are about to change code in the UI Design area and want SwiftCode's standard workflow.

## Workflow
1. Read horizontalSizeClass and adapt structure, not just spacing.
2. Use NavigationSplitView for regular widths and stacks for compact.
3. Use ViewThatFits for alternative arrangements.
4. Support Split View and Slide Over sizes.
5. Preview on iPhone SE, Pro Max and iPad in multiple orientations.

## Rules
- One codebase, adaptive structure.
- No device-model checks.

## Verification
- [ ] Previews for each size class.
- [ ] No clipped content in multitasking.

## Avoid
- Hardcoded screen widths.
- UIDevice idiom branching for layout.

## Recommended SwiftCode tools
- `swift_list_swiftui_views`
- `scan_geometry_reader`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
