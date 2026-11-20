---
name: contract-testing-apis
description: "Verify client/server API contracts with recorded fixtures and schema checks."
category: Testing
tags: [contract testing, api, fixtures]
tools: [http_get_request, json_structure_validate, json_list_keys]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Contract Testing Apis

Verify client/server API contracts with recorded fixtures and schema checks.

## When to use this skill
- The user asks for work involving: contract testing, api, fixtures.
- You are about to change code in the Testing area and want SwiftCode's standard workflow.

## Workflow
1. Capture real responses for each endpoint as fixtures.
2. Decode fixtures in tests with the production models.
3. Validate required fields and types against the schema.
4. Refresh fixtures when the API version changes.
5. Fail CI on decoding errors.

## Rules
- Fixtures come from real responses.
- No secrets in fixtures.

## Verification
- [ ] All endpoints have decode tests.
- [ ] Schema drift detected.

## Avoid
- Hand-written fake JSON shapes.
- Ignoring optional fields.

## Recommended SwiftCode tools
- `http_get_request`
- `json_structure_validate`
- `json_list_keys`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
