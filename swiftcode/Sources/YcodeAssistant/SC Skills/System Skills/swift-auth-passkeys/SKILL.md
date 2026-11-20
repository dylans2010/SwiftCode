---
name: swift-auth-passkeys
description: "Implement passkeys (WebAuthn) sign-in and registration with AuthenticationServices."
category: Authentication
tags: [passkeys, webauthn, authentication]
tools: [project_entitlements, http_post_json, scan_keychain_usage]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Swift Auth Passkeys

Implement passkeys (WebAuthn) sign-in and registration with AuthenticationServices.

## When to use this skill
- The user asks for work involving: passkeys, webauthn, authentication.
- You are about to change code in the Authentication area and want SwiftCode's standard workflow.

## Workflow
1. Add the associated domains entitlement (webcredentials:) and host apple-app-site-association.
2. Fetch a registration/assertion challenge from your server.
3. Use ASAuthorizationPlatformPublicKeyCredentialProvider to create registration or assertion requests.
4. Present ASAuthorizationController and send the credential (clientDataJSON, attestation/assertion) to the server for verification.
5. Offer passkey autofill with performAutoFillAssistedRequests where appropriate.

## Rules
- The server verifies everything; the client never trusts itself.
- Keep a fallback sign-in path for devices without passkeys.

## Verification
- [ ] Registration and sign-in tested on device.
- [ ] Cancelled requests handled without errors shown as failures.

## Avoid
- Reusing challenges.
- Storing credential IDs as secrets.

## Recommended SwiftCode tools
- `project_entitlements`
- `http_post_json`
- `scan_keychain_usage`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
