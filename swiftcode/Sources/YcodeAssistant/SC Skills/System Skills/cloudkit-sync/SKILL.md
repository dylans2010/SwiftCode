---
name: cloudkit-sync
description: "Sync data across devices with CloudKit or SwiftData/Core Data CloudKit integration."
category: Data & Persistence
tags: [cloudkit, sync, icloud]
tools: [project_entitlements, scan_swiftdata_usage]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Cloudkit Sync

Sync data across devices with CloudKit or SwiftData/Core Data CloudKit integration.

## When to use this skill
- The user asks for work involving: cloudkit, sync, icloud.
- You are about to change code in the Data & Persistence area and want SwiftCode's standard workflow.

## Workflow
1. Enable iCloud + CloudKit capability and container.
2. Make models CloudKit-compatible (optional or defaulted attributes, no unique constraints).
3. Handle account status changes.
4. Test with two devices/simulators and the CloudKit console.
5. Deploy schema to production before release.

## Rules
- Treat sync as eventually consistent.
- Resolve conflicts deterministically.

## Verification
- [ ] Two-device sync verified.
- [ ] Signed-out iCloud handled.

## Avoid
- Assuming instant sync.
- Unique constraints with CloudKit.

## Recommended SwiftCode tools
- `project_entitlements`
- `scan_swiftdata_usage`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
