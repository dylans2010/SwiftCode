---
name: api-documentation-openapi
description: "Document HTTP APIs with OpenAPI and keep Swift clients in sync."
category: Documentation
tags: [openapi, rest, api docs]
tools: [json_to_swift_codable, http_get_request, json_list_keys]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Api Documentation Openapi

Document HTTP APIs with OpenAPI and keep Swift clients in sync.

## When to use this skill
- The user asks for work involving: openapi, rest, api docs.
- You are about to change code in the Documentation area and want SwiftCode's standard workflow.

## Workflow
1. Capture endpoints, methods, parameters, bodies, responses and errors.
2. Write openapi.yaml with schemas and examples.
3. Generate or hand-write Codable models; verify against real responses with http_get_request.
4. Document auth schemes and rate limits.
5. Validate the spec with a linter.

## Rules
- Examples must be real responses.
- Version the API.

## Verification
- [ ] Client decodes every documented response.
- [ ] Spec validates.

## Avoid
- Undocumented error shapes.
- Drift between spec and server.

## Recommended SwiftCode tools
- `json_to_swift_codable`
- `http_get_request`
- `json_list_keys`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
