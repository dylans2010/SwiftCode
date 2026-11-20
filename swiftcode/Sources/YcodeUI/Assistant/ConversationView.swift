import AppKit
import SwiftUI
import YcodeAssistant
import YcodeIDECore

@MainActor
public final class ConversationView: NSView {
    public let model: CodingAssistantModel
    public let fixedID: UUID?
    public var onReviewProposal: ((ChangeProposal, ConversationMessage, UUID) -> Void)?
    public var onOpenSettings: (() -> Void)?
    public var attachmentSource: (() -> (file: Attachment?, selection: Attachment?))?
    public var onTitleChange: ((String) -> Void)?

    public let providerButton = NSButton()
    private var modelPickerPopover: NSPopover?
    private var modelPickerHosting: NSHostingController<AssistModelPickerView>?
    public let modePicker = NSHostingView(rootView: AssistModePicker(selection: .agent, isEnabled: false, onSelect: { _ in }))
    public let modeDescriptionLabel = NSTextField(labelWithString: "")
    public let statusLabel = NSTextField(wrappingLabelWithString: "")
    public let statusButtons = NSStackView()
    let statusBox = NSStackView()
    public let transcript = NSStackView()
    let transcriptScroll = NSScrollView()
    public let messageView = ComposerTextView()
    public let sendButton = NSButton()
    public let attachButton = NSPopUpButton(frame: .zero, pullsDown: true)
    public let planLabel = NSTextField(labelWithString: "Using ChatGPT plan · Manage usage in ChatGPT settings")
    let chips = NSStackView()
    let workersStrip = WorkersStripView()
    public private(set) var pendingAttachments: [Attachment] = []
    public private(set) var pendingSkills: [SkillDescriptor] = []
    public private(set) var pendingActions: [AssistActionReference] = []
    private var slashPopup: SlashCommandPopupController?
    var skillsActionsPopup: SkillsActionsSlashPopupController?
    private var isApplyingSlashCommit = false
    private var renderedID: UUID?
    private var renderedCount = 0
    private var lastTitle: String?

