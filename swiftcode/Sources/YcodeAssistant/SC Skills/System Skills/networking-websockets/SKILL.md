---
name: networking-websockets
description: "Implement real-time features with URLSessionWebSocketTask and reconnection logic."
category: Networking
tags: [websocket, realtime, streaming]
tools: [scan_url_session_usage, http_get_request]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Networking Websockets

Implement real-time features with URLSessionWebSocketTask and reconnection logic.

## When to use this skill
- The user asks for work involving: websocket, realtime, streaming.
- You are about to change code in the Networking area and want SwiftCode's standard workflow.

## Workflow
1. Wrap URLSessionWebSocketTask in an actor exposing AsyncStream of messages.
2. Send pings on an interval and detect stale connections.
3. Reconnect with backoff and resubscribe.
4. Decode messages with Codable discriminated unions.
5. Cancel on scene background as appropriate.

## Rules
- Single connection owner.
- Handle message ordering explicitly.

## Verification
- [ ] Reconnect tested by dropping the network.
- [ ] No leaked tasks after cancel.

## Avoid
- Polling when websockets exist.
- Unbounded reconnect loops.

## Recommended SwiftCode tools
- `scan_url_session_usage`
- `http_get_request`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
