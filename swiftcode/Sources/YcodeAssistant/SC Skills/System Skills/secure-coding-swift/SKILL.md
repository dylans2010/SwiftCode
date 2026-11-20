---
name: secure-coding-swift
description: "Apply secure coding practices: input validation, secrets, crypto and transport security."
category: Security
tags: [security, secure coding, owasp]
tools: [scan_hardcoded_secrets, scan_insecure_http_urls, scan_weak_crypto, scan_private_key_material, scan_insecure_random]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Secure Coding Swift

Apply secure coding practices: input validation, secrets, crypto and transport security.

## When to use this skill
- The user asks for work involving: security, secure coding, owasp.
- You are about to change code in the Security area and want SwiftCode's standard workflow.

## Workflow
1. Run all security scans on the target path.
2. Validate and bound all external input.
3. Use CryptoKit (AES-GCM, ChaChaPoly, SHA256, Curve25519) for cryptography.
4. Enforce HTTPS/ATS; pin only with rotation plan.
5. Remove secrets from source and rotate exposed ones.

## Rules
- Least privilege for entitlements.
- Fail closed.

## Verification
- [ ] Security scans clean in touched code.
- [ ] No secrets in git history for new commits.

## Avoid
- Custom crypto.
- Disabling ATS globally.

## Recommended SwiftCode tools
- `scan_hardcoded_secrets`
- `scan_insecure_http_urls`
- `scan_weak_crypto`
- `scan_private_key_material`
- `scan_insecure_random`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
