---
name: offline-first-architecture
description: "Build offline-first features with local persistence and background sync."
category: Architecture
tags: [offline first, sync, conflicts]
tools: [scan_swiftdata_usage, scan_url_session_usage]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Offline First Architecture

Build offline-first features with local persistence and background sync.

## When to use this skill
- The user asks for work involving: offline first, sync, conflicts.
- You are about to change code in the Architecture area and want SwiftCode's standard workflow.

## Workflow
1. Make local storage the source of truth for the UI.
2. Queue mutations locally with ids and timestamps.
3. Sync in the background with retries and backoff.
4. Resolve conflicts with a documented policy.
5. Show sync status to users.

## Rules
- UI never blocks on network.
- Conflict policy explicit.

## Verification
- [ ] Airplane-mode edits sync later.
- [ ] Conflicts resolved deterministically.

## Avoid
- Network-first UIs with offline afterthought.
- Silent data loss on conflicts.

## Recommended SwiftCode tools
- `scan_swiftdata_usage`
- `scan_url_session_usage`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
