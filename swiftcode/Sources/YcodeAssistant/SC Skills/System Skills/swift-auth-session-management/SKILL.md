---
name: swift-auth-session-management
description: "Design an observable session/auth state machine (signed out, signing in, signed in, refreshing, expired) in Swift."
category: Authentication
tags: [session, auth state, refresh token, logout]
tools: [swift_list_types, scan_observable_state, scan_singletons]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Swift Auth Session Management

Design an observable session/auth state machine (signed out, signing in, signed in, refreshing, expired) in Swift.

## When to use this skill
- The user asks for work involving: session, auth state, refresh token, logout.
- You are about to change code in the Authentication area and want SwiftCode's standard workflow.

## Workflow
1. Model AuthState as an enum with associated values; keep it in an @Observable @MainActor SessionStore.
2. Centralize token refresh behind an actor so concurrent requests share one refresh.
3. Inject the session into the networking layer to attach Authorization headers.
4. On 401 trigger a single refresh then retry once; on refresh failure transition to .expired and route to login.
5. Clear Keychain, caches and in-memory state on logout.

## Rules
- One source of truth for auth state.
- Never refresh tokens in parallel.

## Verification
- [ ] Concurrent 401s cause exactly one refresh (test with async let).
- [ ] Logout removes all user data.

## Avoid
- Scattered isLoggedIn booleans.
- Retry loops without limits.

## Recommended SwiftCode tools
- `swift_list_types`
- `scan_observable_state`
- `scan_singletons`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
