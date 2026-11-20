---
name: code-signing-provisioning
description: "Resolve code signing and provisioning issues for Apple platforms."
category: Build & Tooling
tags: [code signing, provisioning, certificates]
tools: [codesign_identities, codesign_inspect, project_entitlements]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Code Signing Provisioning

Resolve code signing and provisioning issues for Apple platforms.

## When to use this skill
- The user asks for work involving: code signing, provisioning, certificates.
- You are about to change code in the Build & Tooling area and want SwiftCode's standard workflow.

## Workflow
1. List identities with codesign_identities.
2. Inspect the built product with codesign_inspect.
3. Compare entitlements in the profile vs the app.
4. Use automatic signing for development, manual for CI with explicit profiles.
5. Re-sign and verify with codesign --verify.

## Rules
- Never commit private keys or p12 files.
- Team ID consistent across targets.

## Verification
- [ ] App launches on device.
- [ ] codesign verify passes.

## Avoid
- Disabling signing to work around errors.
- Mixing teams.

## Recommended SwiftCode tools
- `codesign_identities`
- `codesign_inspect`
- `project_entitlements`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
