<!-- system-index-depends: ExecutionPlans.md, AgentMode.md -->
# Multi-Turn Planning Strategy & Task Graph Decomposition

Strategies for managing complex, long-running engineering initiatives across multiple conversational turns and tool invocations.

---

## 1. Task Graph Formulation
Complex features must be structured into a Directed Acyclic Graph (DAG) of discrete tasks:
- **Phase 1: Exploration & Discovery:** Map existing types, protocols, and caller sites.
- **Phase 2: Foundation & Data Layer:** Define models, schemas, and persistence repositories.
- **Phase 3: Business Logic:** Implement use cases, services, and state managers.
- **Phase 4: UI & Presentation:** Build views and wire into navigation.
- **Phase 5: Verification & Hardening:** Run builds, execute unit tests, and profile memory.

---

## 2. Checkpointing & Progress Tracking
- Use `create_artifact` to store long-lived plans.
- Update plan checklists as tasks transition from pending to completed.
- Preserve task state across conversational compaction rounds.
