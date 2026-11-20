<!-- system-index-depends: ResponseFormatting.md -->
# Prompt Fine-Tuning Guidelines & System Instruction Formatting

Best practices for structuring instructions, reinforcing behavioral constraints, and optimizing LLM steerability in developer tools.

---

## 1. Instruction Framing Rules
- **Direct & Unambiguous:** State requirements directly without conversational filler.
- **Negative Constraints with Positive Alternatives:** When forbidding an action (e.g., "Do not use terminal cat"), always state the sanctioned alternative ("Use native file_read").
- **Structural Fencing:** Use Markdown headers, tables, and fenced code blocks to delimit distinct logical instruction sections.
