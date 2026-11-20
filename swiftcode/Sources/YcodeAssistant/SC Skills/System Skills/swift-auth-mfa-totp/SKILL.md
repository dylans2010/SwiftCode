---
name: swift-auth-mfa-totp
description: "Add TOTP-based multi-factor authentication support using CryptoKit."
category: Authentication
tags: [mfa, totp, 2fa]
tools: [text_hash_digest, unix_timestamp_convert]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Swift Auth Mfa Totp

Add TOTP-based multi-factor authentication support using CryptoKit.

## When to use this skill
- The user asks for work involving: mfa, totp, 2fa.
- You are about to change code in the Authentication area and want SwiftCode's standard workflow.

## Workflow
1. Parse otpauth:// URIs (secret, digits, period, algorithm).
2. Decode the Base32 secret and compute HMAC with CryptoKit over the time counter.
3. Apply dynamic truncation to produce the code.
4. Store secrets in the Keychain with device-only accessibility.
5. Test against RFC 6238 test vectors.

## Rules
- Secrets never leave the Keychain unencrypted.
- Account for clock drift by accepting adjacent windows server-side.

## Verification
- [ ] RFC 6238 vectors pass.
- [ ] Codes match a reference authenticator.

## Avoid
- Storing secrets in plain files.
- Logging codes.

## Recommended SwiftCode tools
- `text_hash_digest`
- `unix_timestamp_convert`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
