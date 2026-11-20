---
name: swift-auth-biometrics
description: "Gate sensitive features with Face ID / Touch ID via LocalAuthentication with graceful fallback."
category: Authentication
tags: [biometrics, faceid, touchid, LocalAuthentication]
tools: [scan_keychain_usage, info_plist_audit]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Swift Auth Biometrics

Gate sensitive features with Face ID / Touch ID via LocalAuthentication with graceful fallback.

## When to use this skill
- The user asks for work involving: biometrics, faceid, touchid, LocalAuthentication.
- You are about to change code in the Authentication area and want SwiftCode's standard workflow.

## Workflow
1. Add NSFaceIDUsageDescription to Info.plist.
2. Create an LAContext, call canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics) and branch on the error.
3. Call evaluatePolicy asynchronously and update UI on the main actor.
4. Offer passcode fallback with .deviceOwnerAuthentication when appropriate.
5. For secrets, prefer Keychain items protected with SecAccessControl(.biometryCurrentSet).

## Rules
- Biometrics confirm presence, not identity to your server.
- Handle biometryLockout and biometryNotEnrolled distinctly.

## Verification
- [ ] All LAError cases map to clear messages.
- [ ] Feature remains usable without biometrics where policy allows.

## Avoid
- Calling evaluatePolicy on every view appear.
- Storing a 'biometrics passed' boolean as the security gate.

## Recommended SwiftCode tools
- `scan_keychain_usage`
- `info_plist_audit`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
