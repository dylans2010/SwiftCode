---
name: swiftui-layout-fundamentals
description: "Build adaptive SwiftUI layouts with stacks, grids, ViewThatFits and proper spacing instead of hard-coded frames."
category: UI Design
tags: [swiftui, layout, adaptive, grid]
tools: [scan_geometry_reader, scan_anyview_usage, swift_list_swiftui_views]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Swiftui Layout Fundamentals

Build adaptive SwiftUI layouts with stacks, grids, ViewThatFits and proper spacing instead of hard-coded frames.

## When to use this skill
- The user asks for work involving: swiftui, layout, adaptive, grid.
- You are about to change code in the UI Design area and want SwiftCode's standard workflow.

## Workflow
1. Sketch the hierarchy: containers, content, actions.
2. Use VStack/HStack/Grid/LazyVGrid with consistent spacing tokens (4/8/12/16/24).
3. Use ViewThatFits or size classes for compact vs regular widths.
4. Prefer frame(maxWidth: .infinity, alignment:) over fixed widths.
5. Add #Preview variants for light/dark, large Dynamic Type and small devices.

## Rules
- Avoid GeometryReader unless you truly need container size.
- Keep views small; extract subviews over 60 lines.

## Verification
- [ ] Previews render at XS and XXXL Dynamic Type without clipping.
- [ ] No fixed frame widths for text containers.

## Avoid
- Magic number paddings everywhere.
- Nesting AnyView to satisfy the type checker.

## Recommended SwiftCode tools
- `scan_geometry_reader`
- `scan_anyview_usage`
- `swift_list_swiftui_views`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
