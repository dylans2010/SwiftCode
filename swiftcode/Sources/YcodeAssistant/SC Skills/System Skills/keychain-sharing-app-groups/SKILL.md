---
name: keychain-sharing-app-groups
description: "Share credentials and data between apps and extensions via keychain access groups and App Groups."
category: Security
tags: [keychain, app groups, extensions]
tools: [project_entitlements, scan_keychain_usage]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Keychain Sharing App Groups

Share credentials and data between apps and extensions via keychain access groups and App Groups.

## When to use this skill
- The user asks for work involving: keychain, app groups, extensions.
- You are about to change code in the Security area and want SwiftCode's standard workflow.

## Workflow
1. Enable App Groups and keychain sharing entitlements.
2. Use kSecAttrAccessGroup for shared items.
3. Use FileManager.containerURL for shared files.
4. Test from app and extension.

## Rules
- Share minimum data.
- Consistent group ids across targets.

## Verification
- [ ] Extension reads shared token.
- [ ] Entitlements verified.

## Avoid
- Duplicated secrets per target.
- Mismatched group identifiers.

## Recommended SwiftCode tools
- `project_entitlements`
- `scan_keychain_usage`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
