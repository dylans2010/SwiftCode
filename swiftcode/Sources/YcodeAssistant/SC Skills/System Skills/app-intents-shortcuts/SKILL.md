---
name: app-intents-shortcuts
description: "Expose app functionality to Shortcuts, Siri and Spotlight with App Intents."
category: Platform
tags: [app intents, shortcuts, siri]
tools: [swift_list_structs, file_read]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# App Intents Shortcuts

Expose app functionality to Shortcuts, Siri and Spotlight with App Intents.

## When to use this skill
- The user asks for work involving: app intents, shortcuts, siri.
- You are about to change code in the Platform area and want SwiftCode's standard workflow.

## Workflow
1. Identify top user actions.
2. Implement AppIntent structs with parameters and perform().
3. Provide AppShortcutsProvider phrases.
4. Create AppEntity for domain objects.
5. Test in Shortcuts app.

## Rules
- Intents are fast and side-effect clear.
- Localize phrases.

## Verification
- [ ] Shortcuts run end-to-end.
- [ ] Errors show friendly dialogs.

## Avoid
- Exposing destructive actions without confirmation.
- Slow perform().

## Recommended SwiftCode tools
- `swift_list_structs`
- `file_read`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
