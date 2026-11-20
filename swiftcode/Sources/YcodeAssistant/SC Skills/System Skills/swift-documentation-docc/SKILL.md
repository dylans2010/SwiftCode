---
name: swift-documentation-docc
description: "Write DocC documentation: symbol comments, articles and tutorials for Swift packages."
category: Documentation
tags: [docc, documentation, api docs]
tools: [swift_undocumented_public_api, swift_list_public_api, markdown_toc]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Swift Documentation Docc

Write DocC documentation: symbol comments, articles and tutorials for Swift packages.

## When to use this skill
- The user asks for work involving: docc, documentation, api docs.
- You are about to change code in the Documentation area and want SwiftCode's standard workflow.

## Workflow
1. List undocumented public API with swift_undocumented_public_api.
2. Write /// summaries (one sentence), Discussion, - Parameters, - Returns, - Throws.
3. Add a Documentation.docc catalog with a landing article and topic groups.
4. Include runnable code snippets that compile.
5. Build docs with swift package generate-documentation or xcodebuild docbuild.

## Rules
- Document behavior and contracts, not implementation.
- Keep examples real and tested.

## Verification
- [ ] Doc coverage of public API is 100%.
- [ ] Docs build without warnings.

## Avoid
- Restating the symbol name as the summary.
- Outdated examples.

## Recommended SwiftCode tools
- `swift_undocumented_public_api`
- `swift_list_public_api`
- `markdown_toc`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
