<!-- system-index-depends: ErrorHandling.md -->
# Error Recovery Protocols & Graceful Degradation

Technical protocols for handling model timeouts, rate limits, network disconnects, and provider failover.

---

## 1. Handling Rate Limits & 429 Errors
- Implement exponential backoff with randomized jitter.
- Failover across alternative configured API keys or providers where enabled.

---

## 2. Handling Incomplete or Truncated Responses
- If an LLM response is truncated due to `max_tokens`, prompt for continuation without repeating prior context.
- Detect broken JSON in tool calls and prompt for schema correction.
