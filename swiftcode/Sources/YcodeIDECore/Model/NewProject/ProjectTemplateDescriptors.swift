import Foundation

public struct ProjectTemplateDescriptor: Equatable, Sendable, Identifiable {
    public var id: String
    public var platform: String
    public var section: String
    public var title: String
    public var sortKey: Int?
    public var summary: String
    public var symbol: String
    public var fields: [TemplateOptionField]
    public var generator: String
    public var unavailableReason: String?
    public var defaultSaveName: String?

    public init(id: String, platform: String, section: String, title: String, sortKey: Int?, summary: String, symbol: String,
                fields: [TemplateOptionField], generator: String, unavailableReason: String? = nil, defaultSaveName: String? = nil) {
        self.id = id
        self.platform = platform
        self.section = section
        self.title = title
        self.sortKey = sortKey
        self.summary = summary
        self.symbol = symbol
        self.fields = fields
        self.generator = generator
        self.unavailableReason = unavailableReason
        self.defaultSaveName = defaultSaveName
    }

    public var isAvailable: Bool { unavailableReason == nil }
    public var sdk: TemplateSDK { TemplateSDK.forTab(platform) }
    public var memoryKey: String { "\(section)/\(title)" }
    public var isPackage: Bool { generator.hasPrefix("package:") }

    public func makeForm(_ values: [String: String] = [:]) -> TemplateOptionsForm { TemplateOptionsForm(fields: fields, values: values) }

    public var entry: TemplateEntry {
        var e = TemplateEntry(title, defaultName: "", symbol: symbol)
        e.templateID = id
        e.summary = summary
        return e
    }
}

public struct TemplateChooserCatalog: Sendable {
    public var tabs: [String]
    public var templates: [ProjectTemplateDescriptor]

    public func templates(platform: String) -> [ProjectTemplateDescriptor] {
        templates.filter { $0.platform == platform }.sorted { a, b in
            if a.section != b.section { return a.section.localizedStandardCompare(b.section) == .orderedAscending }
            switch (a.sortKey, b.sortKey) {
            case let (x?, y?) where x != y: return x < y
            case (_?, nil): return true
            case (nil, _?): return false
            default: return a.title.localizedStandardCompare(b.title) == .orderedAscending
            }
        }
    }

    public func sections(platform: String, filter: String = "") -> [TemplateSection] {
        let f = filter.trimmingCharacters(in: .whitespaces)
        var order: [String] = []
        var bySection: [String: [TemplateEntry]] = [:]
        for t in templates(platform: platform) {
            if !f.isEmpty, t.title.range(of: f, options: [.caseInsensitive, .diacriticInsensitive]) == nil { continue }
            if bySection[t.section] == nil { order.append(t.section) }
            bySection[t.section, default: []].append(t.entry)
        }
        return order.map { TemplateSection(title: $0, entries: bySection[$0]!) }
    }

    public func find(_ key: String, platform: String? = nil) -> ProjectTemplateDescriptor? {
        let k = key.lowercased()
        if let d = templates.first(where: { $0.id == k }) { return d }
        let parts = key.split(separator: "/", maxSplits: 1).map(String.init)
        if parts.count == 2, tabs.contains(where: { $0.caseInsensitiveCompare(parts[0]) == .orderedSame }) {
            return find(parts[1], platform: parts[0])
        }
        let pool = platform.map { p in templates.filter { $0.platform.caseInsensitiveCompare(p) == .orderedSame } } ?? templates
        if let d = pool.first(where: { $0.id.hasSuffix("." + k) }) { return d }
        return pool.first { $0.title.caseInsensitiveCompare(key) == .orderedSame || ProjectTemplates.slug($0.title) == k }
    }
}

public enum ProjectTemplates {
    typealias ID = TemplateOptionID
    static let appSection = "Application"
    static let lib = "Framework & Library"

