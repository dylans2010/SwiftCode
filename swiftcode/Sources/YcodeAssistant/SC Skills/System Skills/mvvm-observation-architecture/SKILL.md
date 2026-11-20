---
name: mvvm-observation-architecture
description: "Structure SwiftUI features with views, @Observable view models and services."
category: Architecture
tags: [mvvm, observation, architecture]
tools: [scan_observable_state, swift_list_swiftui_views, swift_list_classes]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Mvvm Observation Architecture

Structure SwiftUI features with views, @Observable view models and services.

## When to use this skill
- The user asks for work involving: mvvm, observation, architecture.
- You are about to change code in the Architecture area and want SwiftCode's standard workflow.

## Workflow
1. Keep views declarative; move logic into an @Observable @MainActor model.
2. Inject services via initializer protocols.
3. Expose state as simple properties and intents as methods.
4. Unit test models without UI.
5. Keep navigation in a router or parent.

## Rules
- Models don't import SwiftUI unless necessary.
- One model per screen.

## Verification
- [ ] Model unit tests cover intents.
- [ ] Views have previews with sample models.

## Avoid
- Massive view models.
- Views calling network directly.

## Recommended SwiftCode tools
- `scan_observable_state`
- `swift_list_swiftui_views`
- `swift_list_classes`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
