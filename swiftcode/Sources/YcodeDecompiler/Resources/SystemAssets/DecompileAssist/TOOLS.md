# Tools — Decompile Assist Tool Catalog

You can call the following tools. All return JSON. Read `ok`, `error`,
`truncated`, and `provenance` fields before relying on output.

## Binary inspection

- `inspect_binary` — summary of the loaded image and analysis counts.
- `get_binary_metadata` — identity, hash, UUID, versions.
- `list_binary_architectures` — slices of a universal binary.
- `inspect_binary_slice` — one slice's descriptor.
- `inspect_binary_sections` / `inspect_binary_segments` — memory layout.
- `get_entry_point` — entry address and containing function.
- `inspect_code_signature`, `inspect_entitlements`, `inspect_binary_dependencies`.

## Functions

- `list_functions` — paginated (`offset`, `limit`, `name_contains`, `kind`).
- `inspect_function` — full metadata for one function.
- `get_function_pseudocode` — C-like pseudocode; **decompiles on demand**
  (may take time on first call; errors if no backend supports the slice).
- `get_function_assembly` — instruction listing (disassembles on demand).
- `get_function_signature` — name/params/returns/locals.
- `get_function_references`, `get_function_callers`, `get_function_callees`.
- `compare_functions` — side-by-side comparison of two functions.
- `inspect_basic_block` — CFG block containing an address.

## Symbols / imports / exports

- `search_symbols`, `inspect_symbol`, `demangle_symbol` (uses the Swift
  demangler when available).
- `list_imports`, `list_exports`, `inspect_import`, `inspect_export`.

## Strings

- `search_strings` — substring search over extracted strings.
- `inspect_string` — one string by address.
- `inspect_string_references` — code locations referencing a string.
- `get_string_context` — neighboring strings + referencing functions.

## Analysis graphs & data

- `get_control_flow_graph` — basic blocks + edges for a function.
- `get_call_graph` — call edges globally or neighborhood around an address.
- `get_cross_references` — filter by address, kind, direction.
- `get_variable_information`, `get_type_information`.
- `search_binary` — raw byte-pattern search (hex or text, bounded).
- `navigate_to_address` — resolve an address to function/section/symbol.
- `inspect_memory_region` — segment info + bounded hex dump at an address.

## Assistant analysis (deterministic, unverified)

- `explain_function`, `explain_instruction`, `explain_binary`,
  `summarize_binary`, `suggest_function_name`, `suggest_variable_names`,
  `identify_function_purpose`, `compare_function_behavior`,
  `generate_function_documentation`, `analyze_suspicious_patterns`.

These compose analysis text from real data locally — fast, no model
round-trip. Output is labeled with `provenance: aiSuggestion`.

## Annotations (require `approved: true`)

- `rename_symbol`, `rename_function`, `add_analysis_comment`,
  `annotate_function`, `create_user_label`, `save_analysis_finding`.

Only call these after the user explicitly requests the change. Without
`approved: true` they return `approval_required`.

## Efficiency rules

- Paginate: default limits are 100–200; raise `limit` only when needed.
- `get_function_pseudocode`/`get_function_assembly` trigger backend work —
  don't call them speculatively for many functions at once.
- Cache mentally: if you already fetched a function's pseudocode this turn,
  reuse it rather than re-calling.
