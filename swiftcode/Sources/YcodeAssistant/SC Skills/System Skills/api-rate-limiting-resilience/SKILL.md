---
name: api-rate-limiting-resilience
description: "Make clients resilient with timeouts, retries, circuit breakers and rate-limit handling."
category: Backend
tags: [resilience, retry, rate limiting]
tools: [http_status_check, scan_url_session_usage]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Api Rate Limiting Resilience

Make clients resilient with timeouts, retries, circuit breakers and rate-limit handling.

## When to use this skill
- The user asks for work involving: resilience, retry, rate limiting.
- You are about to change code in the Backend area and want SwiftCode's standard workflow.

## Workflow
1. Set explicit timeouts.
2. Retry idempotent requests with exponential backoff + jitter.
3. Honor 429 Retry-After.
4. Fail fast with a circuit breaker after repeated failures.

## Rules
- Bound retries.
- Surface degraded state to users.

## Verification
- [ ] Fault injection tests.
- [ ] No retry storms.

## Avoid
- Infinite retries.
- Ignoring Retry-After.

## Recommended SwiftCode tools
- `http_status_check`
- `scan_url_session_usage`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
