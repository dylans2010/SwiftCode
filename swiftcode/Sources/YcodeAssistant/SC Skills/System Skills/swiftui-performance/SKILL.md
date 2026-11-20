---
name: swiftui-performance
description: "Make SwiftUI views fast: minimal invalidation, lazy containers and stable identity."
category: Performance
tags: [swiftui, performance, rendering]
tools: [scan_anyview_usage, scan_geometry_reader, scan_formatter_allocations, swift_list_swiftui_views]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Swiftui Performance

Make SwiftUI views fast: minimal invalidation, lazy containers and stable identity.

## When to use this skill
- The user asks for work involving: swiftui, performance, rendering.
- You are about to change code in the Performance area and want SwiftCode's standard workflow.

## Workflow
1. Use Self._printChanges() to find excess updates.
2. Split large views so state changes invalidate less.
3. Use Lazy stacks/List for long collections with stable ids.
4. Avoid expensive work in body; precompute in models.
5. Cache formatters and images.

## Rules
- Identity must be stable (no UUID() in body).
- Keep body pure.

## Verification
- [ ] Scrolling at 60/120 fps.
- [ ] Fewer body re-evaluations measured.

## Avoid
- AnyView everywhere.
- Sorting/filtering in body.

## Recommended SwiftCode tools
- `scan_anyview_usage`
- `scan_geometry_reader`
- `scan_formatter_allocations`
- `swift_list_swiftui_views`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
