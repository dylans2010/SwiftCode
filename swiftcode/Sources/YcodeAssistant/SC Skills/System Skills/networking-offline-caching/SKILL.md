---
name: networking-offline-caching
description: "Add offline support and caching with URLCache, ETags and local persistence."
category: Networking
tags: [offline, caching, etag, persistence]
tools: [scan_url_session_usage, http_head_request]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Networking Offline Caching

Add offline support and caching with URLCache, ETags and local persistence.

## When to use this skill
- The user asks for work involving: offline, caching, etag, persistence.
- You are about to change code in the Networking area and want SwiftCode's standard workflow.

## Workflow
1. Decide cache policy per endpoint.
2. Configure URLCache size and respect Cache-Control.
3. Use ETag/If-None-Match for revalidation.
4. Persist critical data locally (SwiftData/files) and show stale data with a badge.
5. Sync on connectivity restoration (NWPathMonitor).

## Rules
- Cached data is clearly marked stale.
- Invalidate cache on logout.

## Verification
- [ ] App usable in airplane mode for cached screens.
- [ ] Revalidation returns 304 handled.

## Avoid
- Caching authenticated responses in shared caches.
- Unbounded caches.

## Recommended SwiftCode tools
- `scan_url_session_usage`
- `http_head_request`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
