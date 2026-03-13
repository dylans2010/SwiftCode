import Foundation

// MARK: - Tool Parameter

struct AgentToolParameter {
    let name: String
    let type: String         // "string", "number", "boolean"
    let description: String
    let required: Bool
    let defaultValue: String?

    init(
        name: String,
        type: String = "string",
        description: String,
        required: Bool = true,
        defaultValue: String? = nil
    ) {
        self.name = name
        self.type = type
        self.description = description
        self.required = required
        self.defaultValue = defaultValue
    }
}

// MARK: - Tool Category

enum AgentToolCategory: String, CaseIterable {
    case fileSystem    = "File System"
    case codeAnalysis  = "Code Analysis"
    case codeGen       = "Code Generation"
    case textUtils     = "Text & Strings"
    case utilities     = "Utilities"
    case project       = "Project"
    case dependency    = "Dependency"
    case build         = "Build"
    case search        = "Search"
    case refactoring   = "Refactoring"
    case formatting    = "Formatting"
    case documentation = "Documentation"
    case testing       = "Testing"
    case performance   = "Performance"
    case security      = "Security"

    var icon: String {
        switch self {
        case .fileSystem:     return "folder.fill"
        case .codeAnalysis:   return "magnifyingglass.circle.fill"
        case .codeGen:        return "wand.and.stars"
        case .textUtils:      return "textformat"
        case .utilities:      return "wrench.and.screwdriver.fill"
        case .project:        return "cube.fill"
        case .dependency:     return "shippingbox.fill"
        case .build:          return "hammer.fill"
        case .search:         return "magnifyingglass"
        case .refactoring:    return "arrow.triangle.2.circlepath"
        case .formatting:     return "text.alignleft"
        case .documentation:  return "doc.text.magnifyingglass"
        case .testing:        return "checkmark.shield.fill"
        case .performance:    return "gauge.with.dots.needle.33percent"
        case .security:       return "lock.shield.fill"
        }
    }
}

// MARK: - Agent Tool

struct AgentTool: Identifiable {
    let id: String               // used as tool name in JSON calls
    let displayName: String
    let description: String
    let parameters: [AgentToolParameter]
    let category: AgentToolCategory

