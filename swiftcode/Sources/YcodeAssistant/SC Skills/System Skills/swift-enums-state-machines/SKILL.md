---
name: swift-enums-state-machines
description: "Model workflows as enum state machines with explicit transitions."
category: Swift Language
tags: [state machine, enums, modeling]
tools: [swift_list_enum_cases, swift_list_enums]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Swift Enums State Machines

Model workflows as enum state machines with explicit transitions.

## When to use this skill
- The user asks for work involving: state machine, enums, modeling.
- You are about to change code in the Swift Language area and want SwiftCode's standard workflow.

## Workflow
1. List states and events.
2. Represent state as enum with associated data.
3. Implement a pure transition function (state, event) -> state.
4. Test every valid and invalid transition.

## Rules
- Illegal transitions are impossible or explicit.
- Side effects outside the reducer.

## Verification
- [ ] Transition table fully tested.
- [ ] UI derived from state.

## Avoid
- Booleans combinations for state.
- Side effects inside transitions.

## Recommended SwiftCode tools
- `swift_list_enum_cases`
- `swift_list_enums`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
