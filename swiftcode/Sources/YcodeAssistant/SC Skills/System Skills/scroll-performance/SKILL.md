---
name: scroll-performance
description: "Achieve smooth scrolling in long SwiftUI and UIKit lists."
category: Performance
tags: [scrolling, lists, performance]
tools: [scan_anyview_usage, scan_formatter_allocations, swift_list_swiftui_views]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Scroll Performance

Achieve smooth scrolling in long SwiftUI and UIKit lists.

## When to use this skill
- The user asks for work involving: scrolling, lists, performance.
- You are about to change code in the Performance area and want SwiftCode's standard workflow.

## Workflow
1. Profile hitches with Instruments.
2. Use lazy containers with stable ids.
3. Downsample and cache images off the main thread.
4. Precompute expensive strings and layouts.
5. Avoid heavy modifiers (shadows, blurs) in cells.

## Rules
- Cells are cheap to create.
- No main-thread I/O while scrolling.

## Verification
- [ ] No hitches in the profiled flow.
- [ ] Memory stable while scrolling.

## Avoid
- Decoding full-size images in cells.
- Recomputing in body.

## Recommended SwiftCode tools
- `scan_anyview_usage`
- `scan_formatter_allocations`
- `swift_list_swiftui_views`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
