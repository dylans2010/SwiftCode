---
name: xcode-project-maintenance
description: "Keep Xcode projects healthy: groups, targets, schemes and file references."
category: Build & Tooling
tags: [xcode project, pbxproj_lint, schemes]
tools: [xcodebuild_list_json, pbxproj_lint, workspace_find_by_glob]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Xcode Project Maintenance

Keep Xcode projects healthy: groups, targets, schemes and file references.

## When to use this skill
- The user asks for work involving: xcode project, pbxproj_lint, schemes.
- You are about to change code in the Build & Tooling area and want SwiftCode's standard workflow.

## Workflow
1. List targets/schemes with xcodebuild_list_json.
2. Find missing or orphaned file references.
3. Share schemes needed for CI.
4. Prefer folder-synchronized groups where supported.

## Rules
- Never hand-edit pbxproj without verifying build.
- Keep schemes shared and minimal.

## Verification
- [ ] All schemes build.
- [ ] No missing file references.

## Avoid
- Duplicate file references.
- Unshared CI schemes.

## Recommended SwiftCode tools
- `xcodebuild_list_json`
- `pbxproj_lint`
- `workspace_find_by_glob`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
