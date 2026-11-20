---
name: camera-photos
description: "Integrate camera capture and photo library access correctly."
category: Platform
tags: [camera, photos, avfoundation]
tools: [info_plist_audit, scan_main_thread_checks]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Camera Photos

Integrate camera capture and photo library access correctly.

## When to use this skill
- The user asks for work involving: camera, photos, avfoundation.
- You are about to change code in the Platform area and want SwiftCode's standard workflow.

## Workflow
1. Use PhotosPicker for library access without full permission.
2. Use AVCaptureSession on a dedicated queue for camera.
3. Request permissions with clear descriptions.
4. Handle denied/restricted states.

## Rules
- Limited photo access respected.
- Session work off main.

## Verification
- [ ] Permission flows tested.
- [ ] No main-thread capture work.

## Avoid
- Requesting full library unnecessarily.
- Configuring session on main.

## Recommended SwiftCode tools
- `info_plist_audit`
- `scan_main_thread_checks`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
