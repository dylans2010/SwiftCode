---
name: swiftui-lists-collections
description: "Build performant lists and grids with selection, swipe actions and pagination."
category: UI Design
tags: [list, lazyvgrid, pagination]
tools: [swift_list_swiftui_views, scan_anyview_usage]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Swiftui Lists Collections

Build performant lists and grids with selection, swipe actions and pagination.

## When to use this skill
- The user asks for work involving: list, lazyvgrid, pagination.
- You are about to change code in the UI Design area and want SwiftCode's standard workflow.

## Workflow
1. Use List or LazyVStack with stable Identifiable ids.
2. Add swipeActions and contextMenu.
3. Paginate with onAppear of last items.
4. Support pull to refresh with .refreshable.

## Rules
- Stable ids.
- Cells lightweight.

## Verification
- [ ] Smooth scrolling with 10k items.
- [ ] Pagination loads once per page.

## Avoid
- Index-based ids.
- Heavy cells.

## Recommended SwiftCode tools
- `swift_list_swiftui_views`
- `scan_anyview_usage`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
