---
name: simulator-device-testing
description: "Run and debug apps on simulators reliably from the command line."
category: Testing
tags: [simulator, simctl, device testing]
tools: [simctl_device_list, simctl_runtime_list, xcodebuild_sdk_list]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Simulator Device Testing

Run and debug apps on simulators reliably from the command line.

## When to use this skill
- The user asks for work involving: simulator, simctl, device testing.
- You are about to change code in the Testing area and want SwiftCode's standard workflow.

## Workflow
1. List devices/runtimes.
2. Boot a specific device by UDID.
3. Build and install with xcodebuild -destination.
4. Collect logs and screenshots with simctl.

## Rules
- Use fixed device for reproducibility.
- Erase devices for clean state when needed.

## Verification
- [ ] Tests run on named device.
- [ ] Logs captured.

## Avoid
- Relying on 'any' destination.
- Stale simulator state.

## Recommended SwiftCode tools
- `simctl_device_list`
- `simctl_runtime_list`
- `xcodebuild_sdk_list`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
