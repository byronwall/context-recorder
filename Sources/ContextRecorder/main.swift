import AppKit
import Carbon
import ScreenCaptureKit

/// Menu-bar app. Hotkeys:
///   ⌃⌥R  start / stop recording
///   ⌃⌥M  mark this moment (context + frame pulled from the video afterwards)
///   ⌃⌥S  screenshot mark (full-res still + context)
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: ControlPanel!
    private let recorder = Recorder()
    private let bridge = BrowserBridge()
    private var chromeConnections = 0
    /// Where MHTML page captures land. Kept after stop so captures that arrive late still get saved.
    private var pageCaptureFolder: URL?
    private var session: Session?
    private var timer: Timer?
    private var activity: ActivityLog?
    private var busy = false
    private var recordMicrophone: Bool {
        get { UserDefaults.standard.object(forKey: "recordMicrophone") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "recordMicrophone") }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.autosaveName = "ContextRecorder"
        recorder.onError = { [weak self] error in self?.handleError(error) }
        panel = ControlPanel(actions: .init(
            toggleRecording: { [weak self] in self?.toggleRecording() },
            mark: { [weak self] in self?.addMark(screenshot: false) },
            screenshot: { [weak self] in self?.addMark(screenshot: true) },
            toggleMicrophone: { [weak self] in self?.toggleMicrophone() },
            openLastViewer: { [weak self] in self?.openLastViewer() },
            quit: { [weak self] in self?.quit() }
        ))
        bridge.onEvent = { [weak self] event in
            guard let self, let session = self.session, let offset = self.recorder.currentOffset() else { return }
            session.addBrowserEvent(event, offset: offset)
        }
        bridge.onConnectionsChanged = { [weak self] count in
            self?.chromeConnections = count
            self?.updateTitle()
        }
        bridge.onPageCapture = { [weak self] id, bytes in
            DispatchQueue.main.async {
                guard let folder = self?.pageCaptureFolder?.appendingPathComponent("pages") else { return }
                try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                try? bytes.write(to: folder.appendingPathComponent("\(id).mhtml"))
            }
        }
        bridge.start()
        rebuildMenu()
        updateTitle()
        panel.show()

        let mods = controlKey | optionKey
        HotKeys.shared.register(keyCode: kVK_ANSI_R, modifiers: mods) { [weak self] in self?.toggleRecording() }
        HotKeys.shared.register(keyCode: kVK_ANSI_M, modifiers: mods) { [weak self] in self?.addMark(screenshot: false) }
        HotKeys.shared.register(keyCode: kVK_ANSI_S, modifiers: mods) { [weak self] in self?.addMark(screenshot: true) }

        // Ask for screen-recording permission up front so the first recording doesn't fail.
        if !CGPreflightScreenCaptureAccess() { CGRequestScreenCaptureAccess() }
    }

    /// `open ContextRecorder.app` while running, or clicking it in Finder/Dock, brings the panel back.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        panel.show()
        return false
    }

    // MARK: Menu

    private func rebuildMenu() {
        let menu = NSMenu()
        let recording = session != nil
        menu.addItem(item(recording ? "Stop Recording  (⌃⌥R)" : "Start Recording  (⌃⌥R)", #selector(toggleRecording)))
        let mark = item("Mark Moment  (⌃⌥M)", #selector(markFromMenu))
        mark.isEnabled = recording
        menu.addItem(mark)
        let shot = item("Screenshot Region  (⌃⌥S)", #selector(screenshotFromMenu))
        shot.isEnabled = recording
        menu.addItem(shot)
        menu.addItem(.separator())
        let mic = item("Record Microphone (narration)", #selector(toggleMicrophone))
        mic.state = recordMicrophone ? .on : .off
        mic.isEnabled = !recording
        menu.addItem(mic)
        menu.addItem(.separator())
        menu.addItem(item("Show Control Panel", #selector(showPanel)))
        menu.addItem(item("Open Last Session Viewer", #selector(openLastViewer)))
        menu.addItem(item("Open Sessions Folder", #selector(openSessions)))
        menu.addItem(.separator())
        menu.addItem(item("Quit", #selector(quit)))
        menu.autoenablesItems = false
        statusItem.menu = menu
        updateTitle()
    }

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    private func updateTitle() {
        let title: String
        if let session, let offset = recorder.currentOffset() {
            let t = Int(offset)
            title = String(format: "● %d:%02d · %d", t / 60, t % 60, session.marks.count)
        } else if session != nil {
            title = "● starting…"
        } else if busy {
            title = "◌ processing…"
        } else {
            title = "◎ CR"
        }
        if title == "◎ CR" {
            statusItem.button?.image = NSImage(systemSymbolName: "record.circle", accessibilityDescription: "Context Recorder")
            statusItem.button?.title = ""
        } else {
            statusItem.button?.image = nil
            statusItem.button?.title = title
        }
        panel?.update(status: title == "◎ CR" ? "Ready" : title, recording: session != nil, busy: busy,
                      microphone: recordMicrophone, chromeConnected: chromeConnections > 0)
    }

    private func flash(_ text: String) {
        statusItem.button?.title = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in self?.updateTitle() }
    }

    @objc private func markFromMenu() { addMark(screenshot: false) }
    @objc private func screenshotFromMenu() { addMark(screenshot: true) }
    @objc private func showPanel() { panel.show() }
    @objc private func toggleMicrophone() {
        recordMicrophone.toggle()
        rebuildMenu()
    }
    @objc private func openLastViewer() {
        let folders = (try? FileManager.default.contentsOfDirectory(at: Session.root, includingPropertiesForKeys: nil)) ?? []
        guard let last = folders.filter({ $0.hasDirectoryPath }).map(\.path).sorted().last else { NSSound.beep(); return }
        let viewer = URL(fileURLWithPath: last).appendingPathComponent("viewer.html")
        NSWorkspace.shared.open(FileManager.default.fileExists(atPath: viewer.path) ? viewer : URL(fileURLWithPath: last))
    }
    @objc private func openSessions() {
        try? FileManager.default.createDirectory(at: Session.root, withIntermediateDirectories: true)
        NSWorkspace.shared.open(Session.root)
    }
    @objc private func quit() {
        if session != nil { stopRecording(thenQuit: true) } else { NSApp.terminate(nil) }
    }

    // MARK: Recording

    @objc private func toggleRecording() {
        guard !busy else { return }
        if session == nil { startRecording() } else { stopRecording(thenQuit: false) }
    }

    private func startRecording() {
        do {
            let session = try Session()
            self.session = session
            pageCaptureFolder = session.folder
            rebuildMenu()
            updateTitle()
            Task { @MainActor in
                do {
                    try await recorder.start(outputURL: session.videoURL, recordMicrophone: recordMicrophone)
                    let activity = ActivityLog(url: session.folder.appendingPathComponent("activity.jsonl")) { [weak self] in
                        self?.recorder.currentOffset()
                    }
                    activity.start()
                    self.activity = activity
                    timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.updateTitle() }
                    NSSound(named: "Tink")?.play()
                } catch {
                    handleError(error)
                }
            }
        } catch {
            handleError(error)
        }
    }

    private func stopRecording(thenQuit: Bool) {
        guard let session else { return }
        busy = true
        self.session = nil
        timer?.invalidate()
        activity?.stop()
        activity = nil
        rebuildMenu()
        updateTitle()
        Task { @MainActor in
            await recorder.stop()
            NSSound(named: "Pop")?.play()
            runPostProcessing(for: session) { [weak self] in
                self?.busy = false
                self?.updateTitle()
                let viewer = session.folder.appendingPathComponent("viewer.html")
                NSWorkspace.shared.open(FileManager.default.fileExists(atPath: viewer.path) ? viewer : session.folder)
                if thenQuit { NSApp.terminate(nil) }
            }
        }
    }

    private let regionSelector = RegionSelector()

    private func addMark(screenshot: Bool) {
        guard let session, let offset = recorder.currentOffset() else { NSSound.beep(); return }
        // Capture time + context at the keypress, before the region overlay takes focus.
        let context = ContextProbe.capture()
        let wallTime = session.timestamp()

        // Ask the extension what's under the mouse *now* (only meaningful when Chrome is in front).
        let snapshotReady = DispatchGroup()
        var browser: JSONValue?
        let inChrome = context.bundleID.map(ContextProbe.chromeBundleIDs.contains) ?? false
        if inChrome {
            snapshotReady.enter()
            let id = "m\(session.nextIndex())-\(Int(offset))"
            bridge.request("snapshot", id: id, capturePage: true) { result in
                browser = result
                if let result, result["error"] == nil {
                    browser = result.setting("pageFile", .string("pages/\(id).mhtml"))
                }
                snapshotReady.leave()
            }
        }

        guard screenshot else {
            snapshotReady.notify(queue: .main) { [weak self] in
                let mark = Mark(index: session.nextIndex(), kind: "mark", offsetSeconds: offset, wallTime: wallTime,
                                screenshot: nil, region: nil, context: context, browser: browser)
                session.add(mark)
                NSSound(named: "Tink")?.play()
                self?.flash("🚩 \(mark.index)")
            }
            return
        }
        regionSelector.begin { [weak self] selection in
            guard let self, let selection, self.session === session else { return }
            snapshotReady.notify(queue: .main) {
                let region = Self.displayRect(fromScreen: selection)
                guard let snapshot = browser, snapshot["error"] == nil else {
                    self.addRegionMark(session: session, offset: offset, wallTime: wallTime, region: region,
                                       context: context, browser: browser)
                    return
                }
                // Ask the page which elements sit inside the selected rectangle.
                var payload = Self.regionPayload(region: region, context: context)
                // Pointer position the page saw at keypress (the overlay may since have hidden it from the page).
                if case .number(let cx)? = snapshot["mouse"]?["clientX"], case .number(let cy)? = snapshot["mouse"]?["clientY"] {
                    payload["mouseClient"] = ["clientX": cx, "clientY": cy]
                }
                self.bridge.request("region", payload: payload) { result in
                    let merged = result.map { snapshot.setting("region", $0) } ?? snapshot
                    self.addRegionMark(session: session, offset: offset, wallTime: wallTime, region: region,
                                       context: context, browser: merged)
                }
            }
        }
    }

    private func addRegionMark(session: Session, offset: Double, wallTime: String, region: CGRect?,
                               context: MarkContext, browser: JSONValue?) {
        let index = session.nextIndex()
        let name = String(format: "screenshots/%03d.png", index)
        let mark = Mark(index: index, kind: "screenshot", offsetSeconds: offset, wallTime: wallTime,
                        screenshot: name, region: region.map {
                            ["x": $0.minX, "y": $0.minY, "width": $0.width, "height": $0.height]
                        }, context: context, browser: browser)
        session.add(mark)
        NSSound(named: "Glass")?.play()
        flash("📸 \(index)")
        Task { @MainActor in
            do {
                try await recorder.screenshot(to: session.folder.appendingPathComponent(name), rect: region)
            } catch {
                NSLog("ContextRecorder: screenshot failed: \(error)")
            }
        }
    }

    /// Region in display points (top-left origin) + pointer position in the same space, so the page can
    /// line up screen and viewport coordinates.
    private static func regionPayload(region: CGRect?, context: MarkContext) -> [String: Any] {
        let screen = NSScreen.main
        let frame = screen?.frame ?? .zero
        let rect = region ?? CGRect(origin: .zero, size: frame.size)
        var payload: [String: Any] = [
            "rect": ["x": rect.minX, "y": rect.minY, "width": rect.width, "height": rect.height],
            "screenScale": screen?.backingScaleFactor ?? 2,
        ]
        if let m = context.mouse, let x = m["x"], let y = m["y"] {
            payload["mouseScreen"] = ["x": x - frame.minX, "y": frame.maxY - y]
        }
        return payload
    }

    /// AppKit global coords (bottom-left origin) -> main-display points (top-left origin). nil = whole screen.
    private static func displayRect(fromScreen rect: NSRect) -> CGRect? {
        guard let screen = NSScreen.main else { return nil }
        let f = screen.frame
        if rect.size == f.size { return nil }
        return CGRect(x: rect.minX - f.minX, y: f.maxY - rect.maxY, width: rect.width, height: rect.height)
    }

    /// Runs scripts/process_session.py (transcribe + per-mark markdown). Located next to the .app or via env var.
    private func runPostProcessing(for session: Session, completion: @escaping () -> Void) {
        guard let script = Self.processScriptURL() else {
            NSLog("ContextRecorder: process_session.py not found; skipping post-processing")
            completion(); return
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        // Login shell so PATH includes uv / parakeet-mlx / ffmpeg.
        process.arguments = ["-lc", "python3 \"$0\" \"$1\" >> \"$1/process.log\" 2>&1", script.path, session.folder.path]
        process.terminationHandler = { _ in DispatchQueue.main.async { completion() } }
        do { try process.run() } catch { NSLog("ContextRecorder: \(error)"); completion() }
    }

    static func processScriptURL() -> URL? {
        let fm = FileManager.default
        if let env = ProcessInfo.processInfo.environment["CONTEXT_RECORDER_SCRIPT"], fm.fileExists(atPath: env) {
            return URL(fileURLWithPath: env)
        }
        if let bundled = Bundle.main.url(forResource: "process_session", withExtension: "py") { return bundled }
        // Dev fallback: running the bare binary from the repo.
        let repo = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("scripts/process_session.py")
        if fm.fileExists(atPath: repo.path) { return repo }
        return nil
    }

    private func handleError(_ error: Error) {
        NSLog("ContextRecorder error: \(error)")
        let alert = NSAlert()
        alert.messageText = "Context Recorder"
        alert.informativeText = error.localizedDescription
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
        if session != nil { stopRecording(thenQuit: false) }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
