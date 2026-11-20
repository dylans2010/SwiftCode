---
name: swift-auth-jwt-handling
description: "Handle JWT access tokens safely in Swift clients: decoding claims, expiry and refresh."
category: Authentication
tags: [jwt, tokens, refresh]
tools: [jwt_decode, unix_timestamp_convert, scan_userdefaults_usage]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Swift Auth Jwt Handling

Handle JWT access tokens safely in Swift clients: decoding claims, expiry and refresh.

## When to use this skill
- The user asks for work involving: jwt, tokens, refresh.
- You are about to change code in the Authentication area and want SwiftCode's standard workflow.

## Workflow
1. Treat the JWT as opaque for authorization; decode claims only for UI hints such as expiry.
2. Read exp and refresh proactively before expiry with clock-skew tolerance.
3. Store tokens in the Keychain, never in UserDefaults.
4. Serialize refresh through an actor so only one refresh runs.
5. Clear tokens on logout and on refresh failure.

## Rules
- Never validate signatures client-side as a security decision.
- Never log tokens.

## Verification
- [ ] Expired-token path tested.
- [ ] Concurrent requests trigger one refresh.

## Avoid
- Trusting decoded roles for access control.
- Long-lived tokens without refresh.

## Recommended SwiftCode tools
- `jwt_decode`
- `unix_timestamp_convert`
- `scan_userdefaults_usage`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
