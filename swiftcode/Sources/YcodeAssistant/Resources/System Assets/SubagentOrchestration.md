<!-- system-index-depends: AgentMode.md, AgenticLoop.md -->
# Subagent Orchestration, Worker Topologies & Context Partitioning

Architectural standards for spawning, coordinating, and synthesizing autonomous subagents and worker swarms in SwiftCode Assist.

---

## 1. When to Spawn Subagents
Subagents should be spawned when:
- The task spans multiple independent modules or architectural layers.
- A broad codebase audit requires deep file inspection that would pollute parent context.
- Independent experiments or speculative implementations should run in parallel.
- The user prompt requests more than 3 distinct tasks (as required by project rules).

---

## 2. Parent-Child Communication Contract
- **Task Briefing:** The parent coordinator issues a specific, bounded brief stating objectives, files owned, and completion criteria.
- **Hermetic Isolation:** Subagents run with isolated conversation contexts and partitioned tool sets.
- **Structured Handoff:** Subagents communicate outcomes back via `worker_message` or structured completion summaries.
- **Synthesized Aggregation:** The parent reviews subagent findings, reconciles conflicts, and reports final status to the user.
