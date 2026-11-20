---
name: release-process
description: "Ship releases with versioning, changelogs, tags and archives."
category: Build & Tooling
tags: [release, versioning, archive]
tools: [git_describe_version, semver_bump, git_tag_list]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Release Process

Ship releases with versioning, changelogs, tags and archives.

## When to use this skill
- The user asks for work involving: release, versioning, archive.
- You are about to change code in the Build & Tooling area and want SwiftCode's standard workflow.

## Workflow
1. Decide the version with semver_bump.
2. Update version numbers and CHANGELOG.
3. Tag and push.
4. Archive, sign and verify the artifact.

## Rules
- Release from a clean tree.
- Reproducible builds.

## Verification
- [ ] Artifact signature verified.
- [ ] Tag matches version.

## Avoid
- Releasing from dirty trees.
- Skipping changelog.

## Recommended SwiftCode tools
- `git_describe_version`
- `semver_bump`
- `git_tag_list`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
