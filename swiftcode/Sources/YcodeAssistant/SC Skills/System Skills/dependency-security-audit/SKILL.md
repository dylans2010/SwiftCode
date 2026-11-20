---
name: dependency-security-audit
description: "Audit third-party dependencies for vulnerabilities, licenses and maintenance."
category: Security
tags: [dependencies, supply chain, licenses]
tools: [swiftpm_dependency_tree, github_repository_info, swiftpm_describe_package]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Dependency Security Audit

Audit third-party dependencies for vulnerabilities, licenses and maintenance.

## When to use this skill
- The user asks for work involving: dependencies, supply chain, licenses.
- You are about to change code in the Security area and want SwiftCode's standard workflow.

## Workflow
1. List dependencies with swiftpm_dependency_tree.
2. Check each repo's activity, license and releases with github_repository_info.
3. Check advisories for known CVEs.
4. Remove unused dependencies.
5. Pin to released versions.

## Rules
- Prefer fewer, well-maintained deps.
- License compatible with distribution.

## Verification
- [ ] Report lists every dependency with status.
- [ ] No branch-pinned deps.

## Avoid
- Adding deps for trivial helpers.
- Ignoring license terms.

## Recommended SwiftCode tools
- `swiftpm_dependency_tree`
- `github_repository_info`
- `swiftpm_describe_package`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
