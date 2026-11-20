---
name: async-sequence-design
description: "Design custom AsyncSequence/AsyncStream producers with backpressure and termination."
category: Concurrency
tags: [asyncstream, async sequence, streaming]
tools: [scan_task_detached, file_read]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Async Sequence Design

Design custom AsyncSequence/AsyncStream producers with backpressure and termination.

## When to use this skill
- The user asks for work involving: asyncstream, async sequence, streaming.
- You are about to change code in the Concurrency area and want SwiftCode's standard workflow.

## Workflow
1. Pick AsyncStream for push sources, custom AsyncSequence for pull.
2. Choose a buffering policy explicitly.
3. Finish the continuation on completion and onTermination cleanup.
4. Test cancellation and early termination.

## Rules
- Always finish streams.
- Single consumer unless documented.

## Verification
- [ ] Cancellation releases resources.
- [ ] Buffer policy tested.

## Avoid
- Unbounded buffers for fast producers.
- Never-finishing streams.

## Recommended SwiftCode tools
- `scan_task_detached`
- `file_read`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
