---
name: test-strategy-planning
description: "Design a test strategy across unit, integration, UI and manual testing for a feature."
category: Testing
tags: [test strategy, quality, planning]
tools: [swift_list_test_functions, workspace_extension_stats]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Test Strategy Planning

Design a test strategy across unit, integration, UI and manual testing for a feature.

## When to use this skill
- The user asks for work involving: test strategy, quality, planning.
- You are about to change code in the Testing area and want SwiftCode's standard workflow.

## Workflow
1. List risks and critical behaviors of the feature.
2. Map each risk to the cheapest test type that catches it.
3. Define test data and environments.
4. Decide what runs in CI and what is manual.
5. Document exit criteria.

## Rules
- Most tests at the unit level.
- Every critical path covered.

## Verification
- [ ] Strategy reviewed.
- [ ] Exit criteria measurable.

## Avoid
- Only UI tests.
- Testing without risk analysis.

## Recommended SwiftCode tools
- `swift_list_test_functions`
- `workspace_extension_stats`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
