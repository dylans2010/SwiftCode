---
name: swiftui-design-system
description: "Create a reusable design system (colors, typography, spacing, components) for SwiftUI apps."
category: UI Design
tags: [design system, tokens, theming, components]
tools: [scan_hardcoded_colors, scan_fixed_font_sizes, asset_catalog_list]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Swiftui Design System

Create a reusable design system (colors, typography, spacing, components) for SwiftUI apps.

## When to use this skill
- The user asks for work involving: design system, tokens, theming, components.
- You are about to change code in the UI Design area and want SwiftCode's standard workflow.

## Workflow
1. Inventory existing colors/fonts with scan_hardcoded_colors and scan_fixed_font_sizes.
2. Define semantic color assets (background, surface, accent, textPrimary...) with dark variants.
3. Define typography as Font text styles extensions, spacing as an enum of constants.
4. Build primitives (PrimaryButton, Card, Tag) as ButtonStyle/ViewModifier.
5. Replace literals across the app and document usage in a README section.

## Rules
- Semantic names over raw hues.
- Every component supports Dynamic Type and dark mode.

## Verification
- [ ] Hardcoded color/font scans trend to zero.
- [ ] Components have previews.

## Avoid
- Duplicating styles per screen.
- Color(red:green:blue:) literals in views.

## Recommended SwiftCode tools
- `scan_hardcoded_colors`
- `scan_fixed_font_sizes`
- `asset_catalog_list`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
