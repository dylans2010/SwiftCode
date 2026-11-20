---
name: file-uploads-downloads
description: "Handle large uploads and downloads with progress, resume and background sessions."
category: Networking
tags: [uploads, downloads, background url session]
tools: [scan_url_session_usage, http_head_request]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# File Uploads Downloads

Handle large uploads and downloads with progress, resume and background sessions.

## When to use this skill
- The user asks for work involving: uploads, downloads, background url session.
- You are about to change code in the Networking area and want SwiftCode's standard workflow.

## Workflow
1. Use upload/download tasks instead of data tasks for large payloads.
2. Report progress via delegates or async bytes.
3. Use background URLSession configurations for transfers that outlive the app.
4. Support resume data for interrupted downloads.
5. Validate checksums after download.

## Rules
- Write to temporary files then move atomically.
- Clean up partial files.

## Verification
- [ ] Interrupted transfer resumes.
- [ ] Checksums verified.

## Avoid
- Loading whole files into memory.
- Ignoring background session events.

## Recommended SwiftCode tools
- `scan_url_session_usage`
- `http_head_request`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
