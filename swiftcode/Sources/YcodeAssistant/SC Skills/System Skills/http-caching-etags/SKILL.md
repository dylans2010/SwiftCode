---
name: http-caching-etags
description: "Use HTTP caching, ETags and conditional requests to save bandwidth and latency."
category: Networking
tags: [caching, etag, http]
tools: [http_head_request, scan_url_session_usage]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Http Caching Etags

Use HTTP caching, ETags and conditional requests to save bandwidth and latency.

## When to use this skill
- The user asks for work involving: caching, etag, http.
- You are about to change code in the Networking area and want SwiftCode's standard workflow.

## Workflow
1. Inspect server Cache-Control and ETag headers with http_head_request.
2. Configure URLCache capacity and request cache policy.
3. Send If-None-Match/If-Modified-Since and handle 304.
4. Invalidate caches on logout or data mutation.
5. Measure hit rates.

## Rules
- Never cache private data in shared caches.
- Respect server directives.

## Verification
- [ ] 304 path tested.
- [ ] Cache cleared on logout.

## Avoid
- Caching POST responses.
- Ignoring Vary headers.

## Recommended SwiftCode tools
- `http_head_request`
- `scan_url_session_usage`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
