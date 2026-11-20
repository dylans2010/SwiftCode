---
name: swiftui-forms-input
description: "Build forms with validation, focus management and keyboard handling in SwiftUI."
category: UI Design
tags: [forms, validation, focus, textfield]
tools: [scan_swiftui_property_wrappers, file_read]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Swiftui Forms Input

Build forms with validation, focus management and keyboard handling in SwiftUI.

## When to use this skill
- The user asks for work involving: forms, validation, focus, textfield.
- You are about to change code in the UI Design area and want SwiftCode's standard workflow.

## Workflow
1. Group fields in Form/Section with labels.
2. Validate on change and on submit; show inline messages.
3. Use @FocusState to move focus and submitLabel for the return key.
4. Set textContentType/keyboardType for autofill.
5. Disable submit until valid; show progress while submitting.

## Rules
- Validation logic lives in a testable model.
- Never lose user input on error.

## Verification
- [ ] Validation unit tests pass.
- [ ] Autofill works for credentials.

## Avoid
- Alert-only validation.
- Clearing fields on failure.

## Recommended SwiftCode tools
- `scan_swiftui_property_wrappers`
- `file_read`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
