---
name: llm-integration-swift
description: "Integrate LLM APIs into Swift apps with streaming, tool calls and error handling."
category: AI & Agents
tags: [llm, openai, streaming]
tools: [http_post_json, scan_url_session_usage, scan_hardcoded_secrets]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Llm Integration Swift

Integrate LLM APIs into Swift apps with streaming, tool calls and error handling.

## When to use this skill
- The user asks for work involving: llm, openai, streaming.
- You are about to change code in the AI & Agents area and want SwiftCode's standard workflow.

## Workflow
1. Wrap the provider API in a protocol.
2. Stream responses with URLSession.bytes and parse SSE.
3. Support tool/function calls with JSON schemas.
4. Handle rate limits and timeouts.

## Rules
- API keys in Keychain, not code.
- Cancel streams with tasks.

## Verification
- [ ] Streaming tested with a real endpoint.
- [ ] Errors user friendly.

## Avoid
- Blocking UI while waiting.
- Hardcoded keys.

## Recommended SwiftCode tools
- `http_post_json`
- `scan_url_session_usage`
- `scan_hardcoded_secrets`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
