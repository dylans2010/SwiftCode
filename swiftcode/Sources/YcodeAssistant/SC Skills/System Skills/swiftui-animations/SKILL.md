---
name: swiftui-animations
description: "Add purposeful, performant animations and transitions in SwiftUI."
category: UI Design
tags: [animation, transition, motion]
tools: [scan_view_lifecycle_tasks, file_read]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Swiftui Animations

Add purposeful, performant animations and transitions in SwiftUI.

## When to use this skill
- The user asks for work involving: animation, transition, motion.
- You are about to change code in the UI Design area and want SwiftCode's standard workflow.

## Workflow
1. Identify the state change the animation communicates.
2. Use withAnimation or .animation(_:value:) scoped to a value.
3. Use matchedGeometryEffect/transitions for structural changes.
4. Respect accessibilityReduceMotion.
5. Profile with Instruments if frames drop.

## Rules
- Durations 0.2–0.35s for UI feedback.
- Animate state, not views directly.

## Verification
- [ ] Reduce Motion disables decorative motion.
- [ ] No implicit animation leaks to unrelated views.

## Avoid
- Unscoped .animation() modifiers.
- Long blocking animations.

## Recommended SwiftCode tools
- `scan_view_lifecycle_tasks`
- `file_read`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
