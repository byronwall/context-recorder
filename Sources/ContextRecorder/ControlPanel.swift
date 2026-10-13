import AppKit

/// Small floating panel so the app is usable even when the menu-bar item is hidden (notch / crowded bar).
/// Shown at launch and whenever the app is opened again. Excluded from the recording.
final class ControlPanel: NSObject {
    struct Actions {
        var toggleRecording: () -> Void
        var mark: () -> Void
        var screenshot: () -> Void
        var toggleMicrophone: () -> Void
        var openLastViewer: () -> Void
        var quit: () -> Void
    }

    enum State: Equatable {
        case ready
        case starting
        case recording(elapsed: TimeInterval, marks: Int)
        case processing
    }

    private let panel: NSPanel
    private let dot = StatusDot()
    private let headline = NSTextField(labelWithString: "Ready")
    private let caption = NSTextField(labelWithString: "Not recording")
    private let chromePill = Pill()
    private let recordButton = NSButton()
    private let markButton = NSButton()
    private let shotButton = NSButton()
    private let micSwitch = NSSwitch()
    private let actions: Actions

    init(actions: Actions) {
        self.actions = actions
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 320, height: 200),
                        styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel, .utilityWindow],
                        backing: .buffered, defer: false)
        super.init()
        panel.title = "Context Recorder"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        // Header: status dot + timer, Chrome pill on the right.
        headline.font = .monospacedDigitSystemFont(ofSize: 22, weight: .semibold)
        caption.font = .systemFont(ofSize: 11.5)
        caption.textColor = .secondaryLabelColor
        let titles = NSStackView(views: [headline, caption])
        titles.orientation = .vertical
        titles.alignment = .leading
        titles.spacing = 0
        let header = NSStackView(views: [dot, titles, NSView(), chromePill])
        header.alignment = .centerY
        header.spacing = 10

        // Primary action, then the two in-recording actions.
        configure(recordButton, symbol: "record.circle.fill", title: "Start Recording", action: #selector(onRecord))
        recordButton.bezelColor = .systemRed
        recordButton.keyEquivalent = "\r"
        configure(markButton, symbol: "flag.fill", title: "Mark", action: #selector(onMark))
        configure(shotButton, symbol: "viewfinder", title: "Region", action: #selector(onShot))
        markButton.toolTip = "Mark this moment (⌃⌥M)"
        shotButton.toolTip = "Screenshot a region (⌃⌥S)"
        let secondary = NSStackView(views: [markButton, shotButton])
        secondary.distribution = .fillEqually
        secondary.spacing = 8

        // Footer: microphone switch, viewer + quit as quiet icon buttons.
        micSwitch.controlSize = .mini
        micSwitch.target = self
        micSwitch.action = #selector(onMic)
        let micLabel = NSTextField(labelWithString: "Microphone")
        micLabel.font = .systemFont(ofSize: 12)
        micLabel.textColor = .secondaryLabelColor
        let viewer = iconButton("play.rectangle", tip: "Sessions", action: #selector(onViewer))
        let quit = iconButton("power", tip: "Quit Context Recorder", action: #selector(onQuit))
        let footer = NSStackView(views: [micSwitch, micLabel, NSView(), viewer, quit])
        footer.alignment = .centerY
        footer.spacing = 6

        let hint = NSTextField(labelWithString: "⌃⌥R Record   ·   ⌃⌥M Mark   ·   ⌃⌥S Region")
        hint.font = .systemFont(ofSize: 10.5)
        hint.textColor = .tertiaryLabelColor

        let separator = NSBox()
        separator.boxType = .separator

        let stack = NSStackView(views: [header, recordButton, secondary, separator, footer, hint])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.setCustomSpacing(16, after: header)
        stack.setCustomSpacing(12, after: secondary)
        stack.setCustomSpacing(12, after: separator)
        stack.setCustomSpacing(8, after: footer)
        stack.edgeInsets = NSEdgeInsets(top: 28, left: 16, bottom: 14, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false
        for view in [header, recordButton, secondary, separator, footer] {
            view.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -32).isActive = true
        }

        let background = NSVisualEffectView()
        background.material = .hudWindow
        background.blendingMode = .behindWindow
        background.state = .active
        background.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            stack.topAnchor.constraint(equalTo: background.topAnchor),
            stack.bottomAnchor.constraint(equalTo: background.bottomAnchor),
            background.widthAnchor.constraint(equalToConstant: 320),
        ])
        panel.contentView = background
    }

    private func configure(_ button: NSButton, symbol: String, title: String, action: Selector) {
        button.bezelStyle = .rounded
        button.controlSize = .large
        button.title = title
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        button.imagePosition = .imageLeading
        button.imageHugsTitle = true
        button.target = self
        button.action = action
    }

    private func iconButton(_ symbol: String, tip: String, action: Selector) -> NSButton {
        let button = NSButton(image: NSImage(systemSymbolName: symbol, accessibilityDescription: tip)!, target: self, action: action)
        button.isBordered = false
        button.contentTintColor = .secondaryLabelColor
        button.toolTip = tip
        button.symbolConfiguration = .init(pointSize: 13, weight: .regular)
        return button
    }

    func show() {
        if !panel.isVisible, let screen = NSScreen.main {
            panel.layoutIfNeeded()
            let f = screen.visibleFrame
            panel.setFrameTopLeftPoint(NSPoint(x: f.maxX - panel.frame.width - 20, y: f.maxY - 20))
        }
        panel.orderFrontRegardless()
    }

    func update(state: State, microphone: Bool, chromeConnected: Bool) {
        let recording: Bool
        switch state {
        case .ready:
            recording = false
            headline.stringValue = "Ready"
            caption.stringValue = "Not recording"
            dot.style = .idle
        case .starting:
            recording = true
            headline.stringValue = "0:00"
            caption.stringValue = "Starting…"
            dot.style = .recording
        case let .recording(elapsed, marks):
            recording = true
            let t = Int(elapsed)
            headline.stringValue = String(format: "%d:%02d", t / 60, t % 60)
            caption.stringValue = marks == 0 ? "Recording · no marks yet" : "Recording · \(marks) mark\(marks == 1 ? "" : "s")"
            dot.style = .recording
        case .processing:
            recording = false
            headline.stringValue = "Processing"
            caption.stringValue = "Building the viewer…"
            dot.style = .busy
        }
        let busy = state == .processing

        recordButton.title = recording ? "Stop Recording" : "Start Recording"
        recordButton.image = NSImage(systemSymbolName: recording ? "stop.fill" : "record.circle.fill", accessibilityDescription: nil)
        recordButton.bezelColor = recording ? nil : .systemRed
        recordButton.isEnabled = !busy
        markButton.isEnabled = recording
        shotButton.isEnabled = recording
        micSwitch.state = microphone ? .on : .off
        micSwitch.isEnabled = !recording && !busy
        chromePill.set(text: chromeConnected ? "Chrome" : "No Chrome", color: chromeConnected ? .systemGreen : .tertiaryLabelColor,
                       tip: chromeConnected ? "Browser extension connected" : "Browser extension not connected")
    }

    @objc private func onRecord() { actions.toggleRecording() }
    @objc private func onMark() { actions.mark() }
    @objc private func onShot() { actions.screenshot() }
    @objc private func onMic() { actions.toggleMicrophone() }
    @objc private func onViewer() { actions.openLastViewer() }
    @objc private func onQuit() { actions.quit() }
}

/// Colored status dot; pulses while recording.
private final class StatusDot: NSView {
    enum Style { case idle, recording, busy }
    var style: Style = .idle { didSet { if style != oldValue { restyle() } } }
    private let core = CALayer()
    private let halo = CALayer()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        for l in [halo, core] { layer?.addSublayer(l) }
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 22).isActive = true
        heightAnchor.constraint(equalToConstant: 22).isActive = true
        restyle()
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        halo.frame = bounds
        halo.cornerRadius = bounds.width / 2
        core.frame = bounds.insetBy(dx: 6, dy: 6)
        core.cornerRadius = core.frame.width / 2
    }

    private func restyle() {
        let color: NSColor = switch style {
        case .idle: .systemGray
        case .recording: .systemRed
        case .busy: .systemOrange
        }
        effectiveAppearance.performAsCurrentDrawingAppearance {
            core.backgroundColor = color.cgColor
            halo.backgroundColor = color.withAlphaComponent(0.22).cgColor
        }
        halo.removeAllAnimations()
        guard style != .idle else { return }
        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 1
        pulse.toValue = 0.15
        pulse.duration = style == .recording ? 0.9 : 0.6
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        halo.add(pulse, forKey: "pulse")
    }
}

/// Rounded capsule with a small dot and label, used for the Chrome connection state.
private final class Pill: NSView {
    private let dot = NSView()
    private let label = NSTextField(labelWithString: "")

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.borderWidth = 1
        dot.wantsLayer = true
        dot.layer?.cornerRadius = 3
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = .secondaryLabelColor
        let row = NSStackView(views: [dot, label])
        row.spacing = 5
        row.edgeInsets = NSEdgeInsets(top: 3, left: 8, bottom: 3, right: 9)
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            dot.widthAnchor.constraint(equalToConstant: 6), dot.heightAnchor.constraint(equalToConstant: 6),
            row.leadingAnchor.constraint(equalTo: leadingAnchor), row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.topAnchor.constraint(equalTo: topAnchor), row.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    func set(text: String, color: NSColor, tip: String) {
        label.stringValue = text
        toolTip = tip
        effectiveAppearance.performAsCurrentDrawingAppearance {
            dot.layer?.backgroundColor = color.cgColor
            layer?.borderColor = NSColor.separatorColor.cgColor
            layer?.backgroundColor = NSColor.quaternaryLabelColor.withAlphaComponent(0.06).cgColor
        }
    }
}
