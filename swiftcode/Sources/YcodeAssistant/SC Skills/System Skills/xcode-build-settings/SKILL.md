---
name: xcode-build-settings
description: "Manage Xcode build settings and xcconfig files cleanly."
category: Build & Tooling
tags: [xcconfig, build settings, configurations]
tools: [xcodebuild_build_settings, xcodebuild_list_json, pbxproj_lint]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Xcode Build Settings

Manage Xcode build settings and xcconfig files cleanly.

## When to use this skill
- The user asks for work involving: xcconfig, build settings, configurations.
- You are about to change code in the Build & Tooling area and want SwiftCode's standard workflow.

## Workflow
1. Read current settings with xcodebuild_build_settings.
2. Move settings into shared .xcconfig files per configuration.
3. Use $(inherited) and avoid duplication.
4. Document non-default settings.
5. Verify Debug and Release builds.

## Rules
- Single source for each setting.
- No secrets in xcconfig committed.

## Verification
- [ ] Both configurations build.
- [ ] Settings diff reviewed.

## Avoid
- Editing pbxproj by hand without verification.
- Conflicting target-level overrides.

## Recommended SwiftCode tools
- `xcodebuild_build_settings`
- `xcodebuild_list_json`
- `pbxproj_lint`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
