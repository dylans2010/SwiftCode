---
name: app-store-submission
description: "Prepare a build for App Store submission and review."
category: Platform
tags: [app store, submission, review]
tools: [project_info_plist, codesign_inspect, info_plist_audit]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# App Store Submission

Prepare a build for App Store submission and review.

## When to use this skill
- The user asks for work involving: app store, submission, review.
- You are about to change code in the Platform area and want SwiftCode's standard workflow.

## Workflow
1. Check version/build numbers, icons and launch screens.
2. Verify privacy manifest, usage descriptions and export compliance.
3. Archive with distribution signing and validate.
4. Prepare review notes and demo credentials.
5. Upload and track processing.

## Rules
- Follow App Review Guidelines.
- No private APIs.

## Verification
- [ ] Validation passes.
- [ ] Metadata complete.

## Avoid
- Submitting debug builds.
- Missing demo accounts.

## Recommended SwiftCode tools
- `project_info_plist`
- `codesign_inspect`
- `info_plist_audit`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
