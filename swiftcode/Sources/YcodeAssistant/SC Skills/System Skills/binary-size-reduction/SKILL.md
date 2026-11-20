---
name: binary-size-reduction
description: "Reduce app binary and download size."
category: Performance
tags: [binary size, app thinning, assets]
tools: [workspace_largest_files, binary_architectures, image_asset_size_report]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Binary Size Reduction

Reduce app binary and download size.

## When to use this skill
- The user asks for work involving: binary size, app thinning, assets.
- You are about to change code in the Performance area and want SwiftCode's standard workflow.

## Workflow
1. Find the largest files and assets.
2. Compress or convert images (HEIC, vector PDFs/SF Symbols).
3. Remove unused resources and dependencies.
4. Enable dead stripping and appropriate optimization settings.
5. Measure with an App Store size report.

## Rules
- Measure before and after.
- Keep quality acceptable.

## Verification
- [ ] Size reduction recorded.
- [ ] No missing resources at runtime.

## Avoid
- Shipping debug symbols in the bundle.
- Duplicate assets.

## Recommended SwiftCode tools
- `workspace_largest_files`
- `binary_architectures`
- `image_asset_size_report`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
