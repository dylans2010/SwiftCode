<!-- system-index-depends: Contexts.md, ContextBudgeting.md -->
# Context Optimization, Pruning & History Compaction

Architectural methods for maximizing LLM context efficiency, pruning irrelevant historical messages, and avoiding attention saturation.

---

## 1. Context Window Hygiene
- **Avoid Full-File Dumps:** Use line ranges (`file_read` with `lines: {start, end}`) for large source files.
- **Prune Tool Output Dumps:** Truncate large build logs or directory tree results after extracting key diagnostics.
- **Compacted Conversation History:** Summarize multi-turn back-and-forth into dense key facts when nearing context window boundaries.
