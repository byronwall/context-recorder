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
        recorder.onError = { [weak self] error in self?.handleError(error) }
        panel = ControlPanel(actions: .init(
            toggleRecording: { [weak self] in self?.toggleRecording() },
            mark: { [weak self] in self?.addMark(screenshot: false) },
            screenshot: { [weak self] in self?.addMark(screenshot: true) },
            toggleMicrophone: { [weak self] in self?.toggleMicrophone() },
            openLastViewer: { [weak self] in self?.openLastViewer() },
            quit: { [weak self] in self?.quit() }
        ))
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
        let shot = item("Screenshot Mark  (⌃⌥S)", #selector(screenshotFromMenu))
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
        statusItem.button?.title = title
        panel?.update(status: title == "◎ CR" ? "Ready" : title, recording: session != nil, busy: busy,
                      microphone: recordMicrophone)
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

    private func addMark(screenshot: Bool) {
        guard let session, let offset = recorder.currentOffset() else { NSSound.beep(); return }
        let context = ContextProbe.capture() // capture first, before anything shifts focus
        let index = session.nextIndex()
        var mark = Mark(index: index, kind: screenshot ? "screenshot" : "mark", offsetSeconds: offset,
                        wallTime: session.timestamp(), screenshot: nil, context: context)
        if screenshot {
            let name = String(format: "screenshots/%03d.png", index)
            mark.screenshot = name
            Task { @MainActor in
                do {
                    try await recorder.screenshot(to: session.folder.appendingPathComponent(name))
                } catch {
                    NSLog("ContextRecorder: screenshot failed: \(error)")
                }
            }
        }
        session.add(mark)
        NSSound(named: screenshot ? "Glass" : "Tink")?.play()
        flash(screenshot ? "📸 \(index)" : "🚩 \(index)")
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
