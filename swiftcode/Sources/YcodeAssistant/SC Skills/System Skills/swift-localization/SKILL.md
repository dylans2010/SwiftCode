---
name: swift-localization
description: "Localize Swift apps with String Catalogs, plurals and formatting."
category: Internationalization
tags: [localization_audit, i18n, string catalog]
tools: [localization_audit, scan_string_format_calls, scan_formatter_allocations]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Swift Localization

Localize Swift apps with String Catalogs, plurals and formatting.

## When to use this skill
- The user asks for work involving: localization_audit, i18n, string catalog.
- You are about to change code in the Internationalization area and want SwiftCode's standard workflow.

## Workflow
1. Use String(localized:) and LocalizedStringKey for UI text.
2. Manage strings in Localizable.xcstrings with comments.
3. Use plural variations and format with FormatStyle.
4. Test pseudo-languages and RTL.
5. Export/import for translators.

## Rules
- Never concatenate localized fragments.
- Provide translator comments.

## Verification
- [ ] Pseudolocalization shows no clipped text.
- [ ] RTL layout correct.

## Avoid
- Hardcoded user-facing strings.
- String(format:) with mismatched specifiers.

## Recommended SwiftCode tools
- `localization_audit`
- `scan_string_format_calls`
- `scan_formatter_allocations`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