    /// Formatted description for the AI system prompt
    var promptDescription: String {
        var lines = ["Tool: \(id)", "Description: \(description)"]
        if !parameters.isEmpty {
            lines.append("Parameters:")
            for p in parameters {
                let req = p.required ? "required" : "optional"
                lines.append("  - \(p.name) (\(p.type), \(req)): \(p.description)")
            }
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Tool Registry (59 built-in tools + custom tools)

extension AgentTool {

    static let builtIns: [AgentTool] =
        fileSystemTools +
        codeAnalysisTools +
        codeGenTools +
        textTools +
        utilityTools +
        projectTools +
        dependencyTools +
        buildTools +
        searchTools +
        refactoringTools +
        formattingTools +
        documentationTools +
        testingTools +
        performanceTools +
        securityTools

    /// All available tools, including user-defined custom tools from CustomToolRegistry.
    static var all: [AgentTool] {
        builtIns + CustomToolRegistry.shared.asAgentTools
    }

    // MARK: File System (12)

    static let fileSystemTools: [AgentTool] = [
        AgentTool(
            id: "read_file",
            displayName: "Read File",
            description: "Read the full contents of a file in the current project",
            parameters: [.init(name: "path", description: "Relative path to the file (e.g. Sources/ContentView.swift)")],
            category: .fileSystem
        ),
        AgentTool(
            id: "write_file",
            displayName: "Write File",
            description: "Write or overwrite the contents of a file in the current project",
            parameters: [
                .init(name: "path",    description: "Relative path to the file"),
                .init(name: "content", description: "New content to write")
            ],
            category: .fileSystem
        ),
        AgentTool(
            id: "create_file",
            displayName: "Create File",
            description: "Create a new file (and any missing parent directories) in the current project",
            parameters: [
                .init(name: "path",    description: "Relative path for the new file"),
                .init(name: "content", description: "Initial file content", required: false, defaultValue: "")
            ],
            category: .fileSystem
        ),
        AgentTool(
            id: "delete_file",
            displayName: "Delete File",
            description: "Permanently delete a file from the current project",
            parameters: [.init(name: "path", description: "Relative path to the file")],
            category: .fileSystem
        ),
        AgentTool(
            id: "list_directory",
            displayName: "List Directory",
            description: "List the files and sub-folders inside a directory of the current project",
            parameters: [
                .init(name: "path", description: "Relative path to the directory, or empty string for project root",
                      required: false, defaultValue: "")
            ],
            category: .fileSystem
        ),
        AgentTool(
            id: "create_directory",
            displayName: "Create Directory",
            description: "Create a new directory (including any needed parents) in the current project",
            parameters: [.init(name: "path", description: "Relative path for the new directory")],
            category: .fileSystem
        ),
        AgentTool(
            id: "delete_directory",
            displayName: "Delete Directory",
            description: "Delete a directory and all of its contents from the current project",
            parameters: [.init(name: "path", description: "Relative path to the directory")],
            category: .fileSystem
        ),
        AgentTool(
            id: "rename_item",
            displayName: "Rename File or Folder",
            description: "Rename a file or folder in the current project",
            parameters: [
                .init(name: "old_path", description: "Current relative path of the item"),
                .init(name: "new_name", description: "New name only (not a full path)")
            ],
            category: .fileSystem
        ),
        AgentTool(
            id: "file_exists",
            displayName: "File Exists",
            description: "Check whether a file or directory exists in the current project",
            parameters: [.init(name: "path", description: "Relative path to check")],
            category: .fileSystem
        ),
        AgentTool(
            id: "copy_file",
            displayName: "Copy File",
            description: "Copy a file to a new location within the current project",
            parameters: [
                .init(name: "source",      description: "Source relative path"),
                .init(name: "destination", description: "Destination relative path")
            ],
            category: .fileSystem
        ),
        AgentTool(
            id: "get_file_info",
            displayName: "Get File Info",
            description: "Get metadata (size, created, modified) for a file in the current project",
            parameters: [.init(name: "path", description: "Relative path to the file")],
            category: .fileSystem
        ),
        AgentTool(
            id: "append_to_file",
            displayName: "Append to File",
            description: "Append text to the end of an existing file",
            parameters: [
                .init(name: "path",    description: "Relative path to the file"),
                .init(name: "content", description: "Content to append")
            ],
            category: .fileSystem
        ),
    ]

    // MARK: Code Analysis (10)

    static let codeAnalysisTools: [AgentTool] = [
        AgentTool(
            id: "search_in_file",
            displayName: "Search in File",
            description: "Search for a text pattern in a file and return matching lines with line numbers",
            parameters: [
                .init(name: "path",  description: "Relative path to the file"),
                .init(name: "query", description: "Text to search for")
            ],
            category: .codeAnalysis
        ),
        AgentTool(
            id: "search_project",
            displayName: "Search Project",
            description: "Search for a text pattern across all files in the current project",
            parameters: [.init(name: "query", description: "Text to search for")],
            category: .codeAnalysis
        ),
        AgentTool(
            id: "find_and_replace",
            displayName: "Find and Replace",
            description: "Find and replace all occurrences of a string in a file",
            parameters: [
                .init(name: "path",    description: "Relative path to the file"),
                .init(name: "find",    description: "Text to find"),
                .init(name: "replace", description: "Replacement text")
            ],
            category: .codeAnalysis
        ),
        AgentTool(
            id: "count_lines",
            displayName: "Count Lines",
            description: "Count the number of lines in a file",
            parameters: [.init(name: "path", description: "Relative path to the file")],
            category: .codeAnalysis
        ),
        AgentTool(
            id: "extract_swift_symbols",
            displayName: "Extract Swift Symbols",
            description: "Extract all type declarations (class, struct, enum, protocol, func, extension) from a Swift file",
            parameters: [.init(name: "path", description: "Relative path to the Swift file")],
            category: .codeAnalysis
        ),
        AgentTool(
            id: "find_todos",
            displayName: "Find TODOs",
            description: "Find all TODO, FIXME, and HACK comments in a file or the whole project",
            parameters: [
                .init(name: "path",
                      description: "Relative path to a specific file, or empty to search the entire project",
                      required: false, defaultValue: "")
            ],
            category: .codeAnalysis
        ),
        AgentTool(
            id: "find_imports",
            displayName: "Find Imports",
            description: "List all import statements in a Swift file",
            parameters: [.init(name: "path", description: "Relative path to the Swift file")],
            category: .codeAnalysis
        ),
        AgentTool(
            id: "count_words",
            displayName: "Count Words",
            description: "Count the number of words in a file",
            parameters: [.init(name: "path", description: "Relative path to the file")],
            category: .codeAnalysis
        ),
        AgentTool(
            id: "get_line",
            displayName: "Get Line(s)",
            description: "Retrieve a specific line or range of lines from a file (1-based)",
            parameters: [
                .init(name: "path",     description: "Relative path to the file"),
                .init(name: "line",     type: "number", description: "Start line number (1-based)"),
                .init(name: "end_line", type: "number",
                      description: "End line number for a range; defaults to start line",
                      required: false)
            ],
            category: .codeAnalysis
        ),
        AgentTool(
            id: "diff_content",
            displayName: "Diff Content",
            description: "Compare two text strings line-by-line and show differences",
            parameters: [
                .init(name: "original", description: "Original text"),
                .init(name: "modified", description: "Modified text")
            ],
            category: .codeAnalysis
        ),
    ]

    // MARK: Code Generation (12)

    static let codeGenTools: [AgentTool] = [
        AgentTool(
            id: "generate_swiftui_view",
            displayName: "Generate SwiftUI View",
            description: "Generate a SwiftUI view scaffold with an optional body description",
            parameters: [
                .init(name: "name",        description: "Struct name (e.g. ProfileView)"),
                .init(name: "description", description: "What the view should contain",
                      required: false, defaultValue: "")
            ],
            category: .codeGen
        ),
        AgentTool(
            id: "generate_model",
            displayName: "Generate Data Model",
            description: "Generate a Codable Swift struct for a data model",
            parameters: [
                .init(name: "name",       description: "Model struct name (e.g. User)"),
                .init(name: "properties", description: "Comma-separated property:type pairs (e.g. id:String, name:String, age:Int)")
            ],
            category: .codeGen
        ),
        AgentTool(
            id: "generate_viewmodel",
            displayName: "Generate ViewModel",
            description: "Generate an ObservableObject ViewModel class",
            parameters: [
                .init(name: "name",       description: "ViewModel class name (e.g. ProfileViewModel)"),
                .init(name: "model_name", description: "Associated model type name",
                      required: false, defaultValue: "")
            ],
            category: .codeGen
        ),
        AgentTool(
            id: "generate_service",
            displayName: "Generate Service",
            description: "Generate a singleton service/manager class",
            parameters: [
                .init(name: "name",        description: "Service class name (e.g. NetworkService)"),
                .init(name: "description", description: "What the service does",
                      required: false, defaultValue: "")
            ],
            category: .codeGen
        ),
        AgentTool(
            id: "generate_unit_tests",
            displayName: "Generate Unit Tests",
            description: "Generate XCTest unit test stubs for a given type",
            parameters: [
                .init(name: "type_name", description: "Name of the type to test (e.g. UserViewModel)"),
                .init(name: "methods",   description: "Comma-separated method names to test",
                      required: false, defaultValue: "")
            ],
            category: .codeGen
        ),
        AgentTool(
            id: "generate_enum",
            displayName: "Generate Enum",
            description: "Generate a Swift enum with specified cases",
            parameters: [
                .init(name: "name",     description: "Enum name"),
                .init(name: "cases",    description: "Comma-separated case names"),
                .init(name: "raw_type", description: "Raw value type (String, Int) or empty for none",
                      required: false, defaultValue: "")
            ],
            category: .codeGen
        ),
        AgentTool(
            id: "generate_protocol",
            displayName: "Generate Protocol",
            description: "Generate a Swift protocol definition",
            parameters: [
                .init(name: "name",    description: "Protocol name"),
                .init(name: "methods", description: "Comma-separated method signatures",
                      required: false, defaultValue: "")
            ],
            category: .codeGen
        ),
        AgentTool(
            id: "generate_extension",
            displayName: "Generate Extension",
            description: "Generate a Swift extension for an existing type",
            parameters: [
                .init(name: "type_name",   description: "The type to extend (e.g. String, View)"),
                .init(name: "description", description: "What the extension adds",
                      required: false, defaultValue: "")
            ],
            category: .codeGen
        ),
        AgentTool(
            id: "generate_struct",
            displayName: "Generate Struct",
            description: "Generate a plain Swift struct with optional properties",
            parameters: [
                .init(name: "name",       description: "Struct name"),
                .init(name: "properties", description: "Comma-separated property:type pairs",
                      required: false, defaultValue: "")
            ],
            category: .codeGen
        ),
        AgentTool(
            id: "generate_async_function",
            displayName: "Generate Async Function",
            description: "Generate an async/await Swift function template",
            parameters: [
                .init(name: "name",        description: "Function name"),
                .init(name: "return_type", description: "Return type (e.g. String, [User])",
                      required: false, defaultValue: "Void"),
                .init(name: "parameters",  description: "Comma-separated param:type pairs",
                      required: false, defaultValue: "")
            ],
            category: .codeGen
        ),
        AgentTool(
            id: "add_swift_import",
            displayName: "Add Swift Import",
            description: "Add an import statement to a Swift file if not already present",
            parameters: [
                .init(name: "path",   description: "Relative path to the Swift file"),
                .init(name: "module", description: "Module to import (e.g. Foundation, Combine)")
            ],
            category: .codeGen
        ),
        AgentTool(
            id: "generate_preview",
            displayName: "Generate SwiftUI Preview",
            description: "Generate a #Preview macro block for a SwiftUI view",
            parameters: [
                .init(name: "view_name",   description: "Name of the SwiftUI view struct"),
                .init(name: "parameters",  description: "Constructor arguments for the preview",
                      required: false, defaultValue: "")
            ],
            category: .codeGen
        ),
    ]

    // MARK: Text & Strings (8)

    static let textTools: [AgentTool] = [
        AgentTool(
            id: "to_camel_case",
            displayName: "To camelCase",
            description: "Convert a string to camelCase",
            parameters: [.init(name: "text", description: "Input text")],
            category: .textUtils
        ),
        AgentTool(
            id: "to_snake_case",
            displayName: "To snake_case",
            description: "Convert a string to snake_case",
            parameters: [.init(name: "text", description: "Input text")],
            category: .textUtils
        ),
        AgentTool(
            id: "to_pascal_case",
            displayName: "To PascalCase",
            description: "Convert a string to PascalCase",
            parameters: [.init(name: "text", description: "Input text")],
            category: .textUtils
        ),
        AgentTool(
            id: "encode_base64",
            displayName: "Encode Base64",
            description: "Encode a UTF-8 string to Base64",
            parameters: [.init(name: "text", description: "Text to encode")],
            category: .textUtils
        ),
        AgentTool(
            id: "decode_base64",
            displayName: "Decode Base64",
            description: "Decode a Base64 string back to UTF-8 text",
            parameters: [.init(name: "text", description: "Base64 string to decode")],
            category: .textUtils
        ),
        AgentTool(
            id: "count_characters",
            displayName: "Count Characters",
            description: "Count the number of Unicode characters in a string",
            parameters: [.init(name: "text", description: "Input text")],
            category: .textUtils
        ),
        AgentTool(
            id: "reverse_string",
            displayName: "Reverse String",
            description: "Reverse the characters in a string",
            parameters: [.init(name: "text", description: "Input text")],
            category: .textUtils
        ),
        AgentTool(
            id: "format_json",
            displayName: "Format JSON",
            description: "Pretty-print a compact JSON string",
            parameters: [.init(name: "json", description: "Compact JSON string to format")],
            category: .textUtils
        ),
    ]

    // MARK: Utilities (9)

    static let utilityTools: [AgentTool] = [
        AgentTool(
            id: "calculate",
            displayName: "Calculate",
            description: "Evaluate a mathematical expression (supports +, -, *, /, parentheses)",
            parameters: [.init(name: "expression", description: "Math expression (e.g. (10 + 5) * 2)")],
            category: .utilities
        ),
        AgentTool(
            id: "generate_uuid",
            displayName: "Generate UUID",
            description: "Generate a new random UUID string",
            parameters: [],
            category: .utilities
        ),
        AgentTool(
            id: "current_datetime",
            displayName: "Current Date & Time",
            description: "Get the current date and time in a given format",
            parameters: [
                .init(name: "format",
                      description: "Date format string (e.g. yyyy-MM-dd HH:mm:ss)",
                      required: false, defaultValue: "yyyy-MM-dd HH:mm:ss")
            ],
            category: .utilities
        ),
        AgentTool(
            id: "generate_random_number",
            displayName: "Generate Random Number",
            description: "Generate a random integer in an inclusive range",
            parameters: [
                .init(name: "min", type: "number", description: "Minimum value (inclusive)"),
                .init(name: "max", type: "number", description: "Maximum value (inclusive)")
            ],
            category: .utilities
        ),
        AgentTool(
            id: "validate_json",
            displayName: "Validate JSON",
            description: "Check whether a string is valid JSON",
            parameters: [.init(name: "json", description: "JSON string to validate")],
            category: .utilities
        ),
        AgentTool(
            id: "hash_string",
            displayName: "Hash String (SHA-256)",
            description: "Generate a hex-encoded SHA-256 hash of a string",
            parameters: [.init(name: "text", description: "Text to hash")],
            category: .utilities
        ),
        AgentTool(
            id: "url_encode",
            displayName: "URL Encode",
            description: "Percent-encode a string for use in a URL query parameter",
            parameters: [.init(name: "text", description: "Text to URL-encode")],
            category: .utilities
        ),
        AgentTool(
            id: "url_decode",
            displayName: "URL Decode",
            description: "Decode a percent-encoded (URL-encoded) string",
            parameters: [.init(name: "text", description: "URL-encoded text to decode")],
            category: .utilities
        ),
        AgentTool(
            id: "repeat_text",
            displayName: "Repeat Text",
            description: "Repeat a string a given number of times",
            parameters: [
                .init(name: "text",  description: "Text to repeat"),
                .init(name: "count", type: "number", description: "Number of repetitions")
            ],
            category: .utilities
        ),
    ]

    // MARK: Project (8)

    static let projectTools: [AgentTool] = [
        AgentTool(
            id: "get_current_project",
            displayName: "Get Current Project",
            description: "Return information about the currently open project",
            parameters: [],
            category: .project
        ),
        AgentTool(
            id: "list_projects",
            displayName: "List Projects",
            description: "List all projects saved in SwiftCode",
            parameters: [],
            category: .project
        ),
        AgentTool(
            id: "get_project_structure",
            displayName: "Get Project Structure",
            description: "Return the full file/folder tree of the current project",
            parameters: [],
            category: .project
        ),
        AgentTool(
            id: "get_active_file",
            displayName: "Get Active File",
            description: "Return info about the file currently open in the editor",
            parameters: [],
            category: .project
        ),
        AgentTool(
            id: "read_active_file",
            displayName: "Read Active File",
            description: "Read the full content of the file currently open in the editor",
            parameters: [],
            category: .project
        ),
        AgentTool(
            id: "write_active_file",
            displayName: "Write Active File",
            description: "Replace the content of the file currently open in the editor",
            parameters: [.init(name: "content", description: "New content for the active file")],
            category: .project
        ),
        AgentTool(
            id: "get_file_count",
            displayName: "Get File Count",
            description: "Count the total number of files in the current project",
            parameters: [],
            category: .project
        ),
        AgentTool(
            id: "search_and_replace_project",
            displayName: "Search & Replace in Project",
            description: "Find and replace text across all files in the current project",
            parameters: [
                .init(name: "find",           description: "Text to find"),
                .init(name: "replace",        description: "Replacement text"),
                .init(name: "file_extension",
                      description: "Only process files with this extension (e.g. swift, md), or empty for all",
                      required: false, defaultValue: "")
            ],
            category: .project
        ),
    ]

    // MARK: Dependency Tools (3)

    static let dependencyTools: [AgentTool] = [
        AgentTool(
            id: "install_dependency",
            displayName: "Install Dependency",
            description: "Add a Swift Package dependency to the project's Package.swift",
            parameters: [
                .init(name: "name",    description: "Package name (e.g. Alamofire)"),
                .init(name: "url",     description: "Git URL of the package"),
                .init(name: "version", description: "Minimum version (e.g. 5.6.0)")
            ],
            category: .dependency
        ),
        AgentTool(
            id: "remove_dependency",
            displayName: "Remove Dependency",
            description: "Remove a Swift Package dependency from the project's Package.swift",
            parameters: [
                .init(name: "name", description: "Package name to remove")
            ],
            category: .dependency
        ),
        AgentTool(
            id: "update_dependency",
            displayName: "Update Dependency",
            description: "Update a dependency version in Package.swift",
            parameters: [
                .init(name: "name",        description: "Package name"),
                .init(name: "new_version", description: "New minimum version")
            ],
            category: .dependency
        ),
    ]

    // MARK: Build Tools (3)

    static let buildTools: [AgentTool] = [
        AgentTool(
            id: "trigger_workflow",
            displayName: "Trigger GitHub Workflow",
            description: "Trigger a GitHub Actions workflow for the connected repository",
            parameters: [
                .init(name: "workflow", description: "Workflow file name (e.g. build.yml)", required: false, defaultValue: "build.yml")
            ],
            category: .build
        ),
        AgentTool(
            id: "check_workflow_status",
            displayName: "Check Workflow Status",
            description: "Check the status of recent GitHub Actions workflow runs",
            parameters: [],
            category: .build
        ),
        AgentTool(
            id: "get_build_logs",
            displayName: "Get Build Logs",
            description: "Retrieve logs from the most recent GitHub Actions build",
            parameters: [
                .init(name: "run_id", description: "Workflow run ID (optional, defaults to latest)", required: false, defaultValue: "")
            ],
            category: .build
        ),
    ]

    // MARK: Search Tools (4)

    static let searchTools: [AgentTool] = [
        AgentTool(
            id: "search_codebase",
            displayName: "Search Codebase",
            description: "Search the entire project codebase for a text pattern",
            parameters: [
                .init(name: "query", description: "Search query text")
            ],
            category: .search
        ),
        AgentTool(
            id: "locate_function",
            displayName: "Locate Function",
            description: "Find where a specific function is defined in the project",
            parameters: [
                .init(name: "name", description: "Function name to locate")
            ],
            category: .search
        ),
        AgentTool(
            id: "find_references",
            displayName: "Find References",
            description: "Find all references to a symbol across the project",
            parameters: [
                .init(name: "symbol", description: "Symbol name to find references for")
            ],
            category: .search
        ),
        AgentTool(
            id: "analyze_symbols",
            displayName: "Analyze Symbols",
            description: "Analyze and list all symbols (functions, structs, classes, etc.) in a file",
            parameters: [
                .init(name: "path", description: "Relative path to the file to analyze")
            ],
            category: .search
        ),
    ]

    // MARK: Refactoring Tools (8)

    static let refactoringTools: [AgentTool] = [
        AgentTool(
            id: "extract_method",
            displayName: "Extract Method",
            description: "Extract a range of lines from a function into a new method with proper parameter passing",
            parameters: [
                .init(name: "path", description: "Relative path to the file"),
                .init(name: "start_line", type: "number", description: "Start line of code to extract"),
                .init(name: "end_line", type: "number", description: "End line of code to extract"),
                .init(name: "method_name", description: "Name for the new extracted method")
            ],
            category: .refactoring
        ),
        AgentTool(
            id: "rename_symbol",
            displayName: "Rename Symbol",
            description: "Rename a symbol (variable, function, type) across the entire project",
            parameters: [
                .init(name: "old_name", description: "Current symbol name"),
                .init(name: "new_name", description: "New symbol name"),
                .init(name: "file_extension", description: "Only process files with this extension", required: false, defaultValue: "swift")
            ],
            category: .refactoring
        ),
        AgentTool(
            id: "inline_variable",
            displayName: "Inline Variable",
            description: "Replace a variable with its value at all usage sites in a file",
            parameters: [
                .init(name: "path", description: "Relative path to the file"),
                .init(name: "variable_name", description: "Name of the variable to inline")
            ],
            category: .refactoring
        ),
        AgentTool(
            id: "extract_protocol",
            displayName: "Extract Protocol",
            description: "Extract a protocol from a class or struct's public interface",
            parameters: [
                .init(name: "path", description: "Relative path to the file"),
                .init(name: "type_name", description: "Name of the type to extract protocol from"),
                .init(name: "protocol_name", description: "Name for the new protocol")
            ],
            category: .refactoring
        ),
        AgentTool(
            id: "convert_to_async",
            displayName: "Convert to Async",
            description: "Convert a completion-handler-based function to async/await syntax",
            parameters: [
                .init(name: "path", description: "Relative path to the file"),
                .init(name: "function_name", description: "Name of the function to convert")
            ],
            category: .refactoring
        ),
        AgentTool(
            id: "split_file",
            displayName: "Split File",
            description: "Split a large file into multiple files based on type declarations",
            parameters: [
                .init(name: "path", description: "Relative path to the file to split"),
                .init(name: "output_directory", description: "Directory for the split files", required: false, defaultValue: "")
            ],
            category: .refactoring
        ),
        AgentTool(
            id: "add_conformance",
            displayName: "Add Protocol Conformance",
            description: "Add protocol conformance (Equatable, Hashable, Codable, etc.) to a type with auto-generated implementations",
            parameters: [
                .init(name: "path", description: "Relative path to the file"),
                .init(name: "type_name", description: "Name of the type"),
                .init(name: "protocol", description: "Protocol to conform to (e.g. Equatable, Hashable, Codable, CustomStringConvertible)")
            ],
            category: .refactoring
        ),
        AgentTool(
            id: "dependency_graph",
            displayName: "Dependency Graph",
            description: "Generate a dependency graph showing import relationships between all project files",
            parameters: [
                .init(name: "format", description: "Output format: text, mermaid, or dot", required: false, defaultValue: "text")
            ],
            category: .refactoring
        ),
    ]

    // MARK: Formatting Tools (6)

    static let formattingTools: [AgentTool] = [
        AgentTool(
            id: "format_file",
            displayName: "Format File",
            description: "Auto-format a source file with consistent indentation, spacing, and style",
            parameters: [
                .init(name: "path", description: "Relative path to the file to format")
            ],
            category: .formatting
        ),
        AgentTool(
            id: "format_selection",
            displayName: "Format Selection",
            description: "Format a specific range of lines in a file",
            parameters: [
                .init(name: "path", description: "Relative path to the file"),
                .init(name: "start_line", type: "number", description: "Start line"),
                .init(name: "end_line", type: "number", description: "End line")
            ],
            category: .formatting
        ),
        AgentTool(
            id: "sort_imports",
            displayName: "Sort Imports",
            description: "Sort and organize import statements alphabetically in a Swift file",
            parameters: [
                .init(name: "path", description: "Relative path to the Swift file")
            ],
            category: .formatting
        ),
        AgentTool(
            id: "normalize_whitespace",
            displayName: "Normalize Whitespace",
            description: "Remove trailing whitespace, normalize line endings, and fix indentation across a file",
            parameters: [
                .init(name: "path", description: "Relative path to the file"),
                .init(name: "tab_width", type: "number", description: "Number of spaces per tab", required: false, defaultValue: "4")
            ],
            category: .formatting
        ),
        AgentTool(
            id: "remove_unused_imports",
            displayName: "Remove Unused Imports",
            description: "Detect and remove import statements that are not referenced in the file",
            parameters: [
                .init(name: "path", description: "Relative path to the Swift file")
            ],
            category: .formatting
        ),
        AgentTool(
            id: "add_mark_sections",
            displayName: "Add MARK Sections",
            description: "Automatically add // MARK: - sections to organize a Swift file by properties, methods, and protocol conformances",
            parameters: [
                .init(name: "path", description: "Relative path to the Swift file")
            ],
            category: .formatting
        ),
    ]

    // MARK: Documentation Tools (5)

    static let documentationTools: [AgentTool] = [
        AgentTool(
            id: "generate_doc_comment",
            displayName: "Generate Doc Comment",
            description: "Generate a documentation comment for a function, type, or property",
            parameters: [
                .init(name: "path", description: "Relative path to the file"),
                .init(name: "symbol_name", description: "Name of the symbol to document")
            ],
            category: .documentation
        ),
        AgentTool(
            id: "generate_readme",
            displayName: "Generate README",
            description: "Generate a comprehensive README.md for the project with usage, setup, and architecture sections",
            parameters: [
                .init(name: "include_api", description: "Include API documentation section", required: false, defaultValue: "true")
            ],
            category: .documentation
        ),
        AgentTool(
            id: "generate_changelog",
            displayName: "Generate Changelog",
            description: "Generate a CHANGELOG.md entry based on recent code changes",
            parameters: [
                .init(name: "version", description: "Version number for this changelog entry"),
                .init(name: "changes", description: "Comma-separated list of changes")
            ],
            category: .documentation
        ),
        AgentTool(
            id: "generate_api_docs",
            displayName: "Generate API Docs",
            description: "Generate API reference documentation for all public types and methods in a file",
            parameters: [
                .init(name: "path", description: "Relative path to the Swift file")
            ],
            category: .documentation
        ),
        AgentTool(
            id: "generate_architecture_doc",
            displayName: "Generate Architecture Doc",
            description: "Generate an architecture decision record (ADR) documenting a design decision",
            parameters: [
                .init(name: "title", description: "Decision title"),
                .init(name: "context", description: "Background context for the decision"),
                .init(name: "decision", description: "The decision that was made"),
                .init(name: "consequences", description: "Expected consequences of this decision")
            ],
            category: .documentation
        ),
    ]

    // MARK: Testing Tools (6)

    static let testingTools: [AgentTool] = [
        AgentTool(
            id: "generate_test_suite",
            displayName: "Generate Test Suite",
            description: "Generate a comprehensive test suite for a Swift type including unit, edge case, and error tests",
            parameters: [
                .init(name: "path", description: "Relative path to the file containing the type to test"),
                .init(name: "type_name", description: "Name of the type to generate tests for")
            ],
            category: .testing
        ),
        AgentTool(
            id: "generate_mock",
            displayName: "Generate Mock",
            description: "Generate a mock implementation of a protocol for testing",
            parameters: [
                .init(name: "path", description: "Relative path to the file containing the protocol"),
                .init(name: "protocol_name", description: "Name of the protocol to mock")
            ],
            category: .testing
        ),
        AgentTool(
            id: "generate_test_data",
            displayName: "Generate Test Data Factory",
            description: "Generate a factory that creates test instances of a model type with sensible defaults",
            parameters: [
                .init(name: "path", description: "Relative path to the model file"),
                .init(name: "type_name", description: "Name of the model type")
            ],
            category: .testing
        ),
        AgentTool(
            id: "analyze_testability",
            displayName: "Analyze Testability",
            description: "Analyze a type for testability issues: tight coupling, hidden dependencies, global state",
            parameters: [
                .init(name: "path", description: "Relative path to the file"),
                .init(name: "type_name", description: "Name of the type to analyze")
            ],
            category: .testing
        ),
        AgentTool(
            id: "generate_snapshot_test",
            displayName: "Generate Snapshot Test",
            description: "Generate a snapshot test for a SwiftUI view",
            parameters: [
                .init(name: "view_name", description: "Name of the SwiftUI view to snapshot test"),
                .init(name: "configurations", description: "Comma-separated device configurations to test", required: false, defaultValue: "iPhone SE,iPhone 15 Pro")
            ],
            category: .testing
        ),
        AgentTool(
            id: "generate_performance_test",
            displayName: "Generate Performance Test",
            description: "Generate a performance test with measurement baselines for a function",
            parameters: [
                .init(name: "function_name", description: "Name of the function to measure"),
                .init(name: "iterations", type: "number", description: "Number of iterations to measure", required: false, defaultValue: "10")
            ],
            category: .testing
        ),
    ]

    // MARK: Performance Tools (5)

    static let performanceTools: [AgentTool] = [
        AgentTool(
            id: "analyze_complexity",
            displayName: "Analyze Complexity",
            description: "Calculate cyclomatic complexity and cognitive complexity for functions in a file",
            parameters: [
                .init(name: "path", description: "Relative path to the file to analyze")
            ],
            category: .performance
        ),
        AgentTool(
            id: "find_large_files",
            displayName: "Find Large Files",
            description: "Find the largest files in the project by line count",
            parameters: [
                .init(name: "limit", type: "number", description: "Number of files to return", required: false, defaultValue: "10")
            ],
            category: .performance
        ),
        AgentTool(
            id: "detect_retain_cycles",
            displayName: "Detect Retain Cycles",
            description: "Scan Swift files for common retain cycle patterns (missing weak self, strong delegate references)",
            parameters: [
                .init(name: "path", description: "Relative path to the file, or empty to scan entire project", required: false, defaultValue: "")
            ],
            category: .performance
        ),
        AgentTool(
            id: "find_force_unwraps",
            displayName: "Find Force Unwraps",
            description: "Find all force unwrap (!) usage in a file or project for safety auditing",
            parameters: [
                .init(name: "path", description: "Relative path to the file, or empty to scan entire project", required: false, defaultValue: "")
            ],
            category: .performance
        ),
        AgentTool(
            id: "analyze_view_body_complexity",
            displayName: "Analyze View Body Complexity",
            description: "Analyze SwiftUI view body complexity and suggest extraction of subviews",
            parameters: [
                .init(name: "path", description: "Relative path to the SwiftUI view file")
            ],
            category: .performance
        ),
    ]

    // MARK: Security Tools (5)

    static let securityTools: [AgentTool] = [
        AgentTool(
            id: "audit_secrets",
            displayName: "Audit Secrets",
            description: "Scan the project for hardcoded secrets, API keys, passwords, and tokens",
            parameters: [],
            category: .security
        ),
        AgentTool(
            id: "check_permissions",
            displayName: "Check Permissions",
            description: "List all iOS permission usage descriptions in Info.plist and verify they have appropriate descriptions",
            parameters: [],
            category: .security
        ),
        AgentTool(
            id: "audit_network_security",
            displayName: "Audit Network Security",
            description: "Check for insecure network configurations: HTTP URLs, missing ATS settings, no certificate pinning",
            parameters: [],
            category: .security
        ),
        AgentTool(
            id: "audit_data_storage",
            displayName: "Audit Data Storage",
            description: "Check for sensitive data stored insecurely (UserDefaults for tokens, unencrypted files)",
            parameters: [],
            category: .security
        ),
        AgentTool(
            id: "generate_keychain_wrapper",
            displayName: "Generate Keychain Wrapper",
            description: "Generate a type-safe Keychain access wrapper for secure data storage",
            parameters: [
                .init(name: "name", description: "Wrapper class name"),
                .init(name: "keys", description: "Comma-separated key names to store (e.g. authToken, apiKey, refreshToken)")
            ],
            category: .security
        ),
    ]
}
