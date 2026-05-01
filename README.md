# SwiftCode IDE

## Overview
SwiftCode is a mobile-first IDE for iOS development on iPhone and iPad. It enables writing, managing, building, and installing Swift apps directly on the device.

## Tech Stack
- **Language**: Swift (100% Native)
- **UI Framework**: SwiftUI
- **Architecture**: MVVM with ObservableObject/EnvironmentObject

## Key Features
- On-device code editor with advanced syntax highlighting
- Code formatting (auto-indent, whitespace normalization, import sorting)
- Project management with file tree navigation
- Dual build systems (CI via GitHub Actions, Local via Bonjour)
- GitHub integration (clone, commit, push/pull, branches, issues, PRs)
- AI Assistant with 95+ built-in tools across 15 categories
- 35+ preset agent skills with deep workflow guidance
- Extensions, themes, and custom tool builder
- Command palette, minimap, search/replace

## Project Structure
- `SwiftCode/Views/Editor/` - Code editor, minimap, line numbers
- `SwiftCode/Views/Settings/Skills/` - Skills browser with search and tag filtering
- `SwiftCode/Services/SyntaxHighlighter.swift` - Multi-language syntax highlighting with 20 token categories
- `SwiftCode/Services/CodeFormatter.swift` - Swift/JSON code formatter
- `SwiftCode/Services/ToolbarSettings.swift` - Editor toolbar state
- `SwiftCode/Models/AgentTool.swift` - 95+ tools in 15 categories
- `SwiftCode/Features/Agent Skills/PresetAgentSkills.swift` - 35 preset skills

## Tool Categories
File System, Code Analysis, Code Generation, Text & Strings, Utilities, Project, Dependency, Build, Search, Refactoring, Formatting, Documentation, Testing, Performance, Security

## Syntax Highlighting Colors
- Keywords (pink-red), Types (cyan), Functions (green), Strings (coral-red)
- Comments (green), Numbers (purple), Attributes (orange)
- Property Wrappers (purple), SwiftUI Views (sky blue), Modifiers (light blue)
- Import Modules (magenta), Control Flow (pink), Access Control (pink)
- Variable Declarations (pink), Preprocessor (orange), Interpolation (green)
