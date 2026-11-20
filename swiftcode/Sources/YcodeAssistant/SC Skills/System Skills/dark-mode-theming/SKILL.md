---
name: dark-mode-theming
description: "Support dark mode and high contrast with semantic colors."
category: UI Design
tags: [dark mode, theming, colors]
tools: [scan_hardcoded_colors, color_contrast_ratio, asset_catalog_list]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Dark Mode Theming

Support dark mode and high contrast with semantic colors.

## When to use this skill
- The user asks for work involving: dark mode, theming, colors.
- You are about to change code in the UI Design area and want SwiftCode's standard workflow.

## Workflow
1. Replace literal colors with semantic assets.
2. Provide dark and high-contrast variants.
3. Check contrast in both modes.
4. Preview both appearances.

## Rules
- Never hardcode white/black for text.
- Images adapt or have variants.

## Verification
- [ ] Both modes previewed.
- [ ] Contrast passes.

## Avoid
- Inverting colors programmatically.
- Hardcoded colors.

## Recommended SwiftCode tools
- `scan_hardcoded_colors`
- `color_contrast_ratio`
- `asset_catalog_list`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
