---
name: on-device-ml-coreml
description: "Run on-device ML with Core ML and Foundation Models frameworks."
category: AI & Agents
tags: [coreml, machine learning, on-device]
tools: [file_type_detect, swift_list_types]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# On Device Ml Coreml

Run on-device ML with Core ML and Foundation Models frameworks.

## When to use this skill
- The user asks for work involving: coreml, machine learning, on-device.
- You are about to change code in the AI & Agents area and want SwiftCode's standard workflow.

## Workflow
1. Pick or convert a model (coremltools).
2. Add the model and use generated classes.
3. Run predictions off the main actor.
4. Measure latency and memory.

## Rules
- Prefer on-device for privacy.
- Handle unsupported devices.

## Verification
- [ ] Predictions correct on test inputs.
- [ ] Latency within budget.

## Avoid
- Running models on main.
- Shipping huge models without need.

## Recommended SwiftCode tools
- `file_type_detect`
- `swift_list_types`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
