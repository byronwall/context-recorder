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
    var showChromeSetup = false
    /// Sidebar selection. One session is open when exactly one is selected; several can be trashed together.
    var selection: Set<URL> = [] {
        didSet {
            guard selection != oldValue else { return }
            let open = selection.count == 1 ? selection.first : nil
            guard open != model?.folder else { return }
            model?.tearDown()
            model = open.map { SessionModel(folder: $0) }
        }
    }
    private(set) var model: SessionModel?
    /// The session whose name is being edited in the sidebar.
    var renaming: URL?
    /// Sessions waiting for the user to confirm Move to Trash.
    var confirmTrash: [URL] = []

    func open(_ url: URL?) { selection = url.map { [$0] } ?? [] }

    /// Asks before trashing; the session being recorded or processed is never included.
    func requestTrash(_ urls: some Collection<URL>) {
        confirmTrash = urls.filter { !isLive($0) && !recorder.processing.contains($0) }
    }

    /// "Joining…" while a join is being processed, or why it failed.
    var joinStatus: String?

    /// Joins the selected sessions into a new one and opens it.
    func join(_ urls: some Collection<URL>) {
        let urls = Array(urls)
        joinStatus = "Joining \(urls.count) sessions…"
        Task {
            do {
                let folder = try SessionJoin.join(urls)
                try await SessionProcessing.run(folder)
                library.refresh()
                joinStatus = nil
                open(folder)
            } catch {
                joinStatus = error.localizedDescription
            }
        }
    }

    func trashConfirmed() {
        let urls = confirmTrash
        confirmTrash = []
        selection.subtract(urls)
        if urls.contains(where: { $0 == model?.folder }) { model?.tearDown(); model = nil }
        library.trash(urls)
    }

    /// The Record button in the window: start, and get the window out of the way.
    @ObservationIgnored var startFromWindow: () -> Void = {}

    /// Rebuild the open session from disk, e.g. once a recording's .mp4 is finished.
    func reopen() {
        model?.tearDown()
        model = (selection.count == 1 ? selection.first : nil).map { SessionModel(folder: $0) }
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
    /// This window belongs in recordings (reviewing the app with the app); the recording controls don't.
    var recordedWindows: Set<CGWindowID> {
        guard let window, window.windowNumber > 0 else { return [] }
        return [CGWindowID(window.windowNumber)]
    }
    /// The last app the user was in other than us, to hand focus back to when recording starts from here.
    private var previousApp: NSRunningApplication?

    init(recorder: RecorderController, includeDefaultRoot: Bool = true) {
        state = LibraryState(includeDefaultRoot: includeDefaultRoot, recorder: recorder)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1320, height: 820),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.title = "Sessions"
        window.toolbarStyle = .unified
        // Sidebar (240) + inspector (360) at their default widths, plus room for the compact transport.
        window.minSize = NSSize(width: 980, height: 560)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        let host = NSHostingController(rootView: LibraryView(state: state).frame(minWidth: 0, minHeight: 0).environment(recorder))
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
            if reload, let target, state.selection == [target] { state.reopen() } else { state.open(target) }
        } else if state.selection.isEmpty {
            state.open(state.library.entries.first?.url)
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
        state.model?.viewer?.save()
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
            guard let self, event.window === self.window else { return event }
            if self.window?.firstResponder is NSText { return event }
            // The image viewer's canvas has its own keys (Esc, arrows, zoom, tools).
            if self.state.model?.viewer != nil { return event }
            if event.keyCode == 51, event.modifierFlags.intersection([.command, .control, .option, .shift]) == .command {
                self.state.requestTrash(self.state.selection)
                return nil
            }
            // A recording in progress shows live; review keys apply to saved sessions only.
            guard let model = self.state.model, !self.state.isLive(model.folder) else { return event }
            // ⌘Z / ⇧⌘Z undo and redo cuts (text fields keep their own undo; see the NSText check above).
            if event.keyCode == 6, event.modifierFlags.intersection([.command, .control, .option]) == .command {
                if event.modifierFlags.contains(.shift) { model.redoEdit() } else { model.undoEdit() }
                return nil
            }
            if !event.modifierFlags.intersection([.command, .control, .option]).isEmpty { return event }
            if model.canvasSelecting {
                if event.keyCode == 53 { model.canvasSelecting = false; NSCursor.arrow.set(); return nil }   // esc
                return event
            }
            // Draw mode: RegionShot's tool keys; Delete removes the selected drawing; E or Esc leaves.
            if model.drawMode {
                let key = event.charactersIgnoringModifiers?.lowercased().first
                if let tool = AnnotationTool.available.first(where: { $0.key == key }) { model.tool = tool; return nil }
                switch event.keyCode {
                case 14: model.enterDrawMode(false); return nil                       // e
                case 53:                                                              // esc
                    if model.selectedAnnotation != nil { model.selectedAnnotation = nil }
                    else if model.tool != .select { model.tool = .select }
                    else { model.enterDrawMode(false) }
                    return nil
                case 51, 117: model.deleteSelectedAnnotation(); return nil            // delete
                case 49: return nil                                                   // space: stay paused while drawing
                default: break
                }
            }
            if model.regionMode {
                if event.keyCode == 53 { model.regionMode = false; model.regionPurpose = .shot; NSCursor.arrow.set(); return nil }   // esc
                return event
            }
            switch event.keyCode {
            case 46:                                          // m
                if model.stage == .canvas { Task { await model.markFromCanvas() } } else { Task { await model.addReviewMark() } }
            case 1:                                           // s
                if model.stage == .canvas { model.startCanvasShot() } else { model.startShot() }
            case 8:                                           // c
                guard model.canvas != nil else { return event }
                if model.drawMode { model.enterDrawMode(false) }
                model.stage = model.stage == .canvas ? .video : .canvas
            case 49: model.togglePlay()                       // space
            case 38: model.step(1)                            // j
            case 40: model.step(-1)                           // k
            case 124: model.skip(5)                           // →
            case 123: model.skip(-5)                          // ←
            case 14: model.enterDrawMode(true)                // e
            case 34: model.setSelectionEdge(start: true)      // i
            case 31: model.setSelectionEdge(start: false)     // o
            case 51 where model.selection != nil: model.cutSelection()   // delete
            case 53 where model.selection != nil: model.selection = nil  // esc
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
        app.addItem(withTitle: "Cloud Settings…", action: #selector(AppDelegate.showCloudSettings), keyEquivalent: ",")
        app.addItem(withTitle: "Open Cloud Library", action: #selector(AppDelegate.openCloudLibrary), keyEquivalent: "")
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
        help.addItem(withTitle: "Set Up Chrome Extension…", action: #selector(AppDelegate.showChromeSetup), keyEquivalent: "")
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
