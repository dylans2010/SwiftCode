---
name: user-defaults-preferences
description: "Store user preferences correctly with UserDefaults/@AppStorage and typed keys."
category: Data & Persistence
tags: [userdefaults, preferences, appstorage]
tools: [scan_userdefaults_usage, swift_list_enums]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# User Defaults Preferences

Store user preferences correctly with UserDefaults/@AppStorage and typed keys.

## When to use this skill
- The user asks for work involving: userdefaults, preferences, appstorage.
- You are about to change code in the Data & Persistence area and want SwiftCode's standard workflow.

## Workflow
1. Centralize keys in a typed enum.
2. Register defaults at launch.
3. Use @AppStorage in SwiftUI.
4. Never store secrets or large data.

## Rules
- Small values only.
- Migrate renamed keys.

## Verification
- [ ] Defaults registered.
- [ ] Scan shows no secret keys.

## Avoid
- Stringly-typed keys everywhere.
- Storing tokens.

## Recommended SwiftCode tools
- `scan_userdefaults_usage`
- `swift_list_enums`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
