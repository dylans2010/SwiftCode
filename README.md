# SwiftCode

A mobile-first IDE for iPhone and iPad — write, manage, and build iOS apps directly from your device, no Mac required.

## Description

SwiftCode is a fully featured integrated development environment designed for iOS. It brings professional-grade code editing, project management, version control, and app compilation to your iPhone or iPad, removing the dependency on a Mac for iOS development.

## Overview

SwiftCode provides a complete development workflow on-device:

```
Write Code → Manage Project → Build App → Install IPA
```

From writing your first line of Swift to installing a compiled `.ipa` on your device, the entire process happens within SwiftCode.

## Core Features

### Code Editor

A syntax-highlighted code editor built for mobile, featuring intelligent autocompletion, multi-file tabbed editing, and editor logic frameworks that adapt to different file types. The editor is designed to be productive on smaller screens without sacrificing capability.

### Project Management

Full project and file management with a built-in file navigator, workspace organization, and dependency tracking. Create, rename, move, and delete files and folders without leaving the app.

### GitHub Integration

Native GitHub support for cloning repositories, committing changes, pushing and pulling branches, and viewing diffs. Manage your entire version control workflow directly from SwiftCode.

### CI Build System

Cloud-based compilation using macOS runners. Push your project and let a remote CI pipeline compile your app, sign it, and return a ready-to-install IPA — no local Mac needed.

### Local Build System

Connect to a Mac on your local network and offload compilation to it. SwiftCode discovers nearby Macs, manages the connection, sends your project files, and retrieves the compiled IPA automatically.

### Extensions System

Extend SwiftCode with custom tools and extensions. The extension management system allows you to install, configure, and manage add-ons that enhance the editor and development workflow.

### AI Integration

Built-in AI assistance for code generation, suggestions, and agent-driven development skills. Use AI to accelerate your workflow with intelligent code completions and contextual help.

## Architecture

```
SwiftCode/
├── Backend/
│   ├── CI Building/
│   ├── Local Building/
│   │   ├── Mac Helpers/
│   │   ├── Connectivity/
│   │   └── Build/
│   ├── GitHub/
│   └── Local Simulation/
│
├── Core/
│   ├── BuildSystem/
│   ├── FileSystem/
│   └── GitHub/
│
├── Views/
│   ├── Editor/
│   ├── GitHub/
│   ├── Build/
│   ├── Settings/
│   │   ├── Extension Management/
│   │   ├── Custom Tools/
│   │   └── Skills/
│   ├── AI/
│   ├── Dashboard/
│   ├── Navigator/
│   ├── Workspace/
│   └── ...
│
├── Features/
│   ├── AI/
│   └── Agent Skills/
│
├── Models/
├── Services/
├── UI/
│   ├── Styles/
│   └── Utilities/
└── Resources/
```

| Directory | Responsibility |
|-----------|---------------|
| **Backend** | Build pipelines (CI and local), GitHub API communication, and local simulation logic. |
| **Core** | Foundational systems for the build pipeline, file system operations, and GitHub integration. |
| **Views** | All SwiftUI views organized by feature — editor, build, settings, GitHub, AI, and navigation. |
| **Features** | Higher-level feature modules including AI capabilities and agent skills. |
| **Models** | Data models and types used across the application. |
| **Services** | Shared service layers for networking, persistence, and business logic. |
| **UI** | Reusable UI components, styles, and visual utilities. |

## Build Systems

SwiftCode supports two methods for compiling your projects into installable IPAs.

### CI Build

Cloud-based macOS runners handle compilation remotely. SwiftCode packages your project files, sends them to a CI pipeline, and retrieves the signed IPA once the build completes. This method requires a GitHub account and an internet connection but no additional hardware.

### Local Build

A Mac on your local network acts as the build server. SwiftCode automatically discovers available Macs via local network scanning, establishes a connection, transfers your project, and triggers a build using the Mac's Xcode installation. The compiled IPA is returned to your device for installation. This method works without an internet connection but requires a nearby Mac running Xcode.

## Requirements

- iOS 17 or later
- GitHub account (required for CI builds)
- Mac with Xcode installed (optional, for local builds only)

## Development Status

SwiftCode is actively under development. New features, editor improvements, and build system enhancements are being added continuously.

## Goals

The long-term goal of SwiftCode is to make iOS devices fully capable development environments — enabling developers to write, build, and ship apps entirely from the device they build for.

## License

*License information to be added.*