    public init(model: CodingAssistantModel, conversation: UUID? = nil) {
        self.model = model
        fixedID = conversation
        super.init(frame: .zero)
        build()
        model.observe(owner: self) { [weak self] change in self?.apply(change) }
        reloadAll()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    public var conversationID: UUID? { fixedID ?? model.selectedID }
    public var conversation: Conversation? { conversationID.flatMap(model.conversation) }

    func build() {
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.isSelectable = true
        statusButtons.orientation = .horizontal
        statusButtons.spacing = 6
        statusBox.orientation = .vertical
        statusBox.alignment = .leading
        statusBox.spacing = 6
        statusBox.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        statusBox.addArrangedSubview(statusLabel)
        statusBox.addArrangedSubview(statusButtons)

        transcript.orientation = .vertical
        transcript.alignment = .leading
        transcript.spacing = 16
        transcript.edgeInsets = NSEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        transcript.translatesAutoresizingMaskIntoConstraints = false
        let doc = FlippedView()
        doc.translatesAutoresizingMaskIntoConstraints = false
        doc.addSubview(transcript)
        transcriptScroll.documentView = doc
        transcriptScroll.hasVerticalScroller = true
        transcriptScroll.drawsBackground = false
        transcriptScroll.autohidesScrollers = true
        transcriptScroll.setAccessibilityLabel("Transcript")

        messageView.isRichText = false
        messageView.font = .systemFont(ofSize: 13)
        messageView.textColor = .labelColor
        messageView.insertionPointColor = .controlAccentColor
        messageView.drawsBackground = false
        messageView.onSubmit = { [weak self] in self?.sendClicked() }
        messageView.onTextChange = { [weak self] in self?.slashTextChanged() }
        messageView.onKeyDown = { [weak self] event in self?.slashKeyDown(event) ?? false }
        messageView.setAccessibilityLabel("Message")
        messageView.textContainerInset = NSSize(width: 4, height: 6)
        let messageScroll = NSScrollView()
        messageScroll.documentView = messageView
        messageScroll.hasVerticalScroller = true
        messageScroll.autohidesScrollers = true
        messageScroll.drawsBackground = false
        messageScroll.borderType = .noBorder
        messageView.isVerticallyResizable = true
        messageView.minSize = NSSize(width: 0, height: 0)
        messageView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        messageView.autoresizingMask = [.width]
        messageView.textContainer?.widthTracksTextView = true

        AttachMenu.configure(attachButton, target: self, action: #selector(attachChosen(_:)))
        attachButton.controlSize = .small

        GlassBars.style(providerButton)
        providerButton.isBordered = true
        providerButton.font = .systemFont(ofSize: 11, weight: .semibold)
        providerButton.controlSize = .small
        providerButton.image = NSImage(systemSymbolName: "chevron.up.chevron.down", accessibilityDescription: nil)
        providerButton.imagePosition = .imageTrailing
        providerButton.target = self
        providerButton.action = #selector(providerButtonClicked)
        providerButton.setAccessibilityLabel("Model")
        providerButton.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        sendButton.bezelStyle = .circular
        sendButton.isBordered = false
        sendButton.controlSize = .regular
        sendButton.target = self
        sendButton.action = #selector(sendClicked)
        sendButton.keyEquivalent = ""

        planLabel.font = .systemFont(ofSize: 10)
        planLabel.textColor = .tertiaryLabelColor
        planLabel.lineBreakMode = .byTruncatingTail
        planLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        chips.orientation = .horizontal
        chips.spacing = 6
        chips.isHidden = true

        modePicker.sizingOptions = [.intrinsicContentSize]
        modePicker.setAccessibilityLabel("Assist mode: Plan, Agent or Turbo")
        modeDescriptionLabel.font = .systemFont(ofSize: 10)
        modeDescriptionLabel.textColor = .tertiaryLabelColor
        modeDescriptionLabel.lineBreakMode = .byTruncatingTail
        modeDescriptionLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        modeDescriptionLabel.isHidden = true

        let modeRow = NSStackView(views: [modePicker, NSView()])
        modeRow.orientation = .horizontal
        modeRow.spacing = 6
        modeRow.alignment = .centerY

        let bottom = NSStackView(views: [attachButton, providerButton, NSView(), sendButton])
        bottom.orientation = .horizontal
        bottom.spacing = 6
        bottom.alignment = .centerY

        let composerBg = GlassBars.surface(cornerRadius: 20)
        composerBg.translatesAutoresizingMaskIntoConstraints = false

        let innerDivider = NSBox()
        innerDivider.boxType = .separator

        let composerStack = NSStackView(views: [chips, workersStrip, modeRow, messageScroll, innerDivider, bottom, planLabel])
        composerStack.orientation = .vertical
        composerStack.alignment = .leading
        composerStack.spacing = 8
        composerStack.edgeInsets = NSEdgeInsets(top: 11, left: 12, bottom: 11, right: 12)
        composerStack.translatesAutoresizingMaskIntoConstraints = false
        composerBg.addSubview(composerStack)

        for v in [statusBox, transcriptScroll, composerBg] as [NSView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }
        for full in [workersStrip, modeRow, messageScroll, innerDivider, bottom, planLabel] as [NSView] {
            full.translatesAutoresizingMaskIntoConstraints = false
            full.widthAnchor.constraint(equalTo: composerStack.widthAnchor, constant: -24).isActive = true
        }
        NSLayoutConstraint.activate([
            statusBox.topAnchor.constraint(equalTo: topAnchor),
            statusBox.leadingAnchor.constraint(equalTo: leadingAnchor),
            statusBox.trailingAnchor.constraint(equalTo: trailingAnchor),
            transcriptScroll.topAnchor.constraint(equalTo: statusBox.bottomAnchor),
            transcriptScroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            transcriptScroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            transcriptScroll.bottomAnchor.constraint(equalTo: composerBg.topAnchor, constant: -8),
            doc.topAnchor.constraint(equalTo: transcriptScroll.contentView.topAnchor),
            doc.leadingAnchor.constraint(equalTo: transcriptScroll.contentView.leadingAnchor),
            doc.widthAnchor.constraint(equalTo: transcriptScroll.contentView.widthAnchor),
            transcript.topAnchor.constraint(equalTo: doc.topAnchor),
            transcript.leadingAnchor.constraint(equalTo: doc.leadingAnchor),
            transcript.trailingAnchor.constraint(equalTo: doc.trailingAnchor),
            transcript.bottomAnchor.constraint(equalTo: doc.bottomAnchor),
            composerBg.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            composerBg.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            composerBg.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            composerStack.topAnchor.constraint(equalTo: composerBg.topAnchor),
            composerStack.leadingAnchor.constraint(equalTo: composerBg.leadingAnchor),
            composerStack.trailingAnchor.constraint(equalTo: composerBg.trailingAnchor),
            composerStack.bottomAnchor.constraint(equalTo: composerBg.bottomAnchor),
            messageScroll.heightAnchor.constraint(equalToConstant: 62),
            modePicker.heightAnchor.constraint(equalToConstant: 28),
            sendButton.widthAnchor.constraint(equalToConstant: 28),
            sendButton.heightAnchor.constraint(equalToConstant: 28),
        ])
    }

    func apply(_ change: CodingAssistantModel.Change) {
        switch change {
        case .list:
            renderTranscript(force: conversationID != renderedID)
            updateComposer()
            noteTitle()
        case .transcript(let id):
            if id == conversationID { renderTranscript(force: false) }
            updateComposer()
        case .status:
            reloadProviderButton()
            updateStatus()
            if (conversation?.messages ?? []).isEmpty {
                renderTranscript(force: true)
            }
            updateComposer()
        }
    }

    func reloadAll() {
        reloadProviderButton()
        updateStatus()
        renderTranscript(force: true)
        updateComposer()
        noteTitle()
    }

    func noteTitle() {
        guard let t = conversation?.title, t != lastTitle else { return }
        lastTitle = t
        onTitleChange?(t)
    }

    func reloadProviderButton() {
        providerButton.title = model.sourceLabel
        providerButton.toolTip = "Model: \(model.sourceLabel) — click to choose a provider or model"
    }

    func modelPickerSections() -> [AssistModelPickerView.ProviderSection] {
        ProviderKind.allCases
            .filter { $0 != .scCloud || $0 == model.providerKind }
            .map { AssistModelPickerView.ProviderSection(provider: $0, availability: model.availability[$0]) }
    }

    @objc func providerButtonClicked() {
        if let pop = modelPickerPopover, pop.isShown {
            pop.performClose(nil)
            return
        }
        let picker = AssistModelPickerView(
            sections: modelPickerSections(),
            selectedKind: model.providerKind,
            selectedModelID: model.modelID,
            onSelect: { [weak self] kind, m in
                guard let self else { return }
                model.choose(kind, model: m)
                modelPickerPopover?.performClose(nil)
            },
            onCheckAgain: { [weak self] in self?.model.refreshAvailability() },
            onOpenSettings: { [weak self] in
                self?.modelPickerPopover?.performClose(nil)
                self?.onOpenSettings?()
            })
        let hosting = NSHostingController(rootView: picker)
        modelPickerHosting = hosting
        let pop = NSPopover()
        pop.contentViewController = hosting
        pop.behavior = .transient
        pop.animates = true
        modelPickerPopover = pop
        guard let w = window, w.isVisible else { return }
        pop.show(relativeTo: providerButton.bounds, of: providerButton, preferredEdge: .minY)
    }

    public var modelChoiceTitles: [String] {
        ProviderKind.allCases.flatMap { kind -> [String] in
            let models = model.availability[kind]?.models ?? []
            if models.isEmpty { return ["\(kind.displayName)/Choose \(kind.displayName)"] }
            return models.map { "\(kind.displayName)/\($0.displayName.isEmpty ? "Default" : $0.displayName)" }
        }
    }

    @objc func refreshClicked() { model.refreshAvailability() }
    @objc func settingsClicked() { onOpenSettings?() }

    public var statusText: String? { statusBox.isHidden ? nil : statusLabel.stringValue }

    func updateStatus() {
        statusButtons.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let a = model.currentAvailability
        if model.isSurveying && model.availability.isEmpty {
            statusLabel.stringValue = "Looking for models…"
            statusBox.isHidden = false
            return
        }
        guard let a, !a.isReady else { statusBox.isHidden = true; return }
        if !model.hasUsableBackend {
            statusLabel.stringValue = AssistantBackends.noBackendText
        } else {
            statusLabel.stringValue = "\(model.providerKind.displayName): " + (a.hint ?? "unavailable.")
            for k in model.readyProviders.prefix(3) {
                let b = ClosureButton(title: "Use \(k.displayName)", target: nil, action: nil)
                b.bezelStyle = .inline
                b.onChange = { [weak self] _ in self?.model.choose(k, model: nil) }
                statusButtons.addArrangedSubview(b)
            }
        }
        for (title, action) in [("Check Again", #selector(refreshClicked)), ("Settings…", #selector(settingsClicked))] {
            let b = NSButton(title: title, target: self, action: action)
            b.bezelStyle = .inline
            statusButtons.addArrangedSubview(b)
        }
        statusBox.isHidden = false
    }

    func renderTranscript(force: Bool) {
        let conv = conversation
        let messages = conv?.messages ?? []
        if force || conv?.id != renderedID || messages.count != renderedCount {
            transcript.arrangedSubviews.forEach { $0.removeFromSuperview() }
            if messages.isEmpty {
                let backendReady = model.hasUsableBackend || model.usesChatGPTPlan || model.isSurveying || model.availability.isEmpty
                let text: String
                if fixedID != nil && conv == nil {
                    text = "This conversation was deleted."
                } else if backendReady {
                    text = "Ask a question about your project, attach files, or pick a quick action below."
                } else {
                    text = AssistantBackends.noBackendText
                }
                let heading: String
                if fixedID != nil && conv == nil {
                    heading = "Conversation unavailable"
                } else if backendReady {
                    heading = "What would you like to build?"
                } else {
                    heading = "Connect a provider to begin"
                }
                let empty = emptyState(title: heading, detail: text, showStarters: backendReady && !(fixedID != nil && conv == nil))
                transcript.addArrangedSubview(empty)
                let insets = transcript.edgeInsets
                empty.widthAnchor.constraint(equalTo: transcript.widthAnchor, constant: -(insets.left + insets.right)).isActive = true
            }
            if let convID = conv?.id {
                for m in messages { addMessageView(m, conversation: convID) }
            }
        } else if let last = messages.last, let convID = conv?.id, let lastView = transcript.arrangedSubviews.last {
            lastView.removeFromSuperview()
            addMessageView(last, conversation: convID)
        }
        renderedID = conv?.id
        renderedCount = messages.count
        scrollToEnd()
    }

    func emptyState(title: String, detail: String, showStarters: Bool = false) -> NSView {
        let badge = NSView()
        badge.wantsLayer = true
        let gradient = CAGradientLayer()
        gradient.frame = NSRect(x: 0, y: 0, width: 48, height: 48)
        gradient.cornerRadius = 24
        gradient.cornerCurve = .continuous
        gradient.colors = [NSColor.controlAccentColor.cgColor, NSColor.systemIndigo.withAlphaComponent(0.88).cgColor]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        badge.layer?.addSublayer(gradient)
        badge.layer?.shadowColor = NSColor.controlAccentColor.cgColor
        badge.layer?.shadowOpacity = 0.18
        badge.layer?.shadowRadius = 10
        badge.layer?.shadowOffset = CGSize(width: 0, height: 3)
        let icon = NSImageView(image: NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Assist") ?? NSImage())
        icon.symbolConfiguration = .init(pointSize: 18, weight: .semibold)
        icon.contentTintColor = .white
        icon.translatesAutoresizingMaskIntoConstraints = false
        badge.addSubview(icon)
        NSLayoutConstraint.activate([
            badge.widthAnchor.constraint(equalToConstant: 48),
            badge.heightAnchor.constraint(equalToConstant: 48),
            icon.centerXAnchor.constraint(equalTo: badge.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
        ])

        let heading = NSTextField(labelWithString: title)
        heading.font = .systemFont(ofSize: 15, weight: .semibold)
        heading.textColor = .labelColor
        let hint = NSTextField(wrappingLabelWithString: detail)
        hint.font = .systemFont(ofSize: 11.5)
        hint.textColor = .secondaryLabelColor
        hint.alignment = .center
        hint.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        var views: [NSView] = [badge, heading, hint]
        if showStarters {
            let prompts = [
                ("doc.text.magnifyingglass", "Explain current file", "Explain what the current file does and how it fits into the project."),
                ("ladybug", "Find & fix bugs", "Inspect the current file and open build issues for potential bugs and propose fixes."),
                ("checklist", "Write unit tests", "Write thorough unit tests for the active file."),
            ]
            let promptCol = NSStackView()
            promptCol.orientation = .vertical
            promptCol.alignment = .centerX
            promptCol.spacing = 7
            for (symbol, label, promptText) in prompts {
                let btn = ClosureButton(title: label, target: nil, action: nil)
                btn.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
                btn.imagePosition = .imageLeading
                GlassBars.style(btn)
                btn.controlSize = .regular
                btn.font = .systemFont(ofSize: 11.5, weight: .medium)
                btn.alignment = .left
                btn.toolTip = promptText
                btn.translatesAutoresizingMaskIntoConstraints = false
                btn.widthAnchor.constraint(equalToConstant: 228).isActive = true
                btn.heightAnchor.constraint(equalToConstant: 31).isActive = true
                btn.onChange = { [weak self] _ in
                    guard let self else { return }
                    self.messageView.string = promptText
                    self.focusMessageField()
                }
                promptCol.addArrangedSubview(btn)
            }
            views.append(promptCol)
        }

        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 11
        stack.edgeInsets = NSEdgeInsets(top: 28, left: 16, bottom: 24, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    func scrollToEnd() {
        transcript.layoutSubtreeIfNeeded()
        guard let doc = transcriptScroll.documentView else { return }
        doc.layoutSubtreeIfNeeded()
        let y = max(0, doc.frame.height - transcriptScroll.contentView.bounds.height)
        transcriptScroll.contentView.scroll(to: NSPoint(x: 0, y: y))
        transcriptScroll.reflectScrolledClipView(transcriptScroll.contentView)
    }

    func addMessageView(_ m: ConversationMessage, conversation: UUID) {
        let v = MessageView(message: m, proposals: m.role == .assistant && m.isComplete ? ChangeProposal.parse(m.text, target: m.target) : [])
        v.onReview = { [weak self] p in self?.onReviewProposal?(p, m, conversation) }
        v.onContinue = { [weak self] in self?.model.continueReply(in: conversation) }
        v.translatesAutoresizingMaskIntoConstraints = false
        transcript.addArrangedSubview(v)
        let insets = transcript.edgeInsets
        v.widthAnchor.constraint(equalTo: transcript.widthAnchor, constant: -(insets.left + insets.right)).isActive = true
    }

    public var messageViews: [MessageView] { transcript.arrangedSubviews.compactMap { $0 as? MessageView } }

    func updateComposer() {
        let running = conversationID.map(model.isRunning) ?? false
        sendButton.title = running ? "Stop" : "Send"
        let symbol = running ? "stop.circle.fill" : "arrow.up.circle.fill"
        sendButton.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 22, weight: .semibold))
        sendButton.imagePosition = .imageOnly
        sendButton.setAccessibilityLabel(running ? "Stop response" : "Send message")
        sendButton.contentTintColor = running ? .systemOrange : .controlAccentColor
        sendButton.toolTip = running ? "Stop the response" : "Send (Return)"
        sendButton.isEnabled = !(fixedID != nil && conversation == nil)
        let mode = conversationID.map(model.mode(for:)) ?? .agent
        modePicker.rootView = AssistModePicker(selection: mode, isEnabled: conversation != nil) { [weak self] m in
            guard let self, let id = self.conversationID else { return }
            self.model.setMode(m, for: id)
        }
        modeDescriptionLabel.stringValue = mode.shortDescription
        modeDescriptionLabel.toolTip = "\(mode.displayName) mode — \(mode.shortDescription)"
        planLabel.isHidden = !model.usesChatGPTPlan
        workersStrip.isHidden = WorkerRuntimeState.shared.allWorkers.isEmpty
        messageView.placeholder = "Message \(model.sourceLabel)…"
        messageView.needsDisplay = true
    }

    private var slashCommandsEnabled: Bool {
        model.providerKind == .metaAssist && model.settings.useMetaSlashCommands
    }

    private var slashQuery: String? {
        guard let token = messageView.string.split(whereSeparator: \.isWhitespace).last,
              token.hasPrefix("/") || token.hasPrefix("@") else { return nil }
        return String(token)
    }

    func slashTextChanged() {
        guard !isApplyingSlashCommit, let query = slashQuery else {
            slashPopup?.hide()
            skillsActionsPopup?.hide()
            return
        }
        if slashCommandsEnabled && query.hasPrefix("/") {
            skillsActionsPopup?.hide()
            if let popup = slashPopup, popup.isVisible {
                popup.update(query: query)
            } else {
                let popup = SlashCommandPopupController(model: model, anchorView: messageView)
                popup.onCommit = { [weak self] text, send in self?.slashCommit(text: text, sendImmediately: send) }
                popup.onDismiss = { [weak self] in self?.slashPopup = nil }
                slashPopup = popup
                popup.show(query: query)
            }
            return
        }

        slashPopup?.hide()
        if let popup = skillsActionsPopup, popup.isVisible {
            popup.update(query: query)
        } else {
            let popup = SkillsActionsSlashPopupController(anchorView: messageView)
            popup.onSelect = { [weak self] item in self?.slashPaletteItemSelected(item) }
            popup.onDismiss = { [weak self] in self?.skillsActionsPopup = nil }
            skillsActionsPopup = popup
            popup.show(query: query)
        }
    }

    private func slashKeyDown(_ event: NSEvent) -> Bool {
        if let popup = skillsActionsPopup, popup.isVisible { return popup.handleKeyDown(event) }
        return slashPopup?.handleKeyDown(event) ?? false
    }

    private func slashCommit(text: String, sendImmediately: Bool) {
        isApplyingSlashCommit = true
        messageView.string = text
        isApplyingSlashCommit = false
        if sendImmediately { sendClicked() }
    }

    private func slashPaletteItemSelected(_ item: SlashPaletteItem) {
        consumeTrailingTrigger()
        focusMessageField()
        if item.kind == .skill {
            guard let skill = item.skillDescriptor else { return }
            addSkill(skill)
            return
        }
        addAction(AssistActionReference(command: item.command, title: item.title, summary: item.subtitle, category: item.badgeText))
        Task {
            _ = await SlashCommandExecutionEngine.shared.execute(command: item.command)
        }
    }

    private func consumeTrailingTrigger() {
        var words = messageView.string.split(whereSeparator: \.isWhitespace).map(String.init)
        if let last = words.last, last.hasPrefix("/") || last.hasPrefix("@") {
            words.removeLast()
        }
        let text = words.joined(separator: " ")
        messageView.string = text.isEmpty ? "" : text + " "
    }

    @objc public func sendClicked() {
        if let id = conversationID, model.isRunning(id) {
            model.stop(id)
            return
        }
        if fixedID != nil && conversation == nil { return NSSound.beep() }
        let text = messageView.string
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if model.send(text, attachments: pendingAttachments, skills: pendingSkills, actions: pendingActions, in: fixedID) != nil {
            messageView.string = ""
            pendingAttachments = []
            pendingSkills = []
            pendingActions = []
            renderChips()
        }
    }

    @objc func attachChosen(_ sender: NSPopUpButton) {
        let index = sender.indexOfSelectedItem
        guard index >= 0, let item = sender.item(at: index), let choice = AttachMenu.Choice(rawValue: item.tag) else { return }
        switch choice {
        case .currentFile, .selection:
            guard let src = attachmentSource?() else { return }
            let a = choice == .currentFile ? src.file : src.selection
            guard let a else { NSSound.beep(); return }
            attach(a)
        case .file:
            if let a = AttachmentPicker.pickFile() { attach(a) }
        case .image:
            if let a = AttachmentPicker.pickImage() { attach(a) }
        }
    }

    public func attach(_ a: Attachment) {
        guard !pendingAttachments.contains(a) else { return }
        pendingAttachments.append(a)
        renderChips()
    }

    public func addSkill(_ skill: SkillDescriptor) {
        guard !pendingSkills.contains(where: { $0.id == skill.id }) else { return }
        pendingSkills.append(skill)
        renderChips(animated: true)
    }

    public func addAction(_ action: AssistActionReference) {
        guard !pendingActions.contains(where: { $0.command == action.command }) else { return }
        pendingActions.append(action)
        renderChips(animated: true)
    }

    func renderChips(animated: Bool = false) {
        chips.arrangedSubviews.forEach { $0.removeFromSuperview() }
        var animatedViews: [NSView] = []
        for (i, a) in pendingAttachments.enumerated() {
            let b = ClosureButton(title: a.label + "  ✕", target: nil, action: nil)
            b.bezelStyle = .inline
            b.controlSize = .small
            b.toolTip = "Remove \(a.path) from the message"
            b.onChange = { [weak self] _ in
                guard let self, i < pendingAttachments.count else { return }
                pendingAttachments.remove(at: i)
                renderChips()
            }
            chips.addArrangedSubview(b)
        }
        for (i, skill) in pendingSkills.enumerated() {
            let b = ClosureButton(title: "/\(skill.name)  ✕", target: nil, action: nil)
            b.controlSize = .small
            GlassBars.style(b)
            b.toolTip = "Remove the \(skill.name) skill reference. The full skill is never embedded in the message."
            b.onChange = { [weak self] _ in
                guard let self, i < pendingSkills.count else { return }
                pendingSkills.remove(at: i)
                renderChips()
            }
            chips.addArrangedSubview(b)
            animatedViews.append(b)
        }
        for (i, action) in pendingActions.enumerated() {
            let b = ClosureButton(title: action.command + "  ✕", target: nil, action: nil)
            b.controlSize = .small
            GlassBars.style(b)
            b.contentTintColor = .systemBlue
            b.toolTip = "Remove \(action.title). Full action details are retrieved locally and are never embedded in the message."
            b.onChange = { [weak self] _ in
                guard let self, i < pendingActions.count else { return }
                pendingActions.remove(at: i)
                renderChips()
            }
            chips.addArrangedSubview(b)
            animatedViews.append(b)
        }
        chips.isHidden = pendingAttachments.isEmpty && pendingSkills.isEmpty && pendingActions.isEmpty
        if animated, !animatedViews.isEmpty {
            for view in animatedViews { view.alphaValue = 0 }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                for view in animatedViews { view.animator().alphaValue = 1 }
            }
        }
    }

    public func focusMessageField() { window?.makeFirstResponder(messageView) }
}

enum AttachMenu {
    enum Choice: Int {
        case currentFile = 0
        case selection = 1
        case file = 2
        case image = 3
    }

    @MainActor static func configure(_ b: NSPopUpButton, target: AnyObject, action: Selector) {
        b.isBordered = false
        b.removeAllItems()
        b.addItem(withTitle: "")
        b.item(at: 0)?.image = NSImage(systemSymbolName: "paperclip", accessibilityDescription: "Attach")
        b.item(at: 0)?.tag = -1
        for (title, choice) in [("Attach Current File", Choice.currentFile), ("Attach Selection", Choice.selection)] {
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.tag = choice.rawValue
            item.image = NSImage(systemSymbolName: choice == .currentFile ? "doc.text" : "selection.pin.in.out",
                                 accessibilityDescription: nil)
            b.menu?.addItem(item)
        }
        b.menu?.addItem(.separator())
        for (title, choice, symbol) in [("Attach File…", Choice.file, "doc.badge.plus"),
                                        ("Attach Image…", Choice.image, "photo.badge.plus")] {
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.tag = choice.rawValue
            item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
            b.menu?.addItem(item)
        }
        b.target = target
        b.action = action
        b.toolTip = "Attach the current file, the selection, or a file/image from disk"
        b.setAccessibilityLabel("Attach")
        (b.cell as? NSPopUpButtonCell)?.arrowPosition = .noArrow
    }
}

@MainActor
enum ProviderMenu {
    final class Choice: NSObject {
        let kind: ProviderKind
        let model: String?
        init(kind: ProviderKind, model: String?) { self.kind = kind; self.model = model }
    }

    static func build(_ model: CodingAssistantModel, target: AnyObject, choose: Selector, checkAgain: Selector, settings: Selector,
                      title: String? = nil, image: NSImage? = nil) -> NSMenu {
        let menu = NSMenu()
        let titleItem = NSMenuItem(title: title ?? model.sourceLabel, action: nil, keyEquivalent: "")
        titleItem.image = image
        menu.addItem(titleItem)
        let current = model.providerKind
        let currentModel = model.modelID ?? ""
        for kind in ProviderKind.allCases {
            let a = model.availability[kind]
            let header = NSMenuItem(title: kind.displayName + stateSuffix(a), action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)
            let models = a?.models ?? []
            for m in models.isEmpty ? [ModelInfo(id: "", displayName: "Choose \(kind.displayName)")] : models {
                let item = NSMenuItem(title: m.displayName.isEmpty ? "Default" : m.displayName, action: choose, keyEquivalent: "")
                item.indentationLevel = 1
                item.representedObject = Choice(kind: kind, model: models.isEmpty ? nil : m.id)
                item.target = target
                item.state = kind == current && (models.isEmpty || m.id == currentModel) ? .on : .off
                menu.addItem(item)
            }
        }
        menu.addItem(.separator())
        let refresh = NSMenuItem(title: "Check Again", action: checkAgain, keyEquivalent: "")
        refresh.target = target
        menu.addItem(refresh)
        let s = NSMenuItem(title: "Assist Settings…", action: settings, keyEquivalent: "")
        s.target = target
        menu.addItem(s)
        return menu
    }

    static func choiceTitles(_ menu: NSMenu?) -> [String] {
        (menu?.items ?? []).compactMap { item in
            (item.representedObject as? Choice).map { "\($0.kind.displayName)/\(item.title)" }
        }
    }

    static func stateSuffix(_ a: ProviderAvailability?) -> String {
        switch a {
        case nil: " (checking…)"
        case .ready?: ""
        case .notRunning?: " (not running)"
        case .noModels?: " (no models)"
        case .notInstalled?: " (not installed)"
        case .signedOut?: " (not signed in)"
        case .failed?: " (unavailable)"
        }
    }
}

public final class ComposerTextView: NSTextView {
    var onSubmit: (() -> Void)?
    var onCancel: (() -> Void)?
    var onTextChange: (() -> Void)?
    var onKeyDown: ((NSEvent) -> Bool)?
    var placeholder = "" { didSet { needsDisplay = true } }

    public override func cancelOperation(_ sender: Any?) {
        if let onCancel { onCancel() } else { _ = nextResponder?.tryToPerform(#selector(cancelOperation(_:)), with: sender) }
    }

    public override func keyDown(with event: NSEvent) {
        if let onKeyDown, onKeyDown(event) { return }
        let isReturn = event.keyCode == 36 || event.keyCode == 76
        if isReturn && event.modifierFlags.isDisjoint(with: [.shift, .option]) && !hasMarkedText() {
            onSubmit?()
            return
        }
        super.keyDown(with: event)
    }

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard string.isEmpty, !placeholder.isEmpty else { return }
        let attrs: [NSAttributedString.Key: Any] = [.foregroundColor: NSColor.placeholderTextColor, .font: font ?? .systemFont(ofSize: 13)]
        (placeholder as NSString).draw(at: NSPoint(x: textContainerInset.width + 5, y: textContainerInset.height), withAttributes: attrs)
    }

    public override func didChangeText() {
        super.didChangeText()
        needsDisplay = true
        onTextChange?()
    }
}

private struct AssistantThinkingIndicator: View {
    @State private var isAnimating = false
    private let palette: [Color] = [.indigo, .cyan, .purple, .orange]

    var body: some View {
        HStack(spacing: 5) {
            Text("Generating")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(colors: [.indigo, .cyan, .purple, .orange], startPoint: .leading, endPoint: .trailing)
                )
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(palette[index % palette.count])
                    .frame(width: 4.5, height: 4.5)
                    .scaleEffect(isAnimating ? 1.0 : 0.55)
                    .opacity(isAnimating ? 1.0 : 0.35)
                    .animation(
                        .easeInOut(duration: 0.62)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.14),
                        value: isAnimating
                    )
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Color.primary.opacity(0.055), in: Capsule(style: .continuous))
        .accessibilityLabel("Assistant is generating a response")
        .onAppear { isAnimating = true }
    }
}

public final class MessageView: NSStackView {
    public let message: ConversationMessage
    public let proposals: [ChangeProposal]
    var onReview: ((ChangeProposal) -> Void)?
    var onContinue: (() -> Void)?
    public private(set) var continueButton: NSButton?
    public private(set) var reviewButtons: [NSButton] = []

    init(message: ConversationMessage, proposals: [ChangeProposal]) {
        self.message = message
        self.proposals = proposals
        super.init(frame: .zero)
        orientation = .vertical
        alignment = .leading
        spacing = 6
        build()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func build() {
        let whoIcon = NSImageView(image: NSImage(systemSymbolName: message.role == .user ? "person.circle.fill" : "sparkles",
                                                 accessibilityDescription: nil) ?? NSImage())
        whoIcon.contentTintColor = message.role == .user ? Theme.accentColor : .systemPurple
        whoIcon.symbolConfiguration = .init(pointSize: 12, weight: .medium)
        let who = NSTextField(labelWithString: message.role == .user ? "You" : (message.source ?? "Assist"))
        who.font = .boldSystemFont(ofSize: 11)
        who.textColor = .secondaryLabelColor
        let whoRow = NSStackView(views: [whoIcon, who])
        whoRow.spacing = 4
        whoRow.alignment = .centerY
        if message.role == .user {
            let headerRow = NSStackView(views: [NSView(), whoRow])
            headerRow.orientation = .horizontal
            headerRow.alignment = .centerY
            addArrangedSubview(headerRow)
        } else {
            addArrangedSubview(whoRow)
        }
        if !message.attachments.isEmpty {
            let a = NSTextField(labelWithString: "Attached: " + message.attachments.map(\.label).joined(separator: ", "))
            a.font = .systemFont(ofSize: 10)
            a.textColor = .secondaryLabelColor
            addArrangedSubview(a)
        }
        if !message.activity.isEmpty {
            let card = ActivityCardView(lines: message.activity)
            addArrangedSubview(card)
            card.widthAnchor.constraint(equalTo: widthAnchor).isActive = true
        }
        if message.role == .user {
            let bubble = NSView()
            bubble.wantsLayer = true
            bubble.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.15).cgColor
            bubble.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.22).cgColor
            bubble.layer?.borderWidth = 1
            bubble.layer?.cornerRadius = 16
            bubble.layer?.cornerCurve = .continuous
            let p = prose(message.text, markdown: false)
            p.translatesAutoresizingMaskIntoConstraints = false
            p.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            bubble.addSubview(p)
            bubble.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                p.topAnchor.constraint(equalTo: bubble.topAnchor, constant: 9),
                p.leadingAnchor.constraint(equalTo: bubble.leadingAnchor, constant: 14),
                p.trailingAnchor.constraint(equalTo: bubble.trailingAnchor, constant: -14),
                p.bottomAnchor.constraint(equalTo: bubble.bottomAnchor, constant: -9),
            ])
            let bubbleRow = NSStackView(views: [NSView(), bubble])
            bubbleRow.orientation = .horizontal
            bubbleRow.alignment = .top
            addArrangedSubview(bubbleRow)
            bubble.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, multiplier: 0.82).isActive = true
        } else {
            var codeIndex = 0
            for block in MarkdownBlocks.parse(message.text) {
                switch block {
                case .prose(let p): addArrangedSubview(prose(p, markdown: true))
                case .code(let info, let text, _):
                    if info.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "tool_call" {
                        addArrangedSubview(toolCallCard(text: text))
                    } else {
                        addArrangedSubview(codeBlock(info: info, text: text, proposal: proposals.first { $0.blockIndex == codeIndex }, index: codeIndex))
                    }
                    codeIndex += 1
                }
            }
            if !message.isComplete && message.text.isEmpty {
                let indicator = NSHostingView(rootView: AssistantThinkingIndicator())
                indicator.sizingOptions = [.intrinsicContentSize]
                addArrangedSubview(indicator)
            }
        }
        if message.isCutOff == true {
            let l = NSTextField(wrappingLabelWithString: "The reply was cut off at the output limit (Settings ▸ Assist ▸ Most output tokens).")
            l.textColor = .secondaryLabelColor
            l.font = .systemFont(ofSize: 11)
            let b = NSButton(title: "Continue", target: self, action: #selector(continueClicked))
            b.bezelStyle = .inline
            b.controlSize = .small
            b.isEnabled = message.isComplete
            continueButton = b
            let row = NSStackView(views: [l, b])
            row.alignment = .firstBaseline
            addArrangedSubview(row)
        }
        if let e = message.error {
            if e == "Stopped." || e == "Interrupted." {
                let l = NSTextField(wrappingLabelWithString: e)
                l.textColor = .secondaryLabelColor
                l.font = .systemFont(ofSize: 11)
                l.isSelectable = true
                addArrangedSubview(l)
            } else {
                let bubble = NSHostingView(rootView: AssistErrorBubble(error: e))
                bubble.sizingOptions = [.intrinsicContentSize]
                bubble.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
                addArrangedSubview(bubble)
            }
        }
        for v in arrangedSubviews {
            v.translatesAutoresizingMaskIntoConstraints = false
            if v is NSTextField || v is NSStackView {
                v.widthAnchor.constraint(equalTo: widthAnchor).isActive = true
            }
        }
    }

