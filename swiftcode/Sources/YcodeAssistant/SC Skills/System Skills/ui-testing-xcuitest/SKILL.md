---
name: ui-testing-xcuitest
description: "Write reliable UI tests with XCUITest using accessibility identifiers."
category: Testing
tags: [ui tests, xcuitest, automation]
tools: [scan_accessibility_modifiers, simctl_device_list]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Ui Testing Xcuitest

Write reliable UI tests with XCUITest using accessibility identifiers.

## When to use this skill
- The user asks for work involving: ui tests, xcuitest, automation.
- You are about to change code in the Testing area and want SwiftCode's standard workflow.

## Workflow
1. Add accessibilityIdentifier to key controls.
2. Launch with launchArguments to seed deterministic state.
3. Use waitForExistence instead of sleep.
4. Page-object pattern for screens.
5. Run on a fixed simulator from simctl_device_list.

## Rules
- Test critical user journeys only.
- Reset state between tests.

## Verification
- [ ] Flake rate measured over 5 runs.
- [ ] Identifiers stable.

## Avoid
- Querying by visible text that is localized.
- sleep() calls.

## Recommended SwiftCode tools
- `scan_accessibility_modifiers`
- `simctl_device_list`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
