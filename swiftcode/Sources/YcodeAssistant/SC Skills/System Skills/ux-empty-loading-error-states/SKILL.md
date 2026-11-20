---
name: ux-empty-loading-error-states
description: "Design consistent empty, loading, error and offline states for every screen."
category: UI Design
tags: [ux, loading, error states, empty states]
tools: [swift_list_swiftui_views, scan_view_lifecycle_tasks]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Ux Empty Loading Error States

Design consistent empty, loading, error and offline states for every screen.

## When to use this skill
- The user asks for work involving: ux, loading, error states, empty states.
- You are about to change code in the UI Design area and want SwiftCode's standard workflow.

## Workflow
1. Model screen state as enum Loadable<T> { idle, loading, loaded(T), failed(Error) }.
2. Show skeletons/ProgressView for loading.
3. Use ContentUnavailableView for empty states with a call to action.
4. Show actionable errors with retry.
5. Test each state via previews.

## Rules
- Never show a blank screen.
- Errors are human readable.

## Verification
- [ ] Every async screen has 4 previewed states.
- [ ] Retry re-runs the load.

## Avoid
- Spinners without timeouts.
- Raw error.localizedDescription dumps for users.

## Recommended SwiftCode tools
- `swift_list_swiftui_views`
- `scan_view_lifecycle_tasks`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
