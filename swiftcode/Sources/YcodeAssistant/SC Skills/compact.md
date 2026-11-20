# /compact — Conversation Compaction & Memory Optimization Specification

The `/compact` slash command performs intelligent, hierarchical conversation compaction. As conversations grow over prolonged coding sessions, context tokens become exhausted, increasing inference latency and risking context window truncation. `/compact` condenses prior dialogue while preserving critical architectural decisions, file changes, unsolved errors, and active goals.

---

## 1. Syntax & Invocation

```text
/compact [focus-instructions]
```

### Examples
- `/compact`
- `/compact focus on open compiler errors and changed swift files`
- `/compact summarize everything prior to the networking rewrite`

---

## 2. Operational Rules

1. **Context Window Safety**: Compaction must reduce the conversation token footprint by at least 50% while preserving:
   - High-level project objectives and current sub-goals.
   - List of all files created, modified, or deleted during the session.
   - Key architectural decisions, selected design tokens, or framework constraints.
   - Unresolved bugs, pending action items, and verification requirements.
2. **Deterministic Retention**: Never discard active user specifications or unverified plan steps.
3. **Engine Integration**: Invokes `AssistConversationCompactor` and `AssistContextEngine` to compute token pressures and generate the structured condensation.
4. **Transparent Audit**: Replaces older message turns with a synthesized `System` or `Context Summary` entry and logs the compaction metrics (before/after token estimates, message count reduction).

---

## 3. Tool Calling Patterns & Internal Architecture

When `/compact` executes:
1. `SlashCommandExecutionEngine.shared` delegates to `AssistConversationCompactor.shared.compactCurrentSession(...)`.
2. `AssistContextEngine` analyzes all messages in `AssistManager.shared.messages`.
3. P2 sections (verbose tool inputs, intermediate logs, file read dumps) are aggressively summarized.
4. P1 sections (tool execution results) are contracted to concise 1-line outcomes.
5. P0 sections (active objective, latest user prompt, pending diffs) remain intact.
6. The compacted history replaces the message stream, and `AssistConversationHistory.shared` is updated on disk.

---

## 4. Behavior Specifications

1. **Token Estimation**: Compares pre-compaction token count with post-compaction token count.
2. **Status Notification**: Reports a clear summary bubble to the user:
   - "Conversation compacted: Reduced from 48,200 tokens to 11,400 tokens (-76%). 24 older turns summarized into structured context."
3. **Zero Context Loss**: The agent's next turn continues seamlessly with full awareness of all earlier work.
