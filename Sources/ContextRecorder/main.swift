import AppKit
import Carbon

/// One app, three views of the same recorder:
///   - the Sessions window: home. Record from its sidebar, watch a recording live, review sessions.
///   - the recording HUD: floats over your work only while recording.
///   - the menu-bar item: status at a glance, quick actions and recent sessions.
/// Hotkeys (global): ⌃⌥R start / stop, ⌃⌥M mark, ⌃⌥S region screenshot.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSMenuItemValidation {
    /// `--library <folder>` opens only the session library on that folder (no recording, hotkeys or
    /// permission prompts), for working on the library UI next to an installed copy of the app.
    private let devLibraryFolder: URL? = {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--library"), i + 1 < args.count else { return nil }
        return URL(fileURLWithPath: args[i + 1]).standardizedFileURL
    }()
    private lazy var recorder = RecorderController(canRecord: devLibraryFolder == nil)
    private lazy var library = LibraryWindowController(recorder: recorder, includeDefaultRoot: devLibraryFolder == nil)
    private var hud: RecordingHUDController?
    private var statusItem: NSStatusItem?
    private var flashText: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        library.onVisibilityChange = { [weak self] in self?.updatePresence() }
        // Stopping always lands you on the new session: processing progress first, then the session itself.
        recorder.onFinished = { [weak self] folder in self?.library.show(session: folder, reload: true) }
        recorder.onProcessed = { [weak self] folder, ok in self?.didProcess(folder, ok: ok) }
        recorder.onFlash = { [weak self] text in self?.flash(text) }
        MainMenu.install()

        if let devLibraryFolder {
            startDevRun(devLibraryFolder)
            return
        }

        setUpStatusItem()
        hud = RecordingHUDController(recorder: recorder) { [weak self] in self?.library.show() }
        observeContinuously { [weak self] in
            self?.updateStatusTitle()
            self?.updatePresence()
        }

        let mods = controlKey | optionKey
        HotKeys.shared.register(keyCode: kVK_ANSI_R, modifiers: mods) { [weak self] in self?.recorder.toggle() }
        HotKeys.shared.register(keyCode: kVK_ANSI_M, modifiers: mods) { [weak self] in self?.recorder.mark() }
        HotKeys.shared.register(keyCode: kVK_ANSI_S, modifiers: mods) { [weak self] in self?.recorder.screenshot() }

        // Ask for screen-recording permission up front so the first recording doesn't fail.
        if !CGPreflightScreenCaptureAccess() { CGRequestScreenCaptureAccess() }
        library.show()
    }

    private func startDevRun(_ folder: URL) {
        if let look = ProcessInfo.processInfo.environment["CR_APPEARANCE"] {   // light | dark, for screenshots
            NSApp.appearance = NSAppearance(named: look == "dark" ? .darkAqua : .aqua)
        }
        library.show(session: folder)
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--mark"), i + 1 < args.count, let n = Int(args[i + 1]) {
            library.state.model?.select(n)   // `--mark <n>` opens that mark too
        }
        // `--demo recording|processing|failed` fakes that state on the open session, to work on those views.
        if let i = args.firstIndex(of: "--demo"), i + 1 < args.count, let open = library.state.selection {
            switch args[i + 1] {
            case "recording":
                recorder.demoRecording(in: open)
                hud = RecordingHUDController(recorder: recorder) { [weak self] in self?.library.show() }
            case "processing": recorder.demoPending(open, failed: false)
            case "failed": recorder.demoPending(open, failed: true)
            default: break
            }
        }
    }

    /// `open "Context Recorder.app"` while running, or clicking it in Finder/Dock, brings the Sessions window back.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        library.show()
        return false
    }

    /// Quitting mid-recording finishes the video first, so it's never left unplayable.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard recorder.isRecording else { return .terminateNow }
        Task { @MainActor in
            await recorder.stopForQuit()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    /// Dock icon and menus while the Sessions window is open or a recording is running; menu bar only otherwise.
    private func updatePresence() {
        guard devLibraryFolder == nil else { return }
        let regular = library.isVisible || recorder.phase != .idle
        let policy: NSApplication.ActivationPolicy = regular ? .regular : .accessory
        if NSApp.activationPolicy() != policy { NSApp.setActivationPolicy(policy) }
    }

    private func didProcess(_ folder: URL, ok: Bool) {
        library.state.library.refresh()
        if library.state.selection == folder { library.state.model?.reload() }
        // Nudge the Dock icon if you've moved on to something else.
        if !NSApp.isActive, library.isVisible { NSApp.requestUserAttention(.informationalRequest) }
    }

    // MARK: Menu-bar item

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = "ContextRecorder"
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item
    }

    /// Built each time it opens, so the status line and recent sessions are current.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let header = NSMenuItem(title: statusLine, action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())
        menu.addItem(item("Start Recording", #selector(toggleRecording), symbol: "record.circle", key: "r"))
        menu.addItem(item("Mark Moment", #selector(markMoment), symbol: "flag", key: "m"))
        menu.addItem(item("Screenshot Region", #selector(screenshotRegion), symbol: "viewfinder", key: "s"))
        menu.addItem(.separator())
        menu.addItem(item("Record Microphone", #selector(toggleMicrophone), symbol: "mic"))
        if recorder.isRecording {
            menu.addItem(item("Show Recording Controls", #selector(showRecordingControls), symbol: "macwindow"))
        }
        menu.addItem(.separator())
        menu.addItem(item("Open Sessions", #selector(openLibrary), symbol: "rectangle.stack"))
        let recent = library.state.library.entries.filter { !library.state.isLive($0.url) }.prefix(5)
        if !recent.isEmpty {
            menu.addItem(.sectionHeader(title: "Recent"))
            for entry in recent {
                let row = item(recentTitle(entry), #selector(openRecent(_:)))
                row.subtitle = recentSubtitle(entry)
                row.representedObject = entry.url
                menu.addItem(row)
            }
        }
        menu.addItem(.separator())
        menu.addItem(item("Open Sessions Folder", #selector(openSessionsFolder), symbol: "folder"))
        menu.addItem(item("Quit Context Recorder", #selector(NSApplication.terminate(_:)), key: "q", modifiers: .command, target: NSApp))
    }

    /// `key` only displays the global hotkey (⌃⌥ by default) next to the item; HotKeys does the real work.
    private func item(_ title: String, _ action: Selector, symbol: String? = nil, key: String = "",
                      modifiers: NSEvent.ModifierFlags = [.control, .option], target: AnyObject? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        item.target = target ?? self
        if let symbol { item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) }
        return item
    }

    private var statusLine: String {
        switch recorder.phase {
        case .starting: return "Starting…"
        case .stopping: return "Saving recording…"
        case .recording:
            let n = recorder.liveMarks.count
            return "Recording · \(Format.time(recorder.elapsed)) · " + (n == 1 ? "1 mark" : "\(n) marks")
        case .idle:
            let n = recorder.processing.count
            if n > 0 { return n == 1 ? "Processing a session…" : "Processing \(n) sessions…" }
            return recorder.chromeConnected ? "Ready · Chrome connected" : "Ready"
        }
    }

    private func recentTitle(_ entry: SessionEntry) -> String {
        guard let d = entry.date else { return entry.url.lastPathComponent }
        let day = Calendar.current.isDateInToday(d) ? "Today"
            : Calendar.current.isDateInYesterday(d) ? "Yesterday" : d.formatted(.dateTime.month(.abbreviated).day())
        return "\(day), \(d.formatted(date: .omitted, time: .shortened))"
    }

    private func recentSubtitle(_ entry: SessionEntry) -> String {
        if recorder.processing.contains(entry.url) { return "Processing…" }
        if !entry.processed { return "Not processed" }
        let n = entry.markCount
        return [entry.duration.map(Format.time), n == 1 ? "1 mark" : "\(n) marks"].compactMap { $0 }.joined(separator: " · ")
    }

    /// Titles, checkmarks and enabled state for both the menu-bar menu and the main menu's Recording menu.
    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        switch item.action {
        case #selector(toggleRecording):
            let recording = recorder.isRecording
            item.title = recording ? "Stop Recording" : "Start Recording"
            item.image = NSImage(systemSymbolName: recording ? "stop.fill" : "record.circle", accessibilityDescription: nil)
            return recorder.canRecord && !recorder.isBusy
        case #selector(markMoment), #selector(screenshotRegion):
            return recorder.phase == .recording
        case #selector(toggleMicrophone):
            item.state = recorder.recordMicrophone ? .on : .off
            return recorder.canRecord && recorder.phase == .idle
        case #selector(showRecordingControls):
            return recorder.isRecording
        default:
            return true
        }
    }

    private func updateStatusTitle() {
        guard let button = statusItem?.button else { return }
        button.imagePosition = .imageLeading
        button.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        let title: String
        switch recorder.phase {
        case .idle where !recorder.processing.isEmpty:
            button.image = NSImage(systemSymbolName: "hourglass", accessibilityDescription: "Processing")
            title = ""
        case .idle:
            button.image = NSImage(systemSymbolName: "record.circle", accessibilityDescription: "Context Recorder")
            title = ""
        case .starting, .recording, .stopping:
            button.image = NSImage(systemSymbolName: "record.circle.fill", accessibilityDescription: "Recording")?
                .withSymbolConfiguration(.init(paletteColors: [.systemRed]))
            let n = recorder.liveMarks.count
            title = recorder.phase == .recording ? " \(Format.time(recorder.elapsed))" + (n > 0 ? "  ⚑\(n)" : "") : ""
        }
        button.title = flashText.map { " \($0)" } ?? title
    }

    private func flash(_ text: String) {
        flashText = text
        updateStatusTitle()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
            guard self?.flashText == text else { return }
            self?.flashText = nil
            self?.updateStatusTitle()
        }
    }

    // MARK: Actions (menu-bar menu and main menu)

    @objc func toggleRecording() { recorder.toggle() }
    @objc func markMoment() { recorder.mark() }
    @objc func screenshotRegion() { recorder.screenshot() }
    @objc func toggleMicrophone() { recorder.recordMicrophone.toggle() }
    @objc func showRecordingControls() { hud?.show() }
    @objc func openLibrary() { library.show() }
    @objc func openSessionFolder() { library.openFolder() }
    @objc func showShortcuts() {
        library.show()
        library.state.showShortcuts = true
    }
    @objc private func openRecent(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        library.show(session: url)
    }
    @objc private func openSessionsFolder() {
        try? FileManager.default.createDirectory(at: Session.root, withIntermediateDirectories: true)
        NSWorkspace.shared.open(Session.root)
    }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