    static func slug(_ s: String) -> String {
        var out = String(s.lowercased().map { $0.isLetter || $0.isNumber ? $0 : "-" })
        while out.contains("--") { out = out.replacingOccurrences(of: "--", with: "-") }
        return out.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    static func d(_ tab: String, _ section: String, _ title: String, _ key: Int?, _ summary: String, _ symbol: String,
                  _ fields: [TemplateOptionField], _ generator: String, unavailable: String? = nil, save: String? = nil) -> ProjectTemplateDescriptor {
        let prefix = tab == "Multiplatform" ? "multiplatform" : tab.lowercased()
        return ProjectTemplateDescriptor(id: "\(prefix).\(slug(title))", platform: tab, section: section, title: title, sortKey: key,
                                         summary: summary, symbol: symbol, fields: fields, generator: generator,
                                         unavailableReason: unavailable, defaultSaveName: save)
    }

    static let id = TemplateFields.identity
    static let objcUnavailable = "SwiftCode writes this template in Swift only."
    static let metal4Unavailable = "SwiftCode has no Metal 4 renderer yet."

    static let swiftOnlyLanguage = TemplateOptionField(ID.language, "Language", .popUp(["Swift", TemplateChoice("Objective-C", unavailable: objcUnavailable)]),
                                                       default: "Swift")

    static func gameType(_ values: [String], default def: String, swiftRealityKit: Bool = false) -> TemplateOptionField {
        let all: [String: TemplateChoice] = [
            "RealityKit": TemplateChoice("RealityKit", requires: swiftRealityKit ? [.is(ID.language, "Swift")] : []),
            "SceneKit": TemplateChoice("SceneKit", title: "SceneKit (Deprecated)"),
            "SpriteKit": "SpriteKit",
            "Metal 4": TemplateChoice("Metal 4", unavailable: metal4Unavailable),
            "Metal": "Metal",
        ]
        return TemplateOptionField(ID.gameTechnology, "Game Technology", .popUp(values.map { all[$0]! }), default: def)
    }

    static let integrateGK = TemplateOptionField(ID.integrateGameplayKit, "Integrate GameplayKit", .checkbox, default: "false",
                                                 requires: [.is(ID.gameTechnology, "SpriteKit")])
    static func platform(_ id: String, _ label: String, requires: [TemplateCondition] = []) -> TemplateOptionField {
        TemplateOptionField(id, label, .checkbox, default: "true", requires: requires)
    }

    static let appFields = id + [TemplateFields.interface, TemplateFields.lifecycle, TemplateFields.appLanguage, TemplateFields.testing,
                                 TemplateFields.storage, TemplateFields.cloudKit]

    static func documentStorage(_ coreData: Bool) -> TemplateOptionField {
        var c: [TemplateChoice] = ["None", TemplateChoice("SwiftData", requires: [.is(ID.lifecycle, "SwiftUI")])]
        if coreData { c.append(TemplateChoice("Core Data", requires: [.is(ID.lifecycle, "Cocoa")])) }
        return TemplateOptionField(ID.documentStorage, "Storage", .popUp(c), default: "None")
    }

    static let renderer = TemplateOptionField(ID.immersiveSpaceRenderer, "Immersive Space Renderer", .popUp([
        "None", "RealityKit", "Metal", TemplateChoice("Metal 4", unavailable: metal4Unavailable),
    ]), default: "None")
    static let immersion = TemplateOptionField(ID.immersiveSpace, "Immersive Space", .popUp([
        TemplateChoice("None", requires: [.is(ID.immersiveSpaceRenderer, "None")]),
        TemplateChoice("Mixed", requires: [.not(ID.immersiveSpaceRenderer, "None")]),
        TemplateChoice("Progressive", requires: [.not(ID.immersiveSpaceRenderer, "None")]),
        TemplateChoice("Full", requires: [.not(ID.immersiveSpaceRenderer, "None")]),
    ]), default: "Full", requires: [.not(ID.immersiveSpaceRenderer, "None")])

    static let libraryLanguage = [TemplateFields.language, TemplateFields.unitTesting, TemplateFields.documentation]

    static let audioUnitFields: [TemplateOptionField] = id + [
        TemplateOptionField(ID.organizationName, "Organization Name", .text, placeholder: "Your Company", required: true),
        TemplateOptionField(ID.audioUnitType, "Audio Unit Type", .popUp(["Instrument", "Generator", "Effect", "Music Effect", "MIDI Processor",
                                                                         TemplateChoice("Speech Synthesizer", unavailable: "SwiftCode has no speech synthesizer unit yet.")]),
                            default: "MIDI Processor"),
        TemplateOptionField(ID.subtypeCode, "Subtype Code", .text, placeholder: "Exactly 4 characters", required: true, persisted: false),
        TemplateOptionField(ID.manufacturerCode, "Manufacturer Code", .text, placeholder: "Exactly 4 characters, at least one upper-case",
                            required: true, persisted: false),
        TemplateOptionField(ID.hasUserInterface, "User Interface", .popUp(["Presents User Interface", "No User Interface"]),
                            default: "Presents User Interface", persisted: false),
        TemplateFields.swiftLanguage, TemplateFields.testing, TemplateFields.storage, TemplateFields.cloudKit,
    ]

    public static let all: [ProjectTemplateDescriptor] = {
        var out: [ProjectTemplateDescriptor] = []
        let mp = "Multiplatform", ios = "iOS", mac = "macOS", watch = "watchOS", tv = "tvOS", vision = "visionOS", dk = "DriverKit"
        out += [
            d(mp, appSection, "App", 1, "One SwiftUI app target for iOS, iPadOS, macOS and visionOS", "app.badge",
              id + [TemplateFields.testing, TemplateFields.storage, TemplateFields.cloudKit], "app"),
            d(mp, appSection, "Document App", 1, "The same, built around a document type", "doc.richtext",
              id + [TemplateFields.testing, documentStorage(false)], "documentApp"),
            d(mp, appSection, "Foveated Streaming App", 10, "An iOS sender app and a visionOS receiver app that stream to each other", "eye",
              id + [platform(ID.iOSPlatform, "Include iOS Application"), platform(ID.visionOSPlatform, "Include visionOS Application")],
              "unavailable", unavailable: "SwiftCode cannot create this template yet: it needs a streaming package SwiftCode does not have."),
            d(mp, appSection, "Game", 10, "A game for iOS, tvOS, macOS and visionOS in the chosen game technology", "gamecontroller",
              id + [gameType(["RealityKit", "SceneKit", "SpriteKit", "Metal 4", "Metal"], default: "RealityKit"), swiftOnlyLanguage,
                    platform(ID.iOSPlatform, "Include iOS Application"),
                    platform(ID.visionOSPlatform, "Include visionOS Application", requires: [.is(ID.gameTechnology, "RealityKit")]),
                    platform(ID.tvOSPlatform, "Include tvOS Application", requires: [.is(ID.iOSPlatform, "true")]),
                    platform(ID.macOSPlatform, "Include macOS Application")], "game"),
            d(mp, appSection, "Audio Unit Extension App", 30, "A host app with an Audio Unit extension", "waveform", audioUnitFields, "audioUnitApp"),
            d(mp, appSection, "Safari Extension App", nil, "iOS and macOS apps, each with a Safari web extension", "globe",
              id + [swiftOnlyLanguage], "safariExtensionApp"),
            d(mp, lib, "Framework", 1, "A framework built for every Apple platform", "shippingbox",
              id + [TemplateFields.swiftLanguage, TemplateFields.unitTesting, TemplateFields.documentation], "framework"),
        ]
        out += [
            d(ios, appSection, "App", 1, "An iOS app (SwiftUI or UIKit storyboard)", "app.badge", appFields, "app"),
            d(ios, appSection, "Document App", 2, "An iOS document-based app", "doc.richtext",
              id + [TemplateFields.interface.with(choices: ["SwiftUI", TemplateChoice("Storyboard", title: "UIKit")]), TemplateFields.lifecycle,
                    swiftOnlyLanguage, TemplateFields.testing, documentStorage(false)], "documentApp"),
            d(ios, appSection, "Game", 10, "An iOS game (SceneKit, SpriteKit, Metal 4 or Metal)", "gamecontroller",
              id + [gameType(["SceneKit", "SpriteKit", "Metal 4", "Metal"], default: "SpriteKit"), integrateGK, swiftOnlyLanguage,
                    TemplateFields.testing], "game"),
            d(ios, appSection, "Augmented Reality App", 11, "An iOS AR app (RealityKit, SceneKit, SpriteKit or Metal)", "camera.viewfinder",
              id + [TemplateOptionField(ID.contentTechnology, "Content Technology", .popUp([
                        "RealityKit", TemplateChoice("SceneKit", title: "SceneKit (Deprecated)"), "SpriteKit",
                        TemplateChoice("Metal", unavailable: "SwiftCode has no AR Metal renderer yet."),
                    ]), default: "RealityKit"),
                    TemplateFields.interface.with(choices: [TemplateChoice("SwiftUI", requires: [.is(ID.contentTechnology, "RealityKit")]),
                                                            TemplateChoice("Storyboard", requires: [.not(ID.contentTechnology, "RealityKit")])]),
                    swiftOnlyLanguage, TemplateFields.testing], "arApp"),
            d(ios, appSection, "App Playground", 12, "A Swift Playgrounds app package (.swiftpm)", "play.rectangle",
              [TemplateFields.productName.with(label: "App Name"), TemplateFields.team, TemplateFields.organization, TemplateFields.bundleIdentifier],
              "appPlayground", save: "My App"),
            d(ios, appSection, "Sticker Pack App", 30, "A Messages sticker pack with no code", "face.smiling", id, "stickerPackApp"),
            d(ios, appSection, "iMessage App", 31, "A Messages-only app with an iMessage extension", "message", id + [swiftOnlyLanguage], "iMessageApp"),
            d(ios, appSection, "Safari Extension App", nil, "An iOS app with a Safari web extension", "globe",
              id + [swiftOnlyLanguage, TemplateFields.testing], "safariExtensionApp"),
            d(ios, lib, "Framework", 1, "An iOS framework", "shippingbox", id + libraryLanguage, "framework"),
            d(ios, lib, "Static Library", 10, "An iOS static library", "building.columns", id + [TemplateFields.language], "staticLibrary"),
            d(ios, lib, "Metal Library", nil, "A standalone .metallib", "cube", [TemplateFields.productName, TemplateFields.team], "metalLibrary"),
        ]
        out += [
            d(mac, appSection, "App", 1, "A macOS app (SwiftUI, storyboard or XIB)", "macwindow",
              id + [TemplateFields.interface.with(choices: ["SwiftUI", "Storyboard", "XIB"]), TemplateFields.lifecycle, TemplateFields.appLanguage,
                    TemplateFields.testing, TemplateFields.storage, TemplateFields.cloudKit], "app"),
            d(mac, appSection, "Document App", 1, "A macOS document-based app", "doc.richtext",
              id + [TemplateFields.interface.with(choices: ["SwiftUI", "Storyboard", "XIB"]), TemplateFields.lifecycle, swiftOnlyLanguage,
                    TemplateFields.testing, documentStorage(true)], "documentApp"),
            d(mac, appSection, "Game", 10, "A macOS game (RealityKit, SceneKit, SpriteKit, Metal 4 or Metal)", "gamecontroller",
              id + [gameType(["RealityKit", "SceneKit", "SpriteKit", "Metal 4", "Metal"], default: "SpriteKit", swiftRealityKit: true), integrateGK,
                    swiftOnlyLanguage, TemplateFields.testing], "game"),
            d(mac, appSection, "Spatial Rendering App", 11, "A macOS app that renders an immersive space for Apple Vision Pro", "rectangle.on.rectangle",
              id + [renderer.with(default: "Metal", choices: ["Metal", TemplateChoice("Metal 4", unavailable: metal4Unavailable)]),
                    TemplateOptionField(ID.immersiveSpace, "Immersive Space", .popUp(["Progressive", "Full"]), default: "Full"),
                    TemplateFields.testing], "unavailable",
              unavailable: "SwiftCode cannot create this template yet: it has no remote immersive-space renderer."),
            d(mac, appSection, "Command Line Tool", 50, "A command-line tool (Swift, Objective-C, C++ or C)", "terminal",
              id + [TemplateFields.language.with(choices: ["Swift", "Objective-C", "C++", "C"])], "commandLineTool"),
            d(mac, appSection, "Safari Extension App", nil, "A macOS app with a Safari web or app extension", "globe",
              id + [TemplateOptionField(ID.safariExtensionType, "Type", .popUp([
                        TemplateChoice("Safari App Extension", unavailable: "SwiftCode writes Safari Web Extensions only."), "Safari Web Extension",
                    ]), default: "Safari Web Extension"), swiftOnlyLanguage, TemplateFields.testing], "safariExtensionApp"),
            d(mac, lib, "Framework", 1, "A macOS framework", "shippingbox", id + libraryLanguage, "framework"),
            d(mac, lib, "Library", 10, "A dynamic or static library (Cocoa, C++ STL or plain C)", "building.columns",
              id + [TemplateOptionField(ID.libraryFramework, "Framework", .popUp(["Cocoa", TemplateChoice("STL", title: "STL (C++ Library)"),
                                                                                 TemplateChoice("None", title: "None (Plain C/C++ Library)")]), default: "Cocoa"),
                    TemplateOptionField(ID.libraryType, "Type", .popUp(["Dynamic", "Static"]), default: "Dynamic")], "library"),
            d(mac, lib, "XPC Service", 100, "An XPC service bundle", "point.3.connected.trianglepath.dotted",
              id + [swiftOnlyLanguage, TemplateOptionField(ID.apiLevel, "API Level", .popUp([
                  TemplateChoice("Low Level", title: "Low Level - libXPC"), TemplateChoice("High Level", title: "High Level - NSXPCConnection"),
              ]), default: "High Level")], "xpcService"),
            d(mac, lib, "Bundle", 101, "A loadable bundle with a chosen extension", "archivebox",
              id + [TemplateOptionField(ID.bundleExtension, "Bundle Extension", .text, default: "bundle")], "bundle"),
            d(mac, lib, "Metal Library", nil, "A standalone .metallib", "cube", [TemplateFields.productName, TemplateFields.team], "metalLibrary"),
            d(mac, "Other", "Generic Kernel Extension", nil, "A C kernel extension", "cpu", id, "kernelExtension"),
            d(mac, "Other", "IOKit Driver", nil, "A C++ IOKit kernel extension", "cpu.fill", id, "iokitDriver"),
            d(mac, "Other", "Installer Plug-in", nil, "An Installer pane plug-in", "shippingbox.and.arrow.backward", id, "installerPlugin"),
            d(mac, "Other", "Instruments Package", nil, "An Instruments package", "gauge.with.dots.needle.33percent", id, "instrumentsPackage"),
            d(mac, "Other", "Preference Pane", nil, "A System Settings pane bundle", "gearshape", id, "preferencePane"),
            d(mac, "Other", "Screen Saver", nil, "A screen saver bundle", "sparkles.tv", id, "screenSaver"),
        ]
        out += [
            d(watch, appSection, "App", 1, "A watchOS app, alone or with a companion iOS app", "timer",
              id + [TemplateOptionField(ID.watchAppType, "Create Companion iOS App", .popUp([
                        "Watch-only App", "Watch App with New Companion iOS App",
                        TemplateChoice("Watch App for Existing iOS App", unavailable: "Use File ▸ New ▸ Target… in a project with an iOS app."),
                    ]), default: "Watch-only App"), TemplateFields.swiftLanguage, TemplateFields.testing], "watchApp"),
            d(watch, lib, "Framework", 1, "A watchOS framework", "shippingbox", id + [TemplateFields.documentation, TemplateFields.language,
                                                                                       TemplateFields.unitTesting], "framework"),
            d(watch, lib, "Static Library", 10, "A watchOS static library", "building.columns", id + [TemplateFields.language, TemplateFields.unitTesting],
              "staticLibrary"),
        ]
        out += [
            d(tv, appSection, "App", 1, "A tvOS app (SwiftUI or storyboard)", "tv", appFields, "app"),
            d(tv, appSection, "Game", 10, "A tvOS game (RealityKit, SceneKit, SpriteKit, Metal 4 or Metal)", "gamecontroller",
              id + [gameType(["RealityKit", "SceneKit", "SpriteKit", "Metal 4", "Metal"], default: "RealityKit", swiftRealityKit: true), integrateGK,
                    swiftOnlyLanguage, TemplateFields.testing], "game"),
            d(tv, lib, "Framework", 1, "A tvOS framework", "shippingbox", id + libraryLanguage, "framework"),
            d(tv, lib, "Static Library", 10, "A tvOS static library", "building.columns", id + [TemplateFields.language], "staticLibrary"),
            d(tv, lib, "Metal Library", nil, "A standalone .metallib", "cube", [TemplateFields.productName, TemplateFields.team], "metalLibrary"),
        ]
        out += [
            d(vision, appSection, "App", 1, "A visionOS app with a window or a volume, and optionally an immersive space", "cube.transparent",
              id + [TemplateOptionField(ID.initialScene, "Initial Scene", .popUp(["Window", "Volume"]), default: "Window"), renderer, immersion,
                    TemplateFields.swiftLanguage, TemplateFields.unitTesting], "visionApp"),
            d(vision, appSection, "Immersive Environment App", 1, "A visionOS app that opens a full or progressive environment", "mountain.2",
              id + [TemplateOptionField(ID.immersiveSpace, "Immersive Space", .popUp(["Progressive", "Full"]), default: "Full"),
                    TemplateFields.swiftLanguage, TemplateFields.unitTesting], "immersiveEnvironmentApp"),
            d(vision, lib, "Framework", 1, "A visionOS framework", "shippingbox", id + libraryLanguage, "framework"),
            d(vision, lib, "Static Library", 10, "A visionOS static library", "building.columns", id + [TemplateFields.language], "staticLibrary"),
        ]
        out += [
            d(dk, "Driver", "Driver", nil, "A DriverKit driver extension", "cpu", id, "driver"),
            d(dk, lib, "Framework", 1, "A DriverKit framework", "shippingbox",
              id + [TemplateFields.documentation, TemplateFields.language.with(forced: "Objective-C")], "framework"),
            d(dk, lib, "Library", 10, "A DriverKit dynamic or static library", "building.columns",
              id + [TemplateOptionField(ID.libraryType, "Type", .popUp(["Dynamic", "Static"]), default: "Dynamic")], "driverKitLibrary"),
        ]
        out += [
            d("Other", "", "Empty", nil, "A project with no targets", "doc", [TemplateFields.productName, TemplateFields.team], "empty"),
            d("Other", "", "External Build System", nil, "A legacy target that runs a build tool", "hammer",
              id + [TemplateOptionField(ID.buildTool, "Build Tool", .text, default: "/usr/bin/make", required: true)], "externalBuildSystem"),
        ]
        
        out += [
            d(mp, appSection, "SwiftUI Starter", 2, "Opinionated SwiftUI app with onboarding, settings & persistence wired", "sparkles",
              id + [TemplateFields.testing, TemplateFields.storage, TemplateFields.cloudKit], "app"),
            d(mp, appSection, "MVVM Tabs App", 3, "Tab-based SwiftUI app with MVVM folders, router & previews", "square.grid.2x2",
              id + [TemplateFields.testing, TemplateFields.storage], "app"),
            d(mp, appSection, "TCA Starter", 4, "Composable Architecture starter with reducer, scope & tests", "arrow.triangle.branch",
              id + [TemplateFields.testing], "app"),
            d(mp, appSection, "VIPER Starter", 5, "VIPER modules, router, entities & unit tests", "square.split.2x2",
              id + [TemplateFields.testing], "app"),
            d(mp, appSection, "Clean Architecture", 6, "Domain / Data / Presentation layers with DI & mocks", "building.columns",
              id + [TemplateFields.testing], "app"),
            d(mp, appSection, "Onboarding Flow", 7, "Paywall-style onboarding, feature flags & analytics hooks", "wand.and.stars",
              id + [TemplateFields.testing], "app"),
            d(mp, appSection, "Chat App", 20, "Realtime chat UI with channels, presence & push stubs", "bubble.left.and.bubble.right",
              id + [TemplateFields.testing, TemplateFields.storage], "app"),
            d(mp, appSection, "Notes App", 21, "Markdown notes with tags, search & iCloud sync stub", "note.text",
              id + [TemplateFields.testing, TemplateFields.storage, TemplateFields.cloudKit], "documentApp"),
            d(mp, appSection, "Todo + Widgets", 22, "Tasks with WidgetKit, App Intents & live activities", "checklist",
              id + [TemplateFields.testing, TemplateFields.storage], "app"),
            d(mp, appSection, "HealthKit App", 23, "HealthKit onboarding, charts & background delivery stubs", "heart.fill",
              id + [TemplateFields.testing], "app"),
            d(mp, appSection, "Map Explorer", 24, "MapKit + search, POIs, routes & offline cache stub", "map",
              id + [TemplateFields.testing], "app"),
            d(mp, appSection, "Media Player", 25, "AVKit player with PiP, chapters & background audio", "play.tv",
              id + [TemplateFields.testing], "app"),
            d(mp, appSection, "Weather App", 26, "WeatherKit client with widgets & location stub", "cloud.sun.fill",
              id + [TemplateFields.testing], "app"),
            d(mp, appSection, "Finance Tracker", 27, "Charts, budgets, CSV import & SwiftData models", "chart.bar.fill",
              id + [TemplateFields.testing, TemplateFields.storage], "app"),
            d(mp, appSection, "E-Commerce", 28, "Catalog, cart, checkout & StoreKit 2 stub", "cart.fill",
              id + [TemplateFields.testing, TemplateFields.storage], "app"),
            d(mp, appSection, "Social Feed", 29, "Feed, composer, likes & image cache stub", "person.2.fill",
              id + [TemplateFields.testing], "app"),
            d(mp, appSection, "AI Chat Starter", 40, "Streaming chat UI wired for OpenAI / local models", "brain",
              id + [TemplateFields.testing], "app"),
            d(mp, appSection, "Vision Pro Companion", 41, "iOS + visionOS immersive space starter", "visionpro",
              id + [TemplateFields.testing], "visionApp"),
            d(mp, appSection, "Menu Bar App", 42, "Menu-bar extra with popover, settings & launch-at-login", "menubar.rectangle",
              id + [TemplateFields.testing], "app"),
        ]
        out += [
            d(ios, appSection, "SwiftUI Starter", 2, "iOS SwiftUI starter with router, DI & persistence", "sparkles",
              appFields, "app"),
            d(ios, appSection, "UIKit Starter", 3, "UIKit + storyboards with coordinators", "square.stack",
              id + [TemplateFields.language.with(choices: ["Swift", "Objective-C"]), TemplateFields.testing], "app"),
            d(ios, appSection, "Tabbed App", 4, "Tab bar with 4 tabs, deep links & badges", "square.grid.2x2.fill",
              appFields, "app"),
            d(ios, appSection, "Master-Detail", 5, "Split-view master/detail with search", "sidebar.left",
              appFields, "documentApp"),
            d(ios, appSection, "Camera App", 20, "AVFoundation camera with filters & photo library", "camera.fill",
              id + [TemplateFields.testing], "app"),
            d(ios, appSection, "Chat App", 21, "Messages UI with input bar & attachments", "bubble.left.fill",
              appFields, "app"),
            d(ios, appSection, "Fitness App", 22, "Workouts, rings & HealthKit stub", "figure.run",
              appFields, "app"),
            d(ios, appSection, "Music Player", 23, "Library, now-playing & background audio stub", "music.note",
              appFields, "app"),
            d(ios, appSection, "Widget Extension App", 30, "App + WidgetKit + App Intents", "widget.small",
              id + [swiftOnlyLanguage], "app"),
            d(ios, appSection, "Share Extension App", 31, "App + share extension target", "square.and.arrow.up",
              id + [swiftOnlyLanguage], "app"),
            d(ios, appSection, "Notification Service App", 32, "App + notification service & content extensions", "bell.badge.fill",
              id + [swiftOnlyLanguage], "app"),
            d(ios, lib, "Swift Package Plug-in", 2, "iOS framework with SPM resources & tests", "shippingbox.fill",
              id + libraryLanguage, "framework"),
            d(ios, lib, "XCFramework", 3, "Binary xcframework distribution stub", "archivebox.fill",
              id + libraryLanguage, "framework"),
        ]
        out += [
            d(mac, appSection, "SwiftUI Starter", 2, "macOS SwiftUI starter with sidebar & inspector", "sparkles",
              id + [TemplateFields.interface.with(choices: ["SwiftUI", "Storyboard", "XIB"]), TemplateFields.lifecycle, TemplateFields.appLanguage, TemplateFields.testing, TemplateFields.storage], "app"),
            d(mac, appSection, "Document Editor", 2, "Multi-window document editor with versions & autosave", "doc.fill",
              id + [TemplateFields.interface.with(choices: ["SwiftUI", "Storyboard", "XIB"]), TemplateFields.lifecycle, swiftOnlyLanguage, TemplateFields.testing, documentStorage(true)], "documentApp"),
            d(mac, appSection, "Menu Bar App", 20, "Status-item app with popover & preferences", "menubar.rectangle",
              id + [TemplateFields.testing], "app"),
            d(mac, appSection, "Finder Sync App", 21, "Finder Sync extension + container app", "folder.badge.plus",
              id + [swiftOnlyLanguage], "app"),
            d(mac, appSection, "QuickLook Preview App", 22, "Quick Look preview + thumbnail extensions", "eye.fill",
              id + [swiftOnlyLanguage], "app"),
            d(mac, appSection, "Spotlight Importer App", 23, "Spotlight importer + host app", "magnifyingglass",
              id + [swiftOnlyLanguage], "app"),
            d(mac, appSection, "Launch Agent Daemon", 50, "LaunchAgent + XPC service + CLI", "gearshape.2.fill",
              id + [TemplateFields.language.with(choices: ["Swift", "C++", "C"])], "commandLineTool"),
            d(mac, appSection, "Developer Tool", 51, "SwiftPM-based CLI with subcommands & man page", "hammer.fill",
              id + [TemplateFields.language], "commandLineTool"),
            d(mac, lib, "Privileged Helper", 102, "SMJobBless helper + XPC interface", "lock.shield.fill",
              id + [swiftOnlyLanguage], "xpcService"),
            d(mac, lib, "QuickLook Extension", 103, "Quick Look preview extension target", "eye",
              id + [swiftOnlyLanguage], "bundle"),
            d(mac, "Other", "Status Bar Panel", nil, "Borderless panel for menu-bar UI", "panel.top",
              id, "bundle"),
            d(mac, "Other", "Print Plugin", nil, "Print dialog extension stub", "printer.fill",
              id, "bundle"),
        ]
        out += [
            d(watch, appSection, "Fitness Companion", 2, "Workouts + complications + iOS sync", "heart.circle.fill",
              id + [TemplateFields.swiftLanguage, TemplateFields.testing], "watchApp"),
            d(tv, appSection, "Streaming App", 2, "TVML-style catalog, player & Top Shelf", "play.tv.fill",
              appFields, "app"),
            d(vision, appSection, "Tabletop Starter", 2, "Volume-anchored tabletop scene + gestures", "cube.fill",
              id + [TemplateOptionField(ID.initialScene, "Initial Scene", .popUp(["Window", "Volume"]), default: "Volume"), renderer, immersion, TemplateFields.swiftLanguage, TemplateFields.unitTesting], "visionApp"),
            d(vision, appSection, "Media Viewer", 3, "Immersive media space with portals", "photo.on.rectangle",
              id + [renderer, immersion, TemplateFields.swiftLanguage, TemplateFields.unitTesting], "immersiveEnvironmentApp"),
        ]
        out += [
            // Multiplatform additions
            d(mp, appSection, "SwiftData Document App", 2, "A multiplatform document app stored in SwiftData", "doc.richtext",
              id + [documentStorage(false).with(default: "SwiftData"), TemplateFields.testing], "documentApp"),
            d(mp, appSection, "Metal Game", 11, "A multiplatform game rendered with Metal", "cube",
              id + [gameType(["RealityKit", "SceneKit", "SpriteKit", "Metal 4", "Metal"], default: "Metal"), swiftOnlyLanguage,
                    platform(ID.iOSPlatform, "Include iOS Application"),
                    platform(ID.visionOSPlatform, "Include visionOS Application", requires: [.is(ID.gameTechnology, "RealityKit")]),
                    platform(ID.tvOSPlatform, "Include tvOS Application", requires: [.is(ID.iOSPlatform, "true")]),
                    platform(ID.macOSPlatform, "Include macOS Application")], "game"),
            d(mp, lib, "Static Library", 10, "A multiplatform static library", "building.columns",
              id + [TemplateFields.language, TemplateFields.unitTesting], "staticLibrary"),
            d(mp, lib, "Objective-C Framework", 20, "A multiplatform framework written in Objective-C", "shippingbox",
              id + [TemplateFields.language.with(default: "Objective-C"), TemplateFields.unitTesting, TemplateFields.documentation], "framework"),
            d(mp, lib, "Resource Bundle", 30, "A multiplatform resource bundle", "shippingbox.fill",
              id + [TemplateOptionField(ID.bundleExtension, "Bundle Extension", .text, default: "bundle")], "bundle"),
        ]
        out += [
            // iOS application additions
            d(ios, appSection, "UIKit App", 6, "An iOS app built with UIKit storyboards (Swift or Objective-C)", "apps.iphone",
              id + [TemplateFields.interface.with(forced: "Storyboard"), TemplateFields.appLanguage, TemplateFields.testing,
                    TemplateFields.storage, TemplateFields.cloudKit], "app"),
            d(ios, appSection, "Objective-C App", 7, "An iOS app written in Objective-C with storyboards", "apps.iphone",
              id + [TemplateFields.interface.with(forced: "Storyboard"), TemplateFields.appLanguage.with(forced: "Objective-C"),
                    TemplateFields.testing], "app"),
            d(ios, appSection, "SceneKit AR App", 13, "An iOS AR app using SceneKit (deprecated but supported)", "arkit",
              id + [TemplateOptionField(ID.contentTechnology, "Content Technology", .popUp([
                        "RealityKit", TemplateChoice("SceneKit", title: "SceneKit (Deprecated)"), "SpriteKit",
                        TemplateChoice("Metal", unavailable: "SwiftCode has no AR Metal renderer yet."),
                    ]), default: "SceneKit"),
                    TemplateFields.interface.with(choices: [TemplateChoice("SwiftUI", requires: [.is(ID.contentTechnology, "RealityKit")]),
                                                            TemplateChoice("Storyboard", requires: [.not(ID.contentTechnology, "RealityKit")])]),
                    swiftOnlyLanguage, TemplateFields.testing], "arApp"),
            d(ios, appSection, "Document Browser", 3, "An iOS document-browser app for custom file types", "doc.text.magnifyingglass",
              id + [TemplateFields.interface.with(choices: ["SwiftUI", TemplateChoice("Storyboard", title: "UIKit")]), TemplateFields.lifecycle,
                    swiftOnlyLanguage, TemplateFields.testing, documentStorage(false).with(default: "SwiftData")], "documentApp"),
            d(ios, appSection, "Journal App", 14, "A SwiftUI journaling app with entries, tags and search", "book.closed",
              appFields, "app", save: "My Journal"),
            d(ios, appSection, "Recipe Box", 15, "A recipe manager with ingredients, steps and favorites", "book",
              id + [TemplateFields.testing, TemplateFields.storage.with(default: "SwiftData"), TemplateFields.cloudKit], "app", save: "My Recipes"),
            d(ios, appSection, "Habit Tracker", 16, "A streak-based habit tracker with weekly charts", "repeat",
              appFields, "app"),
            d(ios, appSection, "Plant Care", 17, "A plant-care scheduler with watering reminders", "leaf.fill",
              appFields, "app"),
            d(ios, appSection, "Sleep Tracker", 18, "A sleep log with bedtime goals and trends", "bed.double.fill",
              appFields, "app"),
            d(ios, appSection, "Language Learning", 19, "Flashcards and quizzes for vocabulary practice", "character.book.closed.fill",
              appFields, "app"),
            d(ios, appSection, "QR Code Scanner", 27, "A camera app that scans and decodes QR codes", "qrcode.viewfinder",
              id + [TemplateFields.testing], "app"),
        ]
        out += [
            // iOS framework & library additions
            d(ios, lib, "Objective-C Framework", 20, "An iOS framework written in Objective-C", "shippingbox",
              id + [TemplateFields.language.with(default: "Objective-C"), TemplateFields.unitTesting, TemplateFields.documentation], "framework"),
            d(ios, lib, "Objective-C Static Library", 11, "An iOS static library written in Objective-C", "building.columns",
              id + [TemplateFields.language.with(default: "Objective-C")], "staticLibrary"),
            d(ios, lib, "Resource Bundle", 12, "A bundle of resources for an iOS app", "shippingbox.fill",
              id + [TemplateOptionField(ID.bundleExtension, "Bundle Extension", .text, default: "bundle")], "bundle"),
        ]
        out += [
            // macOS application additions
            d(mac, appSection, "Cocoa App", 3, "A macOS app with a Cocoa storyboard interface", "macwindow",
              id + [TemplateFields.interface.with(forced: "Storyboard"), TemplateFields.appLanguage, TemplateFields.testing,
                    TemplateFields.storage, TemplateFields.cloudKit], "app"),
            d(mac, appSection, "Objective-C Cocoa App", 4, "A macOS Cocoa app written in Objective-C", "macwindow",
              id + [TemplateFields.interface.with(forced: "Storyboard"), TemplateFields.appLanguage.with(forced: "Objective-C"),
                    TemplateFields.testing], "app"),
            d(mac, appSection, "XIB App", 5, "A macOS app built around a XIB interface", "macwindow",
              id + [TemplateFields.interface.with(forced: "XIB"), TemplateFields.appLanguage, TemplateFields.testing], "app"),
            d(mac, appSection, "Core Data Document Editor", 3, "A macOS document editor backed by Core Data", "doc.richtext",
              id + [TemplateFields.interface.with(forced: "Storyboard"), TemplateFields.lifecycle, swiftOnlyLanguage,
                    TemplateFields.testing, documentStorage(true).with(default: "Core Data")], "documentApp"),
            d(mac, appSection, "Pomodoro Timer", 24, "A focus timer with work/break cycles and stats", "timer.circle.fill",
              id + [TemplateFields.interface.with(choices: ["SwiftUI", "Storyboard", "XIB"]), TemplateFields.lifecycle,
                    TemplateFields.appLanguage, TemplateFields.testing, TemplateFields.storage], "app"),
            d(mac, appSection, "Markdown Editor", 25, "A multi-window markdown editor with preview", "doc.richtext.fill",
              id + [TemplateFields.testing, TemplateFields.storage], "app"),
            d(mac, appSection, "Unit Converter", 26, "A measurement converter with categories and favorites", "arrow.left.arrow.right.circle.fill",
              appFields, "app"),
            d(mac, appSection, "Stock Ticker", 27, "A market watchlist with quotes and sparklines", "chart.line.uptrend.xyaxis",
              appFields, "app"),
            d(mac, appSection, "Recipe Manager", 28, "A recipe organizer with shopping lists", "menucard",
              appFields, "app"),
            d(mac, appSection, "Reading List", 29, "A reading list with progress tracking", "books.vertical.fill",
              appFields, "app"),
            d(mac, appSection, "C Command Line Tool", 51, "A command-line tool written in C", "terminal",
              id + [TemplateFields.language.with(forced: "C")], "commandLineTool"),
            d(mac, appSection, "C++ Command Line Tool", 52, "A command-line tool written in C++", "terminal.fill",
              id + [TemplateFields.language.with(forced: "C++")], "commandLineTool"),
            d(mac, appSection, "Objective-C Command Line Tool", 53, "A command-line tool written in Objective-C", "terminal.badge.plus",
              id + [TemplateFields.language.with(forced: "Objective-C")], "commandLineTool"),
        ]
        out += [
            // macOS framework & library additions
            d(mac, lib, "Objective-C Framework", 20, "A macOS framework written in Objective-C", "shippingbox",
              id + [TemplateFields.language.with(default: "Objective-C"), TemplateFields.unitTesting, TemplateFields.documentation], "framework"),
            d(mac, lib, "C++ Dynamic Library", 11, "A C++ shared library using the STL", "shippingbox.fill",
              id + [TemplateOptionField(ID.libraryFramework, "Framework", .popUp(["Cocoa", TemplateChoice("STL", title: "STL (C++ Library)"),
                                                                                 TemplateChoice("None", title: "None (Plain C/C++ Library)")]), default: "STL").with(forced: "STL"),
                    TemplateOptionField(ID.libraryType, "Type", .popUp(["Dynamic", "Static"]), default: "Dynamic")], "library"),
            d(mac, lib, "C++ Static Library", 12, "A C++ static library using the STL", "building.columns.fill",
              id + [TemplateOptionField(ID.libraryFramework, "Framework", .popUp(["Cocoa", TemplateChoice("STL", title: "STL (C++ Library)"),
                                                                                 TemplateChoice("None", title: "None (Plain C/C++ Library)")]), default: "STL").with(forced: "STL"),
                    TemplateOptionField(ID.libraryType, "Type", .popUp(["Dynamic", "Static"]), default: "Static")], "library"),
            d(mac, lib, "Objective-C Static Library", 13, "A macOS static library written in Objective-C", "building.columns",
              id + [TemplateFields.language.with(default: "Objective-C")], "staticLibrary"),
            d(mac, lib, "Low-Level XPC Service", 102, "An XPC service using libXPC directly", "point.3.connected.trianglepath.dotted",
              id + [TemplateOptionField(ID.apiLevel, "API Level", .popUp([
                  TemplateChoice("Low Level", title: "Low Level - libXPC"), TemplateChoice("High Level", title: "High Level - NSXPCConnection"),
              ]), default: "Low Level").with(forced: "Low Level")], "xpcService"),
        ]
        out += [
            // macOS other additions
            d(mac, "Other", "Quick Look Preview Plug-in", nil, "A Quick Look preview generator bundle", "eye.square",
              id + [TemplateOptionField(ID.bundleExtension, "Bundle Extension", .text, default: "qlgenerator")], "bundle"),
            d(mac, "Other", "Spotlight Importer Plug-in", nil, "A Spotlight metadata importer bundle", "magnifyingglass.circle",
              id + [TemplateOptionField(ID.bundleExtension, "Bundle Extension", .text, default: "mdimporter")], "bundle"),
            d(mac, "Other", "Automator Action Plug-in", nil, "An Automator action bundle", "gearshape.2",
              id + [TemplateOptionField(ID.bundleExtension, "Bundle Extension", .text, default: "action")], "bundle"),
        ]
        out += [
            // watchOS additions
            d(watch, appSection, "Companion App", 2, "A watchOS app with a new companion iOS app", "applewatch",
              id + [TemplateOptionField(ID.watchAppType, "Create Companion iOS App", .popUp([
                        "Watch-only App", "Watch App with New Companion iOS App",
                        TemplateChoice("Watch App for Existing iOS App", unavailable: "Use File ▸ New ▸ Target… in a project with an iOS app."),
                    ]), default: "Watch App with New Companion iOS App"),
                    TemplateFields.swiftLanguage, TemplateFields.testing], "watchApp"),
            d(watch, lib, "Objective-C Framework", 20, "A watchOS framework written in Objective-C", "shippingbox",
              id + [TemplateFields.language.with(default: "Objective-C"), TemplateFields.unitTesting, TemplateFields.documentation], "framework"),
            d(watch, lib, "Objective-C Static Library", 11, "A watchOS static library written in Objective-C", "building.columns",
              id + [TemplateFields.language.with(default: "Objective-C")], "staticLibrary"),
        ]
        out += [
            // tvOS additions
            d(tv, appSection, "UIKit App", 2, "A tvOS app built with UIKit storyboards", "tv",
              id + [TemplateFields.interface.with(forced: "Storyboard"), TemplateFields.lifecycle, TemplateFields.appLanguage,
                    TemplateFields.testing, TemplateFields.storage, TemplateFields.cloudKit], "app"),
            d(tv, appSection, "Arcade Game", 11, "A tvOS game with SpriteKit and GameplayKit", "gamecontroller.fill",
              id + [gameType(["RealityKit", "SceneKit", "SpriteKit", "Metal 4", "Metal"], default: "SpriteKit", swiftRealityKit: true), integrateGK,
                    swiftOnlyLanguage, TemplateFields.testing], "game"),
            d(tv, lib, "Objective-C Framework", 20, "A tvOS framework written in Objective-C", "shippingbox",
              id + [TemplateFields.language.with(default: "Objective-C"), TemplateFields.unitTesting, TemplateFields.documentation], "framework"),
            d(tv, lib, "Objective-C Static Library", 11, "A tvOS static library written in Objective-C", "building.columns",
              id + [TemplateFields.language.with(default: "Objective-C")], "staticLibrary"),
        ]
        out += [
            // visionOS additions
            d(vision, appSection, "Metal Immersive App", 2, "A visionOS app with a Metal-rendered immersive space", "cube.fill",
              id + [TemplateOptionField(ID.initialScene, "Initial Scene", .popUp(["Window", "Volume"]), default: "Window"),
                    renderer.with(default: "Metal"), immersion,
                    TemplateFields.swiftLanguage, TemplateFields.unitTesting], "visionApp"),
            d(vision, lib, "Objective-C Framework", 20, "A visionOS framework written in Objective-C", "shippingbox",
              id + [TemplateFields.language.with(default: "Objective-C"), TemplateFields.unitTesting, TemplateFields.documentation], "framework"),
            d(vision, lib, "Objective-C Static Library", 11, "A visionOS static library written in Objective-C", "building.columns",
              id + [TemplateFields.language.with(default: "Objective-C")], "staticLibrary"),
        ]
        out += [
            // DriverKit additions
            d(dk, "Driver", "User-Space Driver", nil, "A DriverKit driver for user-space devices", "cpu",
              id, "driver"),
            d(dk, lib, "Static Library", 11, "A DriverKit static library", "building.columns",
              id + [TemplateOptionField(ID.libraryType, "Type", .popUp(["Dynamic", "Static"]), default: "Static")], "driverKitLibrary"),
        ]
        out += [
            // Other additions: external build systems
            d("Other", "", "CMake Build System", nil, "A project whose targets run CMake", "shippingbox.and.arrow.backward",
              id + [TemplateOptionField(ID.buildTool, "Build Tool", .text, default: "cmake", required: true)], "externalBuildSystem"),
            d("Other", "", "Bazel Build System", nil, "A project whose targets run Bazel", "shippingbox.and.arrow.backward",
              id + [TemplateOptionField(ID.buildTool, "Build Tool", .text, default: "bazel", required: true)], "externalBuildSystem"),
            d("Other", "", "XcodeGen Build System", nil, "A project whose targets run XcodeGen", "shippingbox.and.arrow.backward",
              id + [TemplateOptionField(ID.buildTool, "Build Tool", .text, default: "xcodegen", required: true)], "externalBuildSystem"),
        ]
        out += [
            // 50 New Templates
            // Multiplatform (10)
            d(mp, appSection, "CloudKit Sync Starter", 12, "Multiplatform app with CloudKit container sync and offline conflict resolution", "icloud.and.arrow.down",
              id + [TemplateFields.testing, TemplateFields.storage, TemplateFields.cloudKit], "app"),
            d(mp, appSection, "SwiftData Model Container", 13, "Multiplatform data app with hierarchical schema migrations and SwiftData models", "cylinder.split.1x2",
              id + [documentStorage(false).with(default: "SwiftData"), TemplateFields.testing], "documentApp"),
            d(mp, appSection, "Live Activity Dashboard", 14, "Multiplatform tracking app with Dynamic Island and Lock Screen widgets", "chart.line.uptrend.xyaxis.circle",
              id + [TemplateFields.testing, TemplateFields.storage], "app"),
            d(mp, appSection, "Audio Engine Studio", 31, "AVAudioEngine node graph synthesizer with low latency DSP effects", "waveform.path.ecg",
              id + [TemplateFields.testing], "app"),
            d(mp, appSection, "Bluetooth BLE Central", 32, "CoreBluetooth central manager with background peripheral discovery", "antenna.radiowaves.left.and.right",
              id + [TemplateFields.testing], "app"),
            d(mp, appSection, "PDF Annotation Reader", 33, "PDFKit document viewer with handwritten Apple Pencil & ink support", "pencil.and.outline",
              id + [TemplateFields.testing, documentStorage(false)], "documentApp"),
            d(mp, appSection, "Keychain Secure Vault", 34, "Biometric LocalAuthentication vault with hardware Enclave storage", "lock.shield",
              id + [TemplateFields.testing], "app"),
            d(mp, appSection, "StoreKit In-App Purchases", 35, "StoreKit 2 subscriptions, entitlements, and consumable products", "creditcard",
              id + [TemplateFields.testing, TemplateFields.storage], "app"),
            d(mp, appSection, "SharePlay Group Activities", 36, "Real-time synchronized GroupActivities session for collaborative editing", "shareplay",
              id + [TemplateFields.testing], "app"),
            d(mp, appSection, "App Intents Siri Shortcut", 37, "Interactive App Intents with parameterized voice queries and Focus filters", "mic.badge.plus",
              id + [TemplateFields.testing], "app"),

            // iOS (10)
            d(ios, appSection, "Dynamic Island Tracker", 33, "ActivityKit live delivery tracker with minimal and expanded island views", "capsule.portrait",
              id + [swiftOnlyLanguage], "app"),
            d(ios, appSection, "NFC Tag Reader", 34, "CoreNFC tag reader and writer supporting NDEF payloads and ISO 7816 tags", "wave.3.forward",
              id + [TemplateFields.testing], "app"),
            d(ios, appSection, "Vision Face Tracking", 35, "Vision framework facial landmark detection with real-time bounding boxes", "face.dashed",
              id + [TemplateFields.testing], "app"),
            d(ios, appSection, "Speech Recognition Assistant", 36, "Speech framework real-time dictation with on-device speech recognizer", "waveform.badge.mic",
              id + [TemplateFields.testing], "app"),
            d(ios, appSection, "Core Motion Pedometer", 37, "Step counter, cadence tracker, and motion activity classifier", "figure.walk",
              id + [TemplateFields.testing], "app"),
            d(ios, appSection, "Vision Text Scanner", 38, "Real-time camera optical character recognition with Data Scanner", "text.viewfinder",
              id + [TemplateFields.testing], "app"),
            d(ios, appSection, "CoreML Image Classifier", 39, "MobileNet on-device image classification with live camera feed", "brain.head.profile",
              id + [TemplateFields.testing], "app"),
            d(ios, appSection, "PencilKit Sketchbook", 40, "Drawing canvas with undo/redo, color picker, and stroke serialization", "paintbrush.pointed",
              id + [TemplateFields.testing, documentStorage(false)], "documentApp"),
            d(ios, appSection, "TipKit Feature Discovery", 41, "Contextual onboarding tips with trigger rules and eligibility tracking", "lightbulb",
              id + [TemplateFields.testing], "app"),
            d(ios, appSection, "CallKit Audio Caller", 42, "VoIP background receiver with native incoming call UI", "phone.arrow.down.left",
              id + [swiftOnlyLanguage], "app"),

            // macOS (10)
            d(mac, appSection, "Virtualization Sandbox", 30, "Apple Virtualization framework Linux/macOS guest VM launcher", "laptopcomputer.and.ipad",
              id + [TemplateFields.testing], "app"),
            d(mac, "Other", "Finder Quick Action", nil, "Service bundle providing contextual file transformation actions", "sparkle.magnifyingglass",
              id, "bundle"),
            d(mac, "Other", "File Provider Extension", nil, "Cloud storage integration syncing remote items into Finder", "folder.badge.gearshape",
              id, "bundle"),
            d(mac, appSection, "Endpoint Security Monitor", 54, "System extension monitoring process exec, fork, and file events", "shield.lefthalf.filled",
              id + [TemplateFields.language], "commandLineTool"),
            d(mac, "Other", "Network Content Filter", nil, "NetworkExtension system extension filtering outbound traffic", "network.badge.shield.half.filled",
              id, "bundle"),
            d(mac, appSection, "Metal Compute Pipeline", 31, "MPS and compute kernel shader dispatcher with GPU profiling", "computerminus",
              id + [TemplateFields.testing], "app"),
            d(mac, appSection, "Accessibility VoiceOver Helper", 32, "NSAccessibility element inspection and automation bridge", "accessibility",
              id + [TemplateFields.testing], "app"),
            d(mac, appSection, "Global Shortcut Manager", 33, "Carbon and CGEventTap hotkey listener with background dispatch", "command",
              id + [TemplateFields.testing], "app"),
            d(mac, appSection, "Touch Bar Customizer", 34, "Customizable NSTouchBar controls with dynamic scrubber items", "menubar.dock.rectangle",
              id + [TemplateFields.testing], "app"),
            d(mac, appSection, "Screen Capture Recorder", 35, "ScreenCaptureKit high performance display and audio stream recorder", "record.circle",
              id + [TemplateFields.testing], "app"),

            // visionOS (8)
            d(vision, appSection, "Spatial Object Manipulator", 4, "RealityKit entity with Drag, Rotate, Scale and physics gestures", "hand.draw",
              id + [renderer, immersion, TemplateFields.swiftLanguage, TemplateFields.unitTesting], "visionApp"),
            d(vision, appSection, "Spatial Audio Soundstage", 5, "Positional 3D spatial audio environment with room acoustics", "speaker.wave.3",
              id + [renderer, immersion, TemplateFields.swiftLanguage, TemplateFields.unitTesting], "visionApp"),
            d(vision, appSection, "Portal to Immersive World", 6, "RealityKit portal effect transitioning from volume to full space", "circle.circle",
              id + [renderer, immersion, TemplateFields.swiftLanguage, TemplateFields.unitTesting], "immersiveEnvironmentApp"),
            d(vision, appSection, "Hover Effect Gallery", 7, "Volumetric UI components with eye-tracking hover states and glow", "sparkles.tv",
              id + [renderer, immersion, TemplateFields.swiftLanguage, TemplateFields.unitTesting], "visionApp"),
            d(vision, appSection, "Hand Tracking Instrument", 8, "ARKit hand joints tracking with pinch-gesture musical triggers", "hand.point.up.left",
              id + [renderer, immersion, TemplateFields.swiftLanguage, TemplateFields.unitTesting], "visionApp"),
            d(vision, appSection, "Polymer Material Shader", 9, "RealityKit custom shader graph material with iridescence", "paintpalette",
              id + [renderer, immersion, TemplateFields.swiftLanguage, TemplateFields.unitTesting], "visionApp"),
            d(vision, appSection, "RealityView Particle System", 10, "Particle emitter components with gravity, turbulence, and lifetime", "sun.snow",
              id + [renderer, immersion, TemplateFields.swiftLanguage, TemplateFields.unitTesting], "visionApp"),
            d(vision, appSection, "Anchored World Landmark", 11, "Plane detection and geographic image anchor placement", "mappin.and.ellipse",
              id + [renderer, immersion, TemplateFields.swiftLanguage, TemplateFields.unitTesting], "visionApp"),

            // watchOS (5)
            d(watch, appSection, "Workout Session Tracker", 3, "HKWorkoutSession with heart rate zones, calories, and outdoor GPS", "figure.run.square.stack",
              id + [TemplateFields.swiftLanguage, TemplateFields.testing], "watchApp"),
            d(watch, appSection, "Complication Widget Suite", 4, "ClockKit and WidgetKit complications for all watch faces", "gauge.with.needle",
              id + [TemplateFields.swiftLanguage, TemplateFields.testing], "watchApp"),
            d(watch, appSection, "Watch Connectivity Sync", 5, "WCSession file transfers, application context, and interactive messaging", "arrow.triangle.2.circlepath.circle",
              id + [TemplateFields.swiftLanguage, TemplateFields.testing], "watchApp"),
            d(watch, appSection, "Water Lock Swimming App", 6, "Auto-locking swim tracker with lap counts and stroke detection", "drop.fill",
              id + [TemplateFields.swiftLanguage, TemplateFields.testing], "watchApp"),
            d(watch, appSection, "Mindfulness Breathing Guide", 7, "Haptic-driven breathing coach with Heart Rate Variability logging", "wind",
              id + [TemplateFields.swiftLanguage, TemplateFields.testing], "watchApp"),

            // tvOS (4)
            d(tv, appSection, "Top Shelf Carousel", 3, "TVTopShelfSectionedItem carousel extension with deep-link bookmarks", "play.rectangle.on.rectangle",
              appFields, "app"),
            d(tv, appSection, "Remote Siri Game Controller", 12, "Apple TV Siri Remote micro-gamepad touch and motion controller", "gamecontroller",
              id + [gameType(["RealityKit", "SceneKit", "SpriteKit", "Metal 4", "Metal"], default: "SpriteKit", swiftRealityKit: true), integrateGK, swiftOnlyLanguage, TemplateFields.testing], "game"),
            d(tv, appSection, "Multi-Stream Video Wall", 4, "AVPlayerLayer grid displaying simultaneous synchronized feeds", "square.grid.3x3.square",
              appFields, "app"),
            d(tv, appSection, "Custom Focus Engine UI", 5, "Focus guide grid navigation with parallax card elevation", "eye.circle",
              appFields, "app"),

            // Other / Tools (3)
            d("Other", "", "Swift DocC Documentation Catalog", nil, "DocC documentation bundle with articles and interactive tutorials", "doc.text.magnifyingglass",
              id, "bundle"),
            d(mac, appSection, "Command-Line Tool with ArgumentParser", 55, "Swift ArgumentParser CLI with nested subcommands and flags", "terminal",
              id + [TemplateFields.language], "commandLineTool"),
            d("Other", "", "Swift Benchmark Suite", nil, "Performance benchmarking harness measuring CPU cycles and allocations", "gauge.badge.plus",
              id + [TemplateFields.language], "commandLineTool"),
        ]
        return out
    }()

    public static let projects = TemplateChooserCatalog(tabs: ProjectTemplateCatalog.platforms, templates: all)

    public static let packages: TemplateChooserCatalog = {
        let testing = TemplateOptionField(ID.testingSystem, "Testing System", .popUp(["None", "XCTest", "Swift Testing"]), default: "None")
        func p(_ tab: String, _ section: String, _ title: String, _ key: Int, _ type: String, _ fields: [TemplateOptionField], _ save: String,
               _ symbol: String, _ summary: String) -> ProjectTemplateDescriptor {
            ProjectTemplateDescriptor(id: "package.\(tab == "macOS" ? "macos." : "")\(slug(title))", platform: tab, section: section, title: title,
                                      sortKey: key, summary: summary, symbol: symbol, fields: [TemplateFields.productName] + fields,
                                      generator: "package:\(type)", defaultSaveName: save)
        }
        return TemplateChooserCatalog(tabs: ["Multiplatform", "macOS"], templates: [
            p("Multiplatform", "Library", "Library", 100, "library", [testing], "MyLibrary", "building.columns", "A library package"),
            p("Multiplatform", "Other", "Empty", 100, "empty", [], "MyPackage", "shippingbox", "A package with an empty manifest"),
            p("Multiplatform", "Other", "Build Tool Plug-in", 200, "build-tool-plugin", [], "MyBuildToolPlugin", "hammer", "A build tool plug-in"),
            p("Multiplatform", "Other", "Command Plug-in", 300, "command-plugin", [testing], "MyCommandPlugin", "terminal", "A command plug-in"),
            p("Multiplatform", "Other", "Swift Macro", 400, "macro", [testing.with(default: "XCTest", choices: ["None", "XCTest"])], "MyMacro",
              "number", "A Swift macro package"),
            p("macOS", "Executable", "Command-Line Tool", 100, "tool", [], "MyTool", "terminal.fill", "A command-line tool with argument parsing"),
            p("macOS", "Executable", "Executable", 200, "executable", [], "MyExecutable", "play", "An executable package"),
            p("Multiplatform", "Executable", "Executable", 150, "executable", [testing], "MyExecutable", "play", "A cross-platform executable package"),
            p("macOS", "Other", "Command Plug-in", 300, "command-plugin", [testing], "MyCommandPlugin", "terminal", "A command plug-in"),
            p("macOS", "Other", "Build Tool Plug-in", 200, "build-tool-plugin", [], "MyBuildToolPlugin", "hammer", "A build tool plug-in"),
        ])
    }()

    public static func templates(platform: String) -> [ProjectTemplateDescriptor] { projects.templates(platform: platform) }

    public static func find(_ key: String, platform: String? = nil) -> ProjectTemplateDescriptor? {
        if key.lowercased().hasPrefix("package.") { return packages.find(key, platform: platform) }
        return projects.find(key, platform: platform)
    }

    public static func find(platform: String, title: String) -> ProjectTemplateDescriptor? {
        all.first { $0.platform == platform && $0.title == title }
    }

    public static func sections(platform: String, filter: String = "") -> [TemplateSection] { projects.sections(platform: platform, filter: filter) }
}
