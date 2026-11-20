---
name: swift-auth-sign-in-with-apple
description: "Add Sign in with Apple using AuthenticationServices, including nonce handling and credential-state checks."
category: Authentication
tags: [sign in with apple, authentication, nonce]
tools: [scan_keychain_usage, text_hash_digest, project_entitlements]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Swift Auth Sign In With Apple

Add Sign in with Apple using AuthenticationServices, including nonce handling and credential-state checks.

## When to use this skill
- The user asks for work involving: sign in with apple, authentication, nonce.
- You are about to change code in the Authentication area and want SwiftCode's standard workflow.

## Workflow
1. Add the Sign in with Apple capability/entitlement.
2. Create a random nonce, send SHA256(nonce) in the request, keep the raw nonce for the backend.
3. Use SignInWithAppleButton (SwiftUI) or ASAuthorizationController and handle success/failure.
4. Send identityToken + raw nonce to your server for verification; store the user identifier in the Keychain.
5. On launch call getCredentialState(forUserID:) and sign out on .revoked.

## Rules
- Name and email are only provided on first sign-in — persist them then.
- Never trust the identity token client-side alone.

## Verification
- [ ] Revoked credential path tested.
- [ ] First-login and returning-login paths tested.

## Avoid
- Assuming email is always present.
- Skipping nonce verification.

## Recommended SwiftCode tools
- `scan_keychain_usage`
- `text_hash_digest`
- `project_entitlements`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
