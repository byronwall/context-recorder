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

    private let panel: NSPanel
    private let status = NSTextField(labelWithString: "Ready")
    private let recordButton = NSButton(title: "Start Recording", target: nil, action: nil)
    private let markButton = NSButton(title: "🚩 Mark", target: nil, action: nil)
    private let shotButton = NSButton(title: "📸 Region", target: nil, action: nil)
    private let chromeLabel = NSTextField(labelWithString: "")
    private let micCheck = NSButton(checkboxWithTitle: "Record microphone", target: nil, action: nil)
    private let actions: Actions

    init(actions: Actions) {
        self.actions = actions
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 300, height: 150),
                        styleMask: [.titled, .closable, .utilityWindow, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        super.init()
        panel.title = "Context Recorder"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        status.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        let hint = NSTextField(labelWithString: "⌃⌥R start/stop · ⌃⌥M mark · ⌃⌥S region shot")
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor

        for (button, sel) in [(recordButton, #selector(onRecord)), (markButton, #selector(onMark)),
                              (shotButton, #selector(onShot)), (micCheck, #selector(onMic))] {
            button.target = self
            button.action = sel
        }
        recordButton.bezelColor = .systemRed
        recordButton.keyEquivalent = "\r"

        let viewer = NSButton(title: "Last Viewer", target: self, action: #selector(onViewer))
        let quit = NSButton(title: "Quit", target: self, action: #selector(onQuit))
        for b in [viewer, quit] { b.controlSize = .small; b.font = .systemFont(ofSize: 11) }

        chromeLabel.font = .systemFont(ofSize: 11)
        chromeLabel.textColor = .secondaryLabelColor
        let statusRow = NSStackView(views: [status, NSView(), chromeLabel])
        let row1 = NSStackView(views: [recordButton, markButton, shotButton])
        let row2 = NSStackView(views: [micCheck, NSView(), viewer, quit])
        let stack = NSStackView(views: [statusRow, row1, row2, hint])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 14, bottom: 12, right: 14)
        row2.widthAnchor.constraint(equalTo: row1.widthAnchor).isActive = true
        statusRow.widthAnchor.constraint(equalTo: row1.widthAnchor).isActive = true
        panel.contentView = stack
    }

    func show() {
        if !panel.isVisible, let screen = NSScreen.main {
            panel.layoutIfNeeded()
            let f = screen.visibleFrame
            panel.setFrameTopLeftPoint(NSPoint(x: f.maxX - panel.frame.width - 20, y: f.maxY - 20))
        }
        panel.orderFrontRegardless()
    }

    func update(status text: String, recording: Bool, busy: Bool, microphone: Bool, chromeConnected: Bool) {
        status.stringValue = text
        chromeLabel.stringValue = chromeConnected ? "Chrome ● connected" : "Chrome ○ no extension"
        chromeLabel.textColor = chromeConnected ? .systemGreen : .secondaryLabelColor
        recordButton.title = recording ? "Stop" : "Start Recording"
        recordButton.isEnabled = !busy
        markButton.isEnabled = recording
        shotButton.isEnabled = recording
        micCheck.state = microphone ? .on : .off
        micCheck.isEnabled = !recording && !busy
    }

    @objc private func onRecord() { actions.toggleRecording() }
    @objc private func onMark() { actions.mark() }
    @objc private func onShot() { actions.screenshot() }
    @objc private func onMic() { actions.toggleMicrophone() }
    @objc private func onViewer() { actions.openLastViewer() }
    @objc private func onQuit() { actions.quit() }
}
