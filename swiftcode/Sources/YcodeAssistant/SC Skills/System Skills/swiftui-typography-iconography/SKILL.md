---
name: swiftui-typography-iconography
description: "Apply consistent typography and SF Symbols usage across an app."
category: UI Design
tags: [typography, sf symbols, icons]
tools: [scan_fixed_font_sizes, scan_sf_symbol_images]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Swiftui Typography Iconography

Apply consistent typography and SF Symbols usage across an app.

## When to use this skill
- The user asks for work involving: typography, sf symbols, icons.
- You are about to change code in the UI Design area and want SwiftCode's standard workflow.

## Workflow
1. Use semantic text styles (title, headline, body, caption).
2. Define a small set of weights and use them consistently.
3. Use SF Symbols with matching text style and symbolRenderingMode.
4. Give icon-only buttons accessibility labels.
5. Check symbol availability for the deployment target.

## Rules
- Hierarchy through style, not only size.
- Symbols scale with text.

## Verification
- [ ] No fixed font sizes in scope.
- [ ] Every icon-only control labeled.

## Avoid
- Mixing many custom fonts.
- Using symbols as decoration without meaning.

## Recommended SwiftCode tools
- `scan_fixed_font_sizes`
- `scan_sf_symbol_images`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
