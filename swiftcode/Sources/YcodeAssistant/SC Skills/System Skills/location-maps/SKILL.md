---
name: location-maps
description: "Use Core Location and MapKit with privacy-respecting permissions."
category: Platform
tags: [location, mapkit, corelocation]
tools: [info_plist_audit, scan_timer_usage]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Location Maps

Use Core Location and MapKit with privacy-respecting permissions.

## When to use this skill
- The user asks for work involving: location, mapkit, corelocation.
- You are about to change code in the Platform area and want SwiftCode's standard workflow.

## Workflow
1. Add usage descriptions.
2. Request when-in-use authorization contextually.
3. Use CLLocationUpdate.liveUpdates or delegate with appropriate accuracy.
4. Display with SwiftUI Map and annotations.

## Rules
- Lowest accuracy that works.
- Stop updates when done.

## Verification
- [ ] Denied state handled.
- [ ] Battery impact low.

## Avoid
- Always authorization without need.
- Continuous best accuracy.

## Recommended SwiftCode tools
- `info_plist_audit`
- `scan_timer_usage`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
