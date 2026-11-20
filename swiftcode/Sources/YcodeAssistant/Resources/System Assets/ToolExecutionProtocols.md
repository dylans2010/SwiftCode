<!-- system-index-depends: AvailableTools.md, CallTool.md -->
# Tool Execution Protocols, Schema Validation & Atomic Rollback

Engineering contracts for dispatching, validating parameters, executing, and handling failures across Assist native tools.

---

## 1. Schema Validation & Argument Checking
Before any tool execution:
- Tool parameters are validated against JSON Schema definitions.
- Required parameters must be present and non-empty.
- Path arguments are sanitized against directory traversal attacks.

---

## 2. Structured Output Envelope
Every tool returns a structured JSON payload:
```json
{
  "success": true,
  "output": "Replaced 1 occurrence of target in File.swift",
  "data": {
    "path": "Sources/File.swift",
    "linesChanged": 4,
    "diff": "@@ -12,4 +12,4 @@"
  },
  "error": null
}
```

---

## 3. Idempotency & Conflict Handling
- File mutations must re-read disk state to ensure the target block has not changed since the last inspection.
- When an edit detects a conflict or missing pattern, the operation fails cleanly without corrupting the file.
