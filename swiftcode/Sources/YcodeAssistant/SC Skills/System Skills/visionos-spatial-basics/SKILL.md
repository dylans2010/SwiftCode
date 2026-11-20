---
name: visionos-spatial-basics
description: "Build visionOS apps with windows, volumes and immersive spaces using SwiftUI and RealityKit."
category: Platform
tags: [visionos, spatial, realitykit]
tools: [swift_list_swiftui_views, scan_view_lifecycle_tasks]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Visionos Spatial Basics

Build visionOS apps with windows, volumes and immersive spaces using SwiftUI and RealityKit.

## When to use this skill
- The user asks for work involving: visionos, spatial, realitykit.
- You are about to change code in the Platform area and want SwiftCode's standard workflow.

## Workflow
1. Start with a window-based SwiftUI experience.
2. Add volumes for 3D content via RealityView.
3. Use ImmersiveSpace only when needed.
4. Design for gaze and pinch with hover effects.
5. Test comfort and performance.

## Rules
- Respect user space and comfort.
- Ornaments for controls.

## Verification
- [ ] Runs in simulator at target fps.
- [ ] Hover effects on interactive elements.

## Avoid
- Porting iPad UI unchanged.
- Forcing immersion.

## Recommended SwiftCode tools
- `swift_list_swiftui_views`
- `scan_view_lifecycle_tasks`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
