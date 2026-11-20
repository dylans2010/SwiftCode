---
name: healthkit-integration
description: "Read and write HealthKit data with granular permissions."
category: Platform
tags: [healthkit, health, privacy]
tools: [project_entitlements, info_plist_audit]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Healthkit Integration

Read and write HealthKit data with granular permissions.

## When to use this skill
- The user asks for work involving: healthkit, health, privacy.
- You are about to change code in the Platform area and want SwiftCode's standard workflow.

## Workflow
1. Enable capability and usage descriptions.
2. Request only needed types.
3. Query with HKSampleQueryDescriptor async APIs.
4. Handle missing authorization gracefully (read status is hidden).

## Rules
- Health data never leaves device without consent.
- Minimal types.

## Verification
- [ ] Works when permission denied.
- [ ] Queries tested on device.

## Avoid
- Requesting all types.
- Logging health data.

## Recommended SwiftCode tools
- `project_entitlements`
- `info_plist_audit`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
