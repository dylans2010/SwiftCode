<!-- system-index-depends: CodeReviewSystemAsset.md -->
# LLM Reflection, Self-Critique & Pre-Commit Auditing

Methodology for executing internal double-pass verification and self-critique on generated code prior to committing changes.

---

## 1. The Reflection Protocol
Before applying code modifications:
1. **Self-Review Checklist:**
   - Did I preserve all existing public API signatures?
   - Did I introduce any retain cycles in closures?
   - Are all concurrency boundaries Sendable-safe?
   - Is memory allocated efficiently?
2. Correct any detected shortcomings before presenting output to the user.
