---
name: snapshot-and-preview-testing
description: "Use previews and snapshot tests to catch SwiftUI visual regressions."
category: Testing
tags: [snapshot tests, previews, visual regression]
tools: [scan_preview_declarations, swift_list_swiftui_views]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Snapshot And Preview Testing

Use previews and snapshot tests to catch SwiftUI visual regressions.

## When to use this skill
- The user asks for work involving: snapshot tests, previews, visual regression.
- You are about to change code in the Testing area and want SwiftCode's standard workflow.

## Workflow
1. Ensure each reusable view has #Preview variants.
2. Render views to images with ImageRenderer in tests.
3. Compare against recorded references with tolerance.
4. Cover dark mode and large text.
5. Re-record intentionally and review diffs.

## Rules
- Snapshots are reviewed like code.
- Deterministic data in snapshots.

## Verification
- [ ] Snapshots stable across runs.
- [ ] Previews compile.

## Avoid
- Recording on different OS versions.
- Random data.

## Recommended SwiftCode tools
- `scan_preview_declarations`
- `swift_list_swiftui_views`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
