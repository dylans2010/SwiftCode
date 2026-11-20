---
name: swift-auth-oauth-pkce
description: "Implement OAuth 2.0 Authorization Code with PKCE in Swift apps using ASWebAuthenticationSession."
category: Authentication
tags: [oauth, pkce, login, ASWebAuthenticationSession]
tools: [scan_webview_usage, text_hash_digest, url_parse, http_post_json]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Swift Auth Oauth Pkce

Implement OAuth 2.0 Authorization Code with PKCE in Swift apps using ASWebAuthenticationSession.

## When to use this skill
- The user asks for work involving: oauth, pkce, login, ASWebAuthenticationSession.
- You are about to change code in the Authentication area and want SwiftCode's standard workflow.

## Workflow
1. Generate a 43-128 char code_verifier with SecRandomCopyBytes and derive code_challenge = BASE64URL(SHA256(verifier)).
2. Build the authorize URL with response_type=code, client_id, redirect_uri, scope, state and code_challenge_method=S256.
3. Present ASWebAuthenticationSession with a custom callback scheme and prefersEphemeralWebBrowserSession when appropriate.
4. Validate the returned state, exchange the code at the token endpoint with the verifier, decode tokens with Codable.
5. Persist tokens in the Keychain and schedule refresh before expiry.

## Rules
- Never embed client secrets in a mobile/desktop app.
- Always verify `state` to prevent CSRF.
- Use an embedded WKWebView for login only if the provider explicitly allows it.

## Verification
- [ ] Test PKCE challenge generation against RFC 7636 test vectors.
- [ ] Cancelled login surfaces a user-friendly message.
- [ ] Refresh works after access token expiry.

## Avoid
- Implicit grant flow.
- Logging authorization codes or tokens.

## Recommended SwiftCode tools
- `scan_webview_usage`
- `text_hash_digest`
- `url_parse`
- `http_post_json`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
