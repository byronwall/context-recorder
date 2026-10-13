import AppKit
import SwiftUI

/// What the library window shows: the sessions, the one that's open, and the shared recorder.
@MainActor @Observable
final class LibraryState {
    let library: SessionLibrary
    let recorder: RecorderController
    init(includeDefaultRoot: Bool, recorder: RecorderController) {
        library = SessionLibrary(includeDefaultRoot: includeDefaultRoot)
        self.recorder = recorder
    }
    var showShortcuts = false
    var selection: URL? {
        didSet {
            guard selection != oldValue else { return }
            model?.tearDown()
            model = selection.map { SessionModel(folder: $0) }
        }
    }
    private(set) var model: SessionModel?
    /// The Record button in the window: start, and get the window out of the way.
    @ObservationIgnored var startFromWindow: () -> Void = {}

    /// Rebuild the open session from disk, e.g. once a recording's .mp4 is finished.
    func reopen() {
        model?.tearDown()
        model = selection.map { SessionModel(folder: $0) }
    }

    /// Whether `folder` is the recording in progress (shown live rather than as a saved session).
    func isLive(_ folder: URL) -> Bool {
        folder == recorder.recordingFolder && recorder.phase != .idle
    }
}

/// The session library and the app's home window. While it's open (or a recording is running) the app
/// has a Dock icon and menus; otherwise it lives in the menu bar.
@MainActor
final class LibraryWindowController: NSWindowController, NSWindowDelegate {
    let state: LibraryState
    /// Called when the window shows or closes, so the app can update its Dock presence.
    var onVisibilityChange: (() -> Void)?
    private var keyMonitor: Any?
    private var changeWatch: Task<Void, Never>?
    /// The last app the user was in other than us, to hand focus back to when recording starts from here.
    private var previousApp: NSRunningApplication?

    init(recorder: RecorderController, includeDefaultRoot: Bool = true) {
        state = LibraryState(includeDefaultRoot: includeDefaultRoot, recorder: recorder)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1320, height: 820),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.title = "Sessions"
        window.toolbarStyle = .unified
        window.minSize = NSSize(width: 900, height: 560)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        let host = NSHostingController(rootView: LibraryView(state: state).environment(recorder))
        host.sizingOptions = []   // keep the window's own size instead of shrinking to the content's ideal size
        window.contentViewController = host
        window.setContentSize(NSSize(width: 1320, height: 820))
        window.center()
        window.setFrameAutosaveName("SessionLibrary")
        window.delegate = self
        state.startFromWindow = { [weak self] in self?.startRecordingFromWindow() }
        observeLibraryChanges()
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated {
                if let app, app != .current { self?.previousApp = app }
            }
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    var isVisible: Bool { window?.isVisible == true }

    /// Shows the window in front of everything. `session` selects a session folder (or the newest in a
    /// folder of sessions); `reload` rebuilds it even if it's already open.
    func show(session: URL? = nil, reload: Bool = false) {
        if let session {
            // A session folder, or a folder of sessions (then the newest is opened).
            let found = state.library.add(folder: session)
            let target = found.contains(session) ? session
                : state.library.entries.first { found.contains($0.url) }?.url ?? found.first
            if reload, target == state.selection { state.reopen() } else { state.selection = target }
        } else if state.selection == nil {
            state.selection = state.library.entries.first?.url
        }
        NSApp.setActivationPolicy(.regular)
        MainMenu.install()
        showWindow(nil)
        if window?.isMiniaturized == true { window?.deminiaturize(nil) }
        // Activation is a request macOS can turn down when another app is in front; ordering the window
        // front regardless means it's at least on top and one click away, never hidden behind.
        window?.orderFrontRegardless()
        window?.makeKey()
        NSApp.activate()
        installKeyMonitor()
        onVisibilityChange?()
    }

    /// Record button in the window: the window steps aside so you're back in the app you were using.
    private func startRecordingFromWindow() {
        guard state.recorder.phase == .idle else { return }
        state.recorder.start()
        if let previousApp, !previousApp.isTerminated {
            window?.orderOut(nil)
            previousApp.activate()
        } else {
            window?.miniaturize(nil)
        }
    }

