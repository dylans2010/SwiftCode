# SwiftCode

An AI-powered iOS IDE built with SwiftUI for iOS/iPadOS development.

## Tech Stack
- **Language**: Swift
- **UI Framework**: SwiftUI
- **Architecture**: MVVM / Service-oriented
- **AI Integration**: OpenRouter API (multiple LLMs)
- **Storage**: UserDefaults, FileManager, Keychain

## Project Structure
- `SwiftCode/Models/` - Data models (Project, FileNode, AgentMode, etc.)
- `SwiftCode/Services/` - Business logic (ProjectManager, OpenRouterService, etc.)
- `SwiftCode/Views/` - UI layer organized by feature (AI, Workspace, Editor, Dashboard, etc.)
- `SwiftCode/Features/AI/` - Advanced AI agent interface (AgentInterfaceView, AgentController)

## Key Architecture Notes
- **AI Assistant Flow**: `AIAssistantView` is the main chat interface. When the user selects the "Agent" tab, it opens `AgentInterfaceView` as a full-screen cover (not inline mode switching).
- `AgentInterfaceView` uses `AgentController.shared` (singleton) for persistent agent execution state.
- `AIAssistantView` handles other modes (Generate, Modify, Refactor, Debug) inline.
