---
name: swiftui-custom-components
description: "Build reusable SwiftUI components with styles, modifiers and environment configuration."
category: UI Design
tags: [components, viewmodifier, buttonstyle]
tools: [swift_list_swiftui_views, scan_preview_declarations]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Swiftui Custom Components

Build reusable SwiftUI components with styles, modifiers and environment configuration.

## When to use this skill
- The user asks for work involving: components, viewmodifier, buttonstyle.
- You are about to change code in the UI Design area and want SwiftCode's standard workflow.

## Workflow
1. Identify repeated UI.
2. Extract a View with minimal inputs or a ViewModifier.
3. Provide styles via protocols (ButtonStyle) and environment.
4. Add previews and documentation.

## Rules
- Components are configurable, not forked.
- Accessible by default.

## Verification
- [ ] Used in 2+ places.
- [ ] Previews cover states.

## Avoid
- Huge config initializers.
- Copy-paste variants.

## Recommended SwiftCode tools
- `swift_list_swiftui_views`
- `scan_preview_declarations`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
