---
name: push-notifications
description: "Implement local and remote notifications with permissions and actions."
category: Platform
tags: [notifications, apns, push]
tools: [project_entitlements, scan_notification_center]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Push Notifications

Implement local and remote notifications with permissions and actions.

## When to use this skill
- The user asks for work involving: notifications, apns, push.
- You are about to change code in the Platform area and want SwiftCode's standard workflow.

## Workflow
1. Request authorization at a meaningful moment.
2. Register for remote notifications and send the token to the server.
3. Define categories/actions.
4. Handle notifications in UNUserNotificationCenterDelegate.
5. Test with simulator push payloads (xcrun simctl push).

## Rules
- Explain value before prompting.
- Never put secrets in payloads.

## Verification
- [ ] Foreground/background/tap handling verified.
- [ ] Denied permission handled.

## Avoid
- Prompting at first launch.
- Unbounded notification spam.

## Recommended SwiftCode tools
- `project_entitlements`
- `scan_notification_center`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
