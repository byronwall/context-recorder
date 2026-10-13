import AppKit
import SwiftUI

/// What the library window shows: the sessions and the one that's open.
@MainActor @Observable
final class LibraryState {
    let library: SessionLibrary
    init(includeDefaultRoot: Bool) { library = SessionLibrary(includeDefaultRoot: includeDefaultRoot) }
    var showShortcuts = false
    var selection: URL? {
        didSet {
            guard selection != oldValue else { return }
            model?.tearDown()
            model = selection.map { SessionModel(folder: $0) }
        }
    }
    private(set) var model: SessionModel?
}

/// The session library: a normal window with a Dock icon while it's open; the app goes back to
/// menu-bar only when it closes.
@MainActor
final class LibraryWindowController: NSWindowController, NSWindowDelegate {
    let state: LibraryState
    private var keyMonitor: Any?
    private var changeWatch: Task<Void, Never>?

    init(includeDefaultRoot: Bool = true) {
        state = LibraryState(includeDefaultRoot: includeDefaultRoot)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1320, height: 820),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.title = "Sessions"
        window.toolbarStyle = .unified
        window.minSize = NSSize(width: 900, height: 560)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        let host = NSHostingController(rootView: LibraryView(state: state))
        host.sizingOptions = []   // keep the window's own size instead of shrinking to the content's ideal size
        window.contentViewController = host
        window.setContentSize(NSSize(width: 1320, height: 820))
        window.center()
        window.setFrameAutosaveName("SessionLibrary")
        window.delegate = self
        observeLibraryChanges()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func show(session: URL? = nil) {
        if let session {
            // A session folder, or a folder of sessions (then the newest is opened).
            let found = state.library.add(folder: session)
            state.selection = found.contains(session) ? session
                : state.library.entries.first { found.contains($0.url) }?.url ?? found.first
        } else if state.selection == nil {
            state.selection = state.library.entries.first?.url
        }
        NSApp.setActivationPolicy(.regular)
        MainMenu.install()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
        installKeyMonitor()
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
        NSApp.setActivationPolicy(.accessory)
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
            guard let self, event.window === self.window, let model = self.state.model else { return event }
            if self.window?.firstResponder is NSText { return event }
            if !event.modifierFlags.intersection([.command, .control, .option]).isEmpty { return event }
            if model.regionMode {
                if event.keyCode == 53 { model.regionMode = false; NSCursor.arrow.set(); return nil }   // esc
                return event
            }
            switch event.keyCode {
            case 46: Task { await model.addReviewMark() }    // m
            case 1: model.player.pause(); model.regionMode = true   // s
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
        app.addItem(withTitle: "Quit Context Recorder", action: #selector(AppDelegate.quitFromMenu), keyEquivalent: "q")

        let file = submenu(main, "File")
        file.addItem(withTitle: "Open Session Folder…", action: #selector(AppDelegate.openSessionFolder), keyEquivalent: "o")
        file.addItem(.separator())
        file.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")

        let edit = submenu(main, "Edit")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        let view = submenu(main, "View")
        view.addItem(withTitle: "Toggle Sidebar", action: #selector(NSSplitViewController.toggleSidebar(_:)), keyEquivalent: "s")
            .keyEquivalentModifierMask = [.command, .control]
        view.addItem(withTitle: "Enter Full Screen", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")
            .keyEquivalentModifierMask = [.command, .control]

        let window = submenu(main, "Window")
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
