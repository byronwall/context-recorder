import AppKit
import Carbon
import ScreenCaptureKit

/// Menu-bar app. Hotkeys:
///   ⌃⌥R  start / stop recording
///   ⌃⌥M  mark this moment (context + frame pulled from the video afterwards)
///   ⌃⌥S  screenshot mark (full-res still + context)
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: ControlPanel!
    private let recorder = Recorder()
    private let bridge = BrowserBridge()
    private var chromeConnections = 0
    /// Where MHTML page captures land. Kept after stop so captures that arrive late still get saved.
    private var pageCaptureFolder: URL?
    private var session: Session? {
        didSet { library.state.library.recordingFolder = session?.folder }
    }
    /// `--library <folder>` opens only the session library on that folder (no recording, hotkeys or
    /// permission prompts), for working on the library UI next to an installed copy of the app.
    private let devLibraryFolder: URL? = {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--library"), i + 1 < args.count else { return nil }
        return URL(fileURLWithPath: args[i + 1]).standardizedFileURL
    }()
    private lazy var library = LibraryWindowController(includeDefaultRoot: devLibraryFolder == nil)
    private var timer: Timer?
    private var activity: ActivityLog?
    private var busy = false
    private var recordMicrophone: Bool {
        get { devLibraryFolder == nil && (UserDefaults.standard.object(forKey: "recordMicrophone") as? Bool ?? true) }
        set { UserDefaults.standard.set(newValue, forKey: "recordMicrophone") }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // UI automation can reopen the bundle without the harness arguments.
        guard Bundle.main.bundleIdentifier != "com.byronwall.ContextRecorder.UITest" || devLibraryFolder != nil else {
            fputs("UI test bundle requires --library; refusing the real session library\n", stderr)
            NSApp.terminate(nil)
            return
        }
        if let devLibraryFolder {
            let args = CommandLine.arguments
            func value(_ flag: String) -> String? {
                args.firstIndex(of: flag).flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil }
            }
            if args.contains("--capture-check") {
                print(CGPreflightScreenCaptureAccess() ? "Screen Recording permission: granted" : "Screen Recording permission: unavailable; capture tests skipped")
                NSApp.terminate(nil)
                return
            }
            if args.contains("--check-transcript") {
                let model = SessionModel(folder: devLibraryFolder)
                let failed = model.transcript.filter { model.sentenceAt($0.start) != $0 }
                guard model.loadError == nil, !model.transcript.isEmpty, failed.isEmpty else {
                    fputs("Transcript start checks failed: \(failed.count)\n", stderr)
                    exit(1)
                }
                print("Transcript start checks passed: \(model.transcript.count)")
                model.tearDown()
                NSApp.terminate(nil)
                return
            }
            if args.contains("--check-previews") {
                Task {
                    let previews = FramePreviews(video: devLibraryFolder.appendingPathComponent("recording.mp4"))
                    // The first frame of a cold video can take a second; time the sweep, not the open.
                    previews.request(0)
                    for _ in 0..<100 where previews.image == nil { try? await Task.sleep(for: .milliseconds(50)) }
                    var frames = Set<ObjectIdentifier>()
                    for step in 0..<60 {
                        previews.request(Double(step) * 0.5)
                        try? await Task.sleep(for: .milliseconds(16))
                        if let image = previews.image { frames.insert(ObjectIdentifier(image)) }
                    }
                    guard frames.count > 1 else {
                        fputs("Preview sweep stalled: \(frames.count) frames\n", stderr)
                        exit(1)
                    }
                    print("Preview sweep passed: \(frames.count) frames during 60 requests")
                    NSApp.terminate(nil)
                }
                return
            }
            if let look = ProcessInfo.processInfo.environment["CR_APPEARANCE"] {   // light | dark, for screenshots
                NSApp.appearance = NSAppearance(named: look == "dark" ? .darkAqua : .aqua)
            }
            library.show(session: devLibraryFolder)
            if let width = value("--window-width").flatMap(Double.init), width >= 980 {
                library.window?.setContentSize(NSSize(width: width, height: 820))
                library.window?.center()
            }
            if let name = value("--recording-fixture") {
                library.state.library.recordingFolder = library.state.library.entries.first { $0.url.lastPathComponent == name }?.url
            }
            if let name = value("--session"), let entry = library.state.library.entries.first(where: { $0.url.lastPathComponent == name }) {
                library.show(session: entry.url)
            }
            if let tab = value("--tab") {
                library.state.model?.tab = SessionModel.Tab.allCases.first { $0.rawValue.lowercased().hasPrefix(tab) } ?? .marks
            }
            if let i = args.firstIndex(of: "--mark"), i + 1 < args.count, let n = Int(args[i + 1]) {
                library.state.model?.select(n)   // `--mark <n>` opens that mark too
            }
            // Review hooks for testing without input: `--seek <s>`, then `--review-mark`,
            // `--review-shot <x,y,w,h | full>` (normalized), `--note <text>` (for the new mark), `--delete-mark <n>`, or
            // `--region-mode` (show the region picker).
            if let model = library.state.model {
                func value(_ flag: String) -> String? {
                    args.firstIndex(of: flag).flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil }
                }
                Task {
                    try? await Task.sleep(for: .seconds(1))
                    if let s = value("--seek").flatMap(Double.init) { model.seek(s) }
                    if args.contains("--review-mark") { await model.addReviewMark() }
                    if let shot = value("--review-shot") {
                        let v = shot.split(separator: ",").compactMap { Double($0) }
                        await model.addReviewShot(region: v.count == 4 ? CGRect(x: v[0], y: v[1], width: v[2], height: v[3]) : nil)
                    }
                    if let note = value("--note"), let index = model.selectedMark { await model.setNote(note, for: index) }
                    if let n = value("--delete-mark").flatMap(Int.init) { await model.deleteReviewMark(n) }
                    if args.contains("--region-mode") { model.regionMode = true }
                    // `--view <n>` opens mark n's image in the viewer; `--view-zoom <percent>` zooms it.
                    if let n = value("--view").flatMap(Int.init), let mark = model.mark(n) {
                        model.view(mark.originalImage)
                        if let zoom = value("--view-zoom").flatMap(Double.init) {
                            try? await Task.sleep(for: .milliseconds(600))
                            model.viewer?.canvas?.zoom(percent: zoom, animated: false)
                        }
                    }
                    // `--script "<steps>"` drives the window with in-app events (see DevScript).
                    if let script = value("--script"), let window = library.window {
                        await DevScript.run(script, in: window, flags: devLibraryFolder.deletingLastPathComponent().appendingPathComponent("flags"))
                    }
                }
            }
            // `--export <folder>` opens the export sheet with that project folder chosen; add
            // `--export-run` to start the export too.
            if let i = args.firstIndex(of: "--export"), i + 1 < args.count, let model = library.state.model {
                let sheet = ExportSheetModel(session: model)
                let folder = URL(fileURLWithPath: args[i + 1]).standardizedFileURL
                let target = sheet.targets.first { $0.folder == folder.path } ?? ExportTarget(folder: folder.path, lastUsed: .now)
                if !sheet.targets.contains(target) { sheet.targets.insert(target, at: 0) }
                sheet.choose(target)
                model.export = sheet
                if args.contains("--export-run") {
                    Task {
                        while sheet.loading || sheet.projectID == nil { try? await Task.sleep(for: .milliseconds(200)) }
                        await sheet.export()
                        print("export:", sheet.phase, sheet.error ?? "")
                    }
                }
            }
            if !args.contains("--capture") { return }
            guard CGPreflightScreenCaptureAccess() else {
                print("Screen Recording permission unavailable; capture tests skipped")
                NSApp.terminate(nil)
                return
            }
        }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.autosaveName = "ContextRecorder"
        recorder.onError = { [weak self] error in self?.handleError(error) }
        library.onShow = { [weak self] in
            guard let self, self.session != nil else { return }
            self.recorder.recordedOwnWindows = self.library.recordedWindows
            Task { await self.recorder.refreshFilter() }
        }
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
        bridge.onPageCapture = { [weak self] id, capture in
            DispatchQueue.main.async {
                guard let folder = self?.pageCaptureFolder?.appendingPathComponent("pages") else { return }
                try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                switch capture {
                case .success(let bytes):
                    try? bytes.write(to: folder.appendingPathComponent("\(id).mhtml"))
                case .failure(let error):
                    // Leave a note so the processor/viewer can say why the saved page is missing.
                    try? error.write(to: folder.appendingPathComponent("\(id).error.txt"), atomically: true, encoding: .utf8)
                }
            }
        }
        if devLibraryFolder == nil { bridge.start() }
        rebuildMenu()
        updateTitle()
        panel.show()

        if devLibraryFolder == nil {
            let mods = controlKey | optionKey
            HotKeys.shared.register(keyCode: kVK_ANSI_R, modifiers: mods) { [weak self] in self?.toggleRecording() }
            HotKeys.shared.register(keyCode: kVK_ANSI_M, modifiers: mods) { [weak self] in self?.addMark(screenshot: false) }
            HotKeys.shared.register(keyCode: kVK_ANSI_S, modifiers: mods) { [weak self] in self?.addMark(screenshot: true) }
            // Ask for screen-recording permission up front so the first recording doesn't fail.
            if !CGPreflightScreenCaptureAccess() { CGRequestScreenCaptureAccess() }
        }
    }

    /// `open "Context Recorder.app"` while running, or clicking it in Finder/Dock, brings the panel back
    /// (or the session library, when it's open and the app has a Dock icon).
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if library.window?.isVisible == true { library.show() } else { panel?.show() }
        return false
    }

    // MARK: Menu

    private func rebuildMenu() {
        let menu = NSMenu()
        let recording = session != nil
        menu.addItem(item(recording ? "Stop Recording" : "Start Recording", #selector(toggleRecording),
                          symbol: recording ? "stop.fill" : "record.circle", key: "r"))
        let mark = item("Mark Moment", #selector(markFromMenu), symbol: "flag", key: "m")
        mark.isEnabled = recording
        menu.addItem(mark)
        let shot = item("Screenshot Region", #selector(screenshotFromMenu), symbol: "viewfinder", key: "s")
        shot.isEnabled = recording
        menu.addItem(shot)
        menu.addItem(.separator())
        let mic = item("Record Microphone", #selector(toggleMicrophone), symbol: "mic")
        mic.state = recordMicrophone ? .on : .off
        mic.isEnabled = !recording
        menu.addItem(mic)
        menu.addItem(.separator())
        menu.addItem(item("Show Control Panel", #selector(showPanel), symbol: "macwindow"))
        menu.addItem(item("Sessions…", #selector(openLastViewer), symbol: "play.rectangle"))
        menu.addItem(item("Open Sessions Folder", #selector(openSessions), symbol: "folder"))
        menu.addItem(.separator())
        menu.addItem(item("Quit Context Recorder", #selector(quit), key: "q", modifiers: .command))
        menu.autoenablesItems = false
        statusItem.menu = menu
        updateTitle()
    }

    /// `key` only displays the global hotkey (⌃⌥ by default) next to the item; HotKeys does the real work.
    private func item(_ title: String, _ action: Selector, symbol: String? = nil, key: String = "",
                      modifiers: NSEvent.ModifierFlags = [.control, .option]) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        item.target = self
        if let symbol { item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) }
        return item
    }

    private func updateTitle() {
        let state: ControlPanel.State
        if let session, let offset = recorder.currentOffset() {
            state = .recording(elapsed: offset, marks: session.marks.count)
        } else if session != nil {
            state = .starting
        } else if busy {
            state = .processing
        } else {
            state = .ready
        }
        let button = statusItem.button
        button?.imagePosition = .imageLeading
        button?.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        switch state {
        case .ready:
            button?.image = NSImage(systemSymbolName: "record.circle", accessibilityDescription: "Context Recorder")
            button?.title = ""
        case .starting, .recording:
            let red = NSImage.SymbolConfiguration(paletteColors: [.systemRed])
            button?.image = NSImage(systemSymbolName: "record.circle.fill", accessibilityDescription: "Recording")?
                .withSymbolConfiguration(red)
            if case let .recording(elapsed, marks) = state {
                let t = Int(elapsed)
                button?.title = String(format: " %d:%02d", t / 60, t % 60) + (marks > 0 ? "  ⚑\(marks)" : "")
            } else {
                button?.title = ""
            }
        case .processing:
            button?.image = NSImage(systemSymbolName: "hourglass", accessibilityDescription: "Processing")
            button?.title = ""
        }
        panel?.update(state: state, microphone: recordMicrophone, chromeConnected: chromeConnections > 0)
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
    @objc private func openLastViewer() { library.show() }
    @objc func openSessionFolder() { library.openFolder() }
    @objc func showShortcuts() { library.state.showShortcuts = true }
    @objc func quitFromMenu() { quit() }
    @objc private func openSessions() {
        let folder = devLibraryFolder ?? Session.root
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        NSWorkspace.shared.open(folder)
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
            let session = try Session(root: devLibraryFolder?.appendingPathComponent("capture-output") ?? Session.root)
            self.session = session
            pageCaptureFolder = session.folder
            rebuildMenu()
            updateTitle()
            Task { @MainActor in
                do {
                    recorder.recordedOwnWindows = library.recordedWindows
                    try await recorder.start(outputURL: session.videoURL, recordMicrophone: recordMicrophone)
                    let activity = ActivityLog(url: session.folder.appendingPathComponent("activity.jsonl")) { [weak self] in
                        self?.recorder.currentOffset()
                    }
                    activity.start()
                    self.activity = activity
                    timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.updateTitle() } }
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
                if !thenQuit { self?.library.show(session: session.folder) }
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
            bridge.request("snapshot", id: id, payload: Self.pointerPayload(context: context), capturePage: true) { result in
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
                self?.flash(" Marked #\(mark.index)")
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
        flash(" Captured #\(index)")
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
        let frame = NSScreen.main?.frame ?? .zero
        let rect = region ?? CGRect(origin: .zero, size: frame.size)
        var payload = pointerPayload(context: context)
        payload["rect"] = ["x": rect.minX, "y": rect.minY, "width": rect.width, "height": rect.height]
        return payload
    }

    /// Pointer position at keypress in display points (top-left origin) + backing scale, so the page can
    /// find the element under the real pointer and convert screen coordinates to viewport coordinates.
    private static func pointerPayload(context: MarkContext) -> [String: Any] {
        let screen = NSScreen.main
        let frame = screen?.frame ?? .zero
        var payload: [String: Any] = ["screenScale": screen?.backingScaleFactor ?? 2]
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

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
