---
name: swift-auth-oauth-device-flow
description: "Implement OAuth device authorization flow for CLI tools and macOS helpers."
category: Authentication
tags: [oauth, device flow, cli]
tools: [http_post_json, url_parse]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Swift Auth Oauth Device Flow

Implement OAuth device authorization flow for CLI tools and macOS helpers.

## When to use this skill
- The user asks for work involving: oauth, device flow, cli.
- You are about to change code in the Authentication area and want SwiftCode's standard workflow.

## Workflow
1. Request a device_code and user_code from the device authorization endpoint.
2. Show the verification URI and user code clearly.
3. Poll the token endpoint at the returned interval, honoring slow_down and authorization_pending.
4. Stop on expired_token or access_denied with clear messages.
5. Store tokens in the Keychain.

## Rules
- Respect the polling interval.
- Make cancellation possible.

## Verification
- [ ] Approval, denial and expiry paths tested.
- [ ] No busy polling.

## Avoid
- Polling faster than allowed.
- Printing tokens to the terminal.

## Recommended SwiftCode tools
- `http_post_json`
- `url_parse`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
