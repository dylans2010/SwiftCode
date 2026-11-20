---
name: changelog-release-notes
description: "Maintain CHANGELOG.md and write user-facing release notes from git history."
category: Documentation
tags: [changelog, release notes, semver]
tools: [git_tag_list, git_log_search_messages, git_changed_files_since, semver_bump]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Changelog Release Notes

Maintain CHANGELOG.md and write user-facing release notes from git history.

## When to use this skill
- The user asks for work involving: changelog, release notes, semver.
- You are about to change code in the Documentation area and want SwiftCode's standard workflow.

## Workflow
1. Find the last tag with git_tag_list.
2. Collect commits since the tag and group into Added/Changed/Fixed/Removed/Security.
3. Rewrite entries in user language with impact.
4. Bump the version with semver_bump according to changes.
5. Link issues/PRs and date the release.

## Rules
- Follow Keep a Changelog format.
- Breaking changes listed first.

## Verification
- [ ] Every user-visible change appears.
- [ ] Version matches semver rules.

## Avoid
- Dumping raw commit logs.
- Omitting breaking changes.

## Recommended SwiftCode tools
- `git_tag_list`
- `git_log_search_messages`
- `git_changed_files_since`
- `semver_bump`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
