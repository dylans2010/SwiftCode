---
name: accessibility-audit
description: "Audit an app for accessibility issues and produce a prioritized fix list."
category: UI Design
tags: [accessibility, audit, wcag]
tools: [scan_accessibility_modifiers, scan_sf_symbol_images, color_contrast_ratio, scan_fixed_font_sizes]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Accessibility Audit

Audit an app for accessibility issues and produce a prioritized fix list.

## When to use this skill
- The user asks for work involving: accessibility, audit, wcag.
- You are about to change code in the UI Design area and want SwiftCode's standard workflow.

## Workflow
1. Run accessibility scans across UI code.
2. Check contrast of key color pairs.
3. Test with VoiceOver, Dynamic Type XXXL, Reduce Motion.
4. Prioritize by user impact and fix.

## Rules
- Blockers first (unlabeled controls, unreadable text).
- Retest after fixes.

## Verification
- [ ] Audit report with severities.
- [ ] Blockers fixed.

## Avoid
- Cosmetic-only audits.
- Ignoring keyboard navigation.

## Recommended SwiftCode tools
- `scan_accessibility_modifiers`
- `scan_sf_symbol_images`
- `color_contrast_ratio`
- `scan_fixed_font_sizes`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
