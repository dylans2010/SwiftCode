Create a fully professional README.md for the SwiftCode repository.

The README must clearly explain what SwiftCode is, its purpose, features, architecture, and build systems. Use clean Markdown formatting with proper headings, sections, and code blocks. The README should look similar in quality to professional open source projects on GitHub.

Include the following sections:
	1.	Project Title
SwiftCode
	2.	Description
Explain that SwiftCode is a mobile first IDE designed for iPhone and iPad that allows users to write, manage, and build iOS apps directly from their device without requiring a Mac.
	3.	Overview
Describe the workflow of SwiftCode:
Write code → manage project → build app → install IPA.
	4.	Core Features
Create subsections describing the major systems:

Code Editor
Project Management
GitHub Integration
CI Build System
Local Build System
Extensions System
AI Integration

Explain the capabilities of each system in a professional way.
	5.	Architecture
Include a repository structure diagram such as:

SwiftCode
├ Backend
│ ├ CI Building
│ ├ Local Building
│ │ ├ Mac Helpers
│ │ ├ Connectivity
│ │ └ Build
│
├ Views
│ ├ GitHub
│ ├ Build
│ ├ Settings
│ └ Editor
│
├ Features
│ └ Extensions

Explain what each major directory is responsible for.
	6.	Build Systems
Describe the two build methods supported by SwiftCode:

CI Build
Explain that cloud macOS runners compile the app.

Local Build
Explain that a nearby Mac on the local network can compile the app and return the IPA.
	7.	Requirements
List requirements such as:

iOS 16 or later
GitHub account for CI builds
Optional Mac with Xcode for Local Build
	8.	Development Status
Explain that SwiftCode is actively under development and continuously expanding its capabilities.
	9.	Goals
Explain the long term goal of making iOS devices capable development environments.
	10.	License Section
Add a placeholder section for the license.

The README must be clean, professional, and formatted with proper Markdown headings (#, ##, ###). Avoid unnecessary filler text and keep explanations clear and concise.