    @objc func continueClicked() { onContinue?() }

    func prose(_ text: String, markdown: Bool) -> NSTextField {
        let s: NSAttributedString
        if markdown, let a = try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            let m = NSMutableAttributedString(a)
            m.addAttribute(.font, value: NSFont.systemFont(ofSize: NSFont.systemFontSize), range: NSRange(location: 0, length: m.length))
            a.runs.forEach { run in
                guard let intent = run.inlinePresentationIntent else { return }
                let r = NSRange(run.range, in: a)
                var font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
                if intent.contains(.code) { font = .monospacedSystemFont(ofSize: NSFont.systemFontSize - 1, weight: .regular) }
                if intent.contains(.stronglyEmphasized) { font = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask) }
                if intent.contains(.emphasized) { font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask) }
                m.addAttribute(.font, value: font, range: r)
            }
            m.addAttribute(.foregroundColor, value: NSColor.labelColor, range: NSRange(location: 0, length: m.length))
            s = m
        } else {
            s = NSAttributedString(string: text, attributes: [.font: NSFont.systemFont(ofSize: NSFont.systemFontSize), .foregroundColor: NSColor.labelColor])
        }
        let l = NSTextField(wrappingLabelWithString: "")
        l.attributedStringValue = s
        l.isSelectable = true
        l.allowsEditingTextAttributes = true
        l.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return l
    }

    func toolCallCard(text: String) -> NSView {
        let object = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any]
        let toolName = (object?["tool"] as? String) ?? (object?["toolName"] as? String) ?? "Tool request"
        let displayName = toolName
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
        let arguments = object?["arguments"] as? [String: Any] ?? [:]
        let preferredKeys = ["query", "path", "prompt", "title", "command", "objective"]
        let firstMatchKey = preferredKeys.first { arguments[$0] != nil } ?? arguments.keys.sorted().first
        let detailText: String
        if let key = firstMatchKey, let value = arguments[key] {
            let summary = String(describing: value)
                .replacingOccurrences(of: "\n", with: " · ")
            detailText = "\(key.capitalized): \(String(summary.prefix(160)))"
        } else if object != nil {
            detailText = "No arguments"
        } else {
            detailText = "SwiftCode could not decode the model's tool request."
        }

        let iconWrap = NSView()
        iconWrap.wantsLayer = true
        iconWrap.layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.14).cgColor
        iconWrap.layer?.cornerRadius = 8
        iconWrap.layer?.cornerCurve = .continuous
        let icon = NSImageView(image: NSImage(systemSymbolName: "wrench.and.screwdriver", accessibilityDescription: "Tool call") ?? NSImage())
        icon.symbolConfiguration = .init(pointSize: 11, weight: .semibold)
        icon.contentTintColor = .systemBlue
        icon.translatesAutoresizingMaskIntoConstraints = false
        iconWrap.addSubview(icon)

        let eyebrow = NSTextField(labelWithString: "Tool call")
        eyebrow.font = .systemFont(ofSize: 9, weight: .bold)
        eyebrow.textColor = .systemBlue
        let title = NSTextField(labelWithString: displayName)
        title.font = .systemFont(ofSize: 12, weight: .semibold)
        title.lineBreakMode = .byTruncatingTail
        let detail = NSTextField(wrappingLabelWithString: detailText)
        detail.font = .systemFont(ofSize: 10.5)
        detail.textColor = .secondaryLabelColor
        detail.lineBreakMode = .byTruncatingTail
        detail.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let status = NSTextField(labelWithString: object == nil ? "Invalid" : "Requested")
        status.font = .systemFont(ofSize: 9, weight: .bold)
        status.textColor = object == nil ? .systemOrange : .systemBlue
        status.wantsLayer = true
        status.layer?.backgroundColor = (object == nil ? NSColor.systemOrange : NSColor.systemBlue).withAlphaComponent(0.1).cgColor
        status.layer?.cornerRadius = 10
        status.layer?.cornerCurve = .continuous
        status.bounds = NSRect(x: 0, y: 0, width: status.intrinsicContentSize.width + 12, height: 20)

        let textStack = NSStackView(views: [eyebrow, title, detail])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2
        let content = NSStackView(views: [iconWrap, textStack, NSView(), status])
        content.orientation = .horizontal
        content.spacing = 10
        content.alignment = .centerY
        content.edgeInsets = NSEdgeInsets(top: 8, left: 10, bottom: 8, right: 10)
        content.wantsLayer = true
        content.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.45).cgColor
        content.layer?.borderColor = NSColor.systemBlue.withAlphaComponent(0.16).cgColor
        content.layer?.borderWidth = 1
        content.layer?.cornerRadius = 12
        content.layer?.cornerCurve = .continuous
        NSLayoutConstraint.activate([
            iconWrap.widthAnchor.constraint(equalToConstant: 28),
            iconWrap.heightAnchor.constraint(equalToConstant: 28),
            icon.centerXAnchor.constraint(equalTo: iconWrap.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconWrap.centerYAnchor),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: status.leadingAnchor, constant: -8),
        ])
        return content
    }

    func codeBlock(info: String, text: String, proposal: ChangeProposal?, index: Int) -> NSView {
        let box = NSStackView()
        box.orientation = .vertical
        box.alignment = .leading
        box.spacing = 5
        let titleText: String
        if let p = proposal {
            switch p.kind {
            case .wholeFile: titleText = "Proposed: \(p.path)"
            case .replaceSelection: titleText = "Proposed: replace the selection in \((p.path as NSString).lastPathComponent)"
            case .append: titleText = "Proposed: add to \((p.path as NSString).lastPathComponent)"
            }
        } else {
            titleText = info.split(separator: " ").first.map(String.init) ?? ""
        }
        let title = NSTextField(labelWithString: titleText)
        title.font = .systemFont(ofSize: 10, weight: .medium)
        title.textColor = .secondaryLabelColor
        title.lineBreakMode = .byTruncatingMiddle
        title.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let copy = ClosureButton(title: "Copy", target: nil, action: nil)
        copy.bezelStyle = .inline
        copy.controlSize = .small
        if GlassBars.enabled { GlassBars.style(copy) }
        copy.onChange = { _ in
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
        var headerViews: [NSView] = [title, NSView(), copy]
        if let p = proposal {
            if let r = message.resolvedProposals[p.blockIndex] {
                let l = NSTextField(labelWithString: r == .accepted ? "Applied" : "Rejected")
                l.font = .systemFont(ofSize: 10, weight: .semibold)
                l.textColor = r == .accepted ? .systemGreen : .secondaryLabelColor
                headerViews.append(l)
            }
            let review = ClosureButton(title: "Review…", target: nil, action: nil)
            review.bezelStyle = .inline
            review.controlSize = .small
            if GlassBars.enabled { GlassBars.style(review) }
            review.toolTip = "Compare the proposed change with the file, then accept or reject it"
            review.onChange = { [weak self] _ in self?.onReview?(p) }
            reviewButtons.append(review)
            headerViews.append(review)
        }
        let header = NSStackView(views: headerViews)
        header.orientation = .horizontal
        header.spacing = 4
        let code = NSTextField(wrappingLabelWithString: text)
        code.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        code.isSelectable = true
        code.drawsBackground = true
        code.backgroundColor = .textBackgroundColor
        code.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        box.addArrangedSubview(header)
        box.addArrangedSubview(code)
        header.translatesAutoresizingMaskIntoConstraints = false
        code.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            header.widthAnchor.constraint(equalTo: box.widthAnchor),
            code.widthAnchor.constraint(equalTo: box.widthAnchor),
        ])
        box.wantsLayer = true
        box.layer?.borderWidth = 1
        box.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.32).cgColor
        box.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.42).cgColor
        box.layer?.cornerRadius = 12
        box.layer?.cornerCurve = .continuous
        box.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        return box
    }
}
