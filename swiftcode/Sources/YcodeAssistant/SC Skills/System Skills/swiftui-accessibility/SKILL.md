---
name: swiftui-accessibility
description: "Make SwiftUI interfaces accessible: VoiceOver labels, Dynamic Type, contrast, focus and reduced motion."
category: UI Design
tags: [accessibility, voiceover, dynamic type, a11y]
tools: [scan_accessibility_modifiers, scan_sf_symbol_images, color_contrast_ratio, scan_fixed_font_sizes]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Swiftui Accessibility

Make SwiftUI interfaces accessible: VoiceOver labels, Dynamic Type, contrast, focus and reduced motion.

## When to use this skill
- The user asks for work involving: accessibility, voiceover, dynamic type, a11y.
- You are about to change code in the UI Design area and want SwiftCode's standard workflow.

## Workflow
1. Find icon-only buttons with scan_sf_symbol_images and add accessibilityLabel.
2. Group related elements with accessibilityElement(children: .combine).
3. Check text/background pairs with color_contrast_ratio (AA 4.5:1).
4. Respect accessibilityReduceMotion and avoid information conveyed only by color.
5. Run Accessibility Inspector/VoiceOver on key flows.

## Rules
- Labels describe purpose, not appearance.
- Hit targets at least 44x44 pt.

## Verification
- [ ] All interactive elements have labels.
- [ ] Contrast passes AA.

## Avoid
- Hiding important elements from accessibility.
- Fixed font sizes.

## Recommended SwiftCode tools
- `scan_accessibility_modifiers`
- `scan_sf_symbol_images`
- `color_contrast_ratio`
- `scan_fixed_font_sizes`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
