---
name: swift-auth-keychain-tokens
description: "Store, read, refresh and delete auth tokens in Swift using the Keychain with correct accessibility classes."
category: Authentication
tags: [auth, keychain, tokens, security]
tools: [scan_keychain_usage, scan_hardcoded_secrets, scan_userdefaults_usage, file_read]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Swift Auth Keychain Tokens

Store, read, refresh and delete auth tokens in Swift using the Keychain with correct accessibility classes.

## When to use this skill
- The user asks for work involving: auth, keychain, tokens, security.
- You are about to change code in the Authentication area and want SwiftCode's standard workflow.

## Workflow
1. Find existing token storage with scan_userdefaults_usage and scan_keychain_usage.
2. Wrap SecItemAdd/SecItemCopyMatching/SecItemUpdate/SecItemDelete in a small TokenStore type with typed errors.
3. Use kSecClassGenericPassword with service + account keys and kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly unless the user needs sync.
4. Expose async load/save/delete APIs and map OSStatus to descriptive errors.
5. Migrate any UserDefaults-stored token into the Keychain and delete the old value.

## Rules
- Never store secrets in UserDefaults, plist files, logs or source.
- Treat errSecItemNotFound as 'no token', not as a failure.
- Keep the access group explicit when sharing with extensions.

## Verification
- [ ] Unit test save→load→delete round trip on a real Keychain (simulator/macOS).
- [ ] scan_hardcoded_secrets returns no findings.
- [ ] Logs never print token values.

## Avoid
- Rolling your own encryption for tokens.
- Using kSecAttrAccessibleAlways (deprecated).

## Recommended SwiftCode tools
- `scan_keychain_usage`
- `scan_hardcoded_secrets`
- `scan_userdefaults_usage`
- `file_read`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
