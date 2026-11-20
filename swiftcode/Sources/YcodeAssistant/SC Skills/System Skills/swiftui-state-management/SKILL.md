---
name: swiftui-state-management
description: "Choose correct state ownership in SwiftUI using @State, @Binding, @Observable and @Environment."
category: UI Design
tags: [state, observation, @Observable, data flow]
tools: [scan_swiftui_property_wrappers, scan_observable_state]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Swiftui State Management

Choose correct state ownership in SwiftUI using @State, @Binding, @Observable and @Environment.

## When to use this skill
- The user asks for work involving: state, observation, @Observable, data flow.
- You are about to change code in the UI Design area and want SwiftCode's standard workflow.

## Workflow
1. Map each piece of state to its single owner.
2. Use @State for view-local values and @Observable models held in @State for reference state.
3. Pass @Binding/@Bindable down instead of duplicating state.
4. Use @Environment for app-wide dependencies.
5. Migrate ObservableObject/@Published to @Observable when the target allows.

## Rules
- Never initialize @StateObject/@State from parent values expecting updates.
- Keep models @MainActor when they drive UI.

## Verification
- [ ] No duplicated sources of truth.
- [ ] Views update correctly in previews and tests.

## Avoid
- Storing derived values as state.
- Mutating state during body evaluation.

## Recommended SwiftCode tools
- `scan_swiftui_property_wrappers`
- `scan_observable_state`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
