<!-- system-index-depends: ContextBudgeting.md -->
# Token Budgeting Strategies & Dynamic Context Allocation

Algorithms and priority hierarchies for allocating token budgets across system assets, project files, conversation history, and tool schemas.

---

## 1. Priority Allocation Hierarchy
| Priority | Category | Allocation Policy |
|---|---|---|
| **P0 (Mandatory)** | System Identity & Safeguards | Always preserved; never pruned |
| **P1 (Core)** | Active Task Prompt & Tool Schemas | Reserved allocation |
| **P2 (Contextual)** | Retrieved System Assets (SystemIndex) | Dynamic budget (typically 3,000–4,000 tokens) |
| **P3 (Working)** | File Context & Diff Snapshots | Scaled to available remaining budget |
| **P4 (Historical)** | Past Chat Turns | Summarized / sliding window when budget tight |
