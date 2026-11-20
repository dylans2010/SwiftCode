---
name: ios-app-lifecycle
description: "Handle SwiftUI app and scene lifecycle, background and state restoration."
category: Platform
tags: [lifecycle, scenePhase, background]
tools: [scan_view_lifecycle_tasks, scan_notification_center]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Ios App Lifecycle

Handle SwiftUI app and scene lifecycle, background and state restoration.

## When to use this skill
- The user asks for work involving: lifecycle, scenePhase, background.
- You are about to change code in the Platform area and want SwiftCode's standard workflow.

## Workflow
1. Use App/Scene with @Environment(\.scenePhase).
2. Save state on background; restore with SceneStorage.
3. Register background tasks with BGTaskScheduler when needed.
4. Handle URL and user activity continuation.
5. Test termination and relaunch.

## Rules
- No heavy work in scenePhase changes.
- Persist before suspension.

## Verification
- [ ] State restores after kill.
- [ ] Background tasks scheduled correctly.

## Avoid
- Relying on app termination callbacks.
- AppDelegate logic duplicated.

## Recommended SwiftCode tools
- `scan_view_lifecycle_tasks`
- `scan_notification_center`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
