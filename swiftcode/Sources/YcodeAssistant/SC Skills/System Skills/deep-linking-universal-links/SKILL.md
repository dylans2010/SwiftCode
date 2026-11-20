---
name: deep-linking-universal-links
description: "Implement custom URL schemes and universal links with routing."
category: Platform
tags: [deep links, universal links, routing]
tools: [project_entitlements, url_parse, swift_list_enums]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Deep Linking Universal Links

Implement custom URL schemes and universal links with routing.

## When to use this skill
- The user asks for work involving: deep links, universal links, routing.
- You are about to change code in the Platform area and want SwiftCode's standard workflow.

## Workflow
1. Define a Route enum and URL parser.
2. Add associated domains and apple-app-site-association.
3. Handle onOpenURL and NSUserActivity.
4. Test all routes with xcrun simctl openurl.

## Rules
- Validate all URL input.
- Unknown links go somewhere sensible.

## Verification
- [ ] Every route opens correctly.
- [ ] Malformed links handled.

## Avoid
- Trusting URL parameters.
- Crashing on unknown paths.

## Recommended SwiftCode tools
- `project_entitlements`
- `url_parse`
- `swift_list_enums`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
