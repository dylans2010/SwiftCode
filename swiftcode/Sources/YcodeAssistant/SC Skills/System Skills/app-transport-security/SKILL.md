---
name: app-transport-security
description: "Configure App Transport Security and TLS correctly."
category: Security
tags: [ats, tls, https]
tools: [scan_insecure_http_urls, info_plist_audit]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# App Transport Security

Configure App Transport Security and TLS correctly.

## When to use this skill
- The user asks for work involving: ats, tls, https.
- You are about to change code in the Security area and want SwiftCode's standard workflow.

## Workflow
1. Find http:// URLs and ATS exceptions.
2. Move endpoints to HTTPS.
3. Scope any unavoidable exception to specific domains with justification.
4. Consider certificate pinning only with a rotation plan.
5. Test against the production endpoints.

## Rules
- No NSAllowsArbitraryLoads.
- Exceptions documented.

## Verification
- [ ] No insecure URLs in scope.
- [ ] ATS exceptions minimal.

## Avoid
- Global ATS disable.
- Pinning without backup pins.

## Recommended SwiftCode tools
- `scan_insecure_http_urls`
- `info_plist_audit`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
