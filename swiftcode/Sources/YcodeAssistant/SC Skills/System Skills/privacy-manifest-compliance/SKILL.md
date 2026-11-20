---
name: privacy-manifest-compliance
description: "Prepare privacy manifests, usage descriptions and data collection disclosures."
category: Security
tags: [privacy, PrivacyInfo.xcprivacy, usage descriptions]
tools: [info_plist_audit, workspace_find_by_glob, scan_userdefaults_usage]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Privacy Manifest Compliance

Prepare privacy manifests, usage descriptions and data collection disclosures.

## When to use this skill
- The user asks for work involving: privacy, PrivacyInfo.xcprivacy, usage descriptions.
- You are about to change code in the Security area and want SwiftCode's standard workflow.

## Workflow
1. Find PrivacyInfo.xcprivacy files with workspace_find_by_glob.
2. List required-reason APIs used (UserDefaults, file timestamps, disk space, boot time).
3. Declare reasons and collected data types.
4. Add precise NS*UsageDescription strings.
5. Verify third-party SDK manifests.

## Rules
- Descriptions explain user benefit.
- Collect the minimum data.

## Verification
- [ ] Manifest validates in Xcode archive report.
- [ ] Every permission prompt has a description.

## Avoid
- Generic 'needed for app' strings.
- Undeclared tracking.

## Recommended SwiftCode tools
- `info_plist_audit`
- `workspace_find_by_glob`
- `scan_userdefaults_usage`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