    func openFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Open Session"
        panel.message = "Choose a session folder, or a folder that contains sessions."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let found = state.library.add(folder: url)
        if let first = found.first { show(session: first) } else { NSSound.beep() }
    }

    func windowWillClose(_ notification: Notification) {
        state.model?.player.pause()
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        DispatchQueue.main.async { [weak self] in self?.onVisibilityChange?() }
    }

    /// Reload the open session when re-processing rewrites its session.json.
    private func observeLibraryChanges() {
        changeWatch = Task { [weak self] in
            var last = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                let token = self.state.library.changeToken
                if token != last { last = token; self.state.model?.reload() }
            }
        }
    }

    /// Space, J/K, ←/→ work anywhere in the window except while typing.
    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window === self.window, let model = self.state.model,
                  !self.state.isLive(model.folder) else { return event }
            if self.window?.firstResponder is NSText { return event }
            if !event.modifierFlags.intersection([.command, .control, .option]).isEmpty { return event }
            switch event.keyCode {
            case 49: model.togglePlay()                       // space
            case 38: model.step(1)                            // j
            case 40: model.step(-1)                           // k
            case 124: model.skip(5)                           // →
            case 123: model.skip(-5)                          // ←
            default: return event
            }
            return nil
        }
    }
}

/// Menus shown while the library window makes the app a regular app.
@MainActor
enum MainMenu {
    static func install() {
        guard NSApp.mainMenu?.items.first?.submenu?.title != "Context Recorder" else { return }
        let main = NSMenu()

        let app = submenu(main, "Context Recorder")
        app.addItem(withTitle: "About Context Recorder", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        app.addItem(.separator())
        app.addItem(withTitle: "Hide Context Recorder", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        app.addItem(.separator())
        app.addItem(withTitle: "Quit Context Recorder", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let file = submenu(main, "File")
        file.addItem(withTitle: "Open Session Folder…", action: #selector(AppDelegate.openSessionFolder), keyEquivalent: "o")
        file.addItem(.separator())
        file.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")

        let recording = submenu(main, "Recording")
        recording.autoenablesItems = true
        for (title, action, key, symbol) in [
            ("Start Recording", #selector(AppDelegate.toggleRecording), "r", "record.circle"),
            ("Mark Moment", #selector(AppDelegate.markMoment), "m", "flag"),
            ("Screenshot Region", #selector(AppDelegate.screenshotRegion), "s", "viewfinder"),
        ] {
            let item = recording.addItem(withTitle: title, action: action, keyEquivalent: key)
            item.keyEquivalentModifierMask = [.control, .option]
            item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        }
        recording.addItem(.separator())
        recording.addItem(withTitle: "Record Microphone", action: #selector(AppDelegate.toggleMicrophone), keyEquivalent: "")
            .image = NSImage(systemSymbolName: "mic", accessibilityDescription: nil)
        recording.addItem(withTitle: "Show Recording Controls", action: #selector(AppDelegate.showRecordingControls), keyEquivalent: "")
            .image = NSImage(systemSymbolName: "macwindow", accessibilityDescription: nil)

        let edit = submenu(main, "Edit")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        let view = submenu(main, "View")
        view.addItem(withTitle: "Toggle Sidebar", action: #selector(NSSplitViewController.toggleSidebar(_:)), keyEquivalent: "s")
            .keyEquivalentModifierMask = [.command, .control]
        view.addItem(withTitle: "Enter Full Screen", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")
            .keyEquivalentModifierMask = [.command, .control]

        let window = submenu(main, "Window")
        window.addItem(withTitle: "Sessions", action: #selector(AppDelegate.openLibrary), keyEquivalent: "0")
        window.addItem(.separator())
        window.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        window.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        NSApp.windowsMenu = window

        let help = submenu(main, "Help")
        help.addItem(withTitle: "Keyboard Shortcuts", action: #selector(AppDelegate.showShortcuts), keyEquivalent: "/")
        NSApp.helpMenu = help

        NSApp.mainMenu = main
    }

    private static func submenu(_ main: NSMenu, _ title: String) -> NSMenu {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let menu = NSMenu(title: title)
        item.submenu = menu
        main.addItem(item)
        return menu
    }
}
