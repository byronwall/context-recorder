import AppKit
import Observation

/// The one place recording state lives. The menu bar, the recording HUD and the Sessions window all
/// read from it and call its actions, so they can never disagree about what's happening.
@MainActor @Observable
final class RecorderController {
    enum Phase: Equatable {
        case idle
        case starting     // asked ScreenCaptureKit to start; no frame yet
        case recording
        case stopping     // finishing the .mp4
    }

    private(set) var phase: Phase = .idle
    /// Seconds into the recording, refreshed twice a second while recording.
    private(set) var elapsed: TimeInterval = 0
    /// Marks made so far in the current recording, newest last.
    private(set) var liveMarks: [Mark] = []
    /// Region marks whose PNG has been written (the thumbnail can load).
    private(set) var capturedShots: Set<Int> = []
    /// The session folder being recorded (or finished) right now.
    private(set) var recordingFolder: URL?
    /// Session folders whose post-processing is running, and ones where it failed.
    private(set) var processing: Set<URL> = []
    private(set) var failed: Set<URL> = []
    private(set) var chromeConnected = false
    var recordMicrophone: Bool = UserDefaults.standard.object(forKey: "recordMicrophone") as? Bool ?? true {
        didSet { UserDefaults.standard.set(recordMicrophone, forKey: "recordMicrophone") }
    }
    /// false for `--library` dev runs: the UI shows, but nothing records.
    let canRecord: Bool

    var isRecording: Bool { phase == .starting || phase == .recording }
    var isBusy: Bool { phase == .starting || phase == .stopping }

    /// The recording was saved and processing has started. The library opens it.
    @ObservationIgnored var onFinished: ((URL) -> Void)?
    /// Processing ended (`ok` false when it failed).
    @ObservationIgnored var onProcessed: ((URL, Bool) -> Void)?
    /// A short confirmation for the menu-bar title, e.g. "Marked #3".
    @ObservationIgnored var onFlash: ((String) -> Void)?

    @ObservationIgnored private let recorder = Recorder()
    @ObservationIgnored private let bridge = BrowserBridge()
    @ObservationIgnored private let regionSelector = RegionSelector()
    @ObservationIgnored private var session: Session?
    @ObservationIgnored private var activity: ActivityLog?
    @ObservationIgnored private var timer: Timer?
    /// Where MHTML page captures land. Kept after stop so captures that arrive late still get saved.
    @ObservationIgnored private var pageCaptureFolder: URL?

    init(canRecord: Bool) {
        self.canRecord = canRecord
        guard canRecord else { return }
        recorder.onError = { [weak self] error in self?.handleError(error) }
        bridge.onEvent = { [weak self] event in
            guard let self, let session = self.session, let offset = self.recorder.currentOffset() else { return }
            session.addBrowserEvent(event, offset: offset)
        }
        bridge.onConnectionsChanged = { [weak self] count in self?.chromeConnected = count > 0 }
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
        bridge.start()
    }

    // MARK: Recording

    func toggle() {
        guard !isBusy else { return }
        if isRecording { stop() } else { start() }
    }

    func start() {
        guard canRecord, phase == .idle else { return }
        do {
            let session = try Session()
            self.session = session
            pageCaptureFolder = session.folder
            recordingFolder = session.folder
            liveMarks = []
            capturedShots = []
            elapsed = 0
            phase = .starting
            Task { @MainActor in
                do {
                    try await recorder.start(outputURL: session.videoURL, recordMicrophone: recordMicrophone)
                    let activity = ActivityLog(url: session.folder.appendingPathComponent("activity.jsonl")) { [weak self] in
                        self?.recorder.currentOffset()
                    }
                    activity.start()
                    self.activity = activity
                    phase = .recording
                    timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                        MainActor.assumeIsolated { self?.tick() }
                    }
                    NSSound(named: "Tink")?.play()
                } catch {
                    handleError(error)
                }
            }
        } catch {
            handleError(error)
        }
    }

    /// Finishes the video, then starts processing and hands the folder to `onFinished`.
    func stop() {
        guard phase == .recording, let session else { return }
        phase = .stopping
        self.session = nil
        timer?.invalidate()
        timer = nil
        activity?.stop()
        activity = nil
        Task { @MainActor in
            await recorder.stop()
            NSSound(named: "Pop")?.play()
            phase = .idle
            process(session.folder)
            onFinished?(session.folder)
        }
    }

    /// Stop for quitting: finish the .mp4 so it's playable, start processing (it outlives the app), done.
    func stopForQuit() async {
        guard isRecording, let session else { return }
        self.session = nil
        timer?.invalidate()
        activity?.stop()
        await recorder.stop()
        phase = .idle
        process(session.folder)
    }

    private func tick() {
        guard let offset = recorder.currentOffset() else { return }
        elapsed = offset
    }

    // MARK: Marks

    func mark() { addMark(screenshot: false) }
    func screenshot() { addMark(screenshot: true) }

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
                self?.didAdd(mark, to: session)
                self?.onFlash?("Marked #\(mark.index)")
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
        didAdd(mark, to: session)
        NSSound(named: "Glass")?.play()
        onFlash?("Captured #\(index)")
        Task { @MainActor in
            do {
                try await recorder.screenshot(to: session.folder.appendingPathComponent(name), rect: region)
                if self.recordingFolder == session.folder { self.capturedShots.insert(index) }
            } catch {
                NSLog("ContextRecorder: screenshot failed: \(error)")
            }
        }
    }

    private func didAdd(_ mark: Mark, to session: Session) {
        guard session === self.session else { return }
        liveMarks = session.marks
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

    // MARK: Processing

    /// Runs scripts/process_session.py (transcribe + frames + session.json). Also used to re-process a session.
    func process(_ folder: URL) {
        guard !processing.contains(folder) else { return }
        failed.remove(folder)
        guard let script = Self.processScriptURL() else {
            NSLog("ContextRecorder: process_session.py not found; skipping post-processing")
            failed.insert(folder)
            onProcessed?(folder, false)
            return
        }
        processing.insert(folder)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        // Login shell so PATH includes uv / parakeet-mlx / ffmpeg.
        process.arguments = ["-lc", "python3 \"$0\" \"$1\" >> \"$1/process.log\" 2>&1", script.path, folder.path]
        process.terminationHandler = { p in
            let ok = p.terminationStatus == 0
            DispatchQueue.main.async { [weak self] in self?.finishProcessing(folder, ok: ok) }
        }
        do { try process.run() } catch {
            NSLog("ContextRecorder: \(error)")
            finishProcessing(folder, ok: false)
        }
    }

    private func finishProcessing(_ folder: URL, ok: Bool) {
        processing.remove(folder)
        let done = ok && FileManager.default.fileExists(atPath: folder.appendingPathComponent("session.json").path)
        if !done { failed.insert(folder) }
        onProcessed?(folder, done)
    }

    nonisolated static func processScriptURL() -> URL? {
        let fm = FileManager.default
        if let env = ProcessInfo.processInfo.environment["CONTEXT_RECORDER_SCRIPT"], fm.fileExists(atPath: env) {
            return URL(fileURLWithPath: env)
        }
        if let bundled = Bundle.main.url(forResource: "process_session", withExtension: "py") { return bundled }
        // Dev fallback: running the bare binary from the repo.
        let repo = URL(fileURLWithPath: fm.currentDirectoryPath).appendingPathComponent("scripts/process_session.py")
        if fm.fileExists(atPath: repo.path) { return repo }
        return nil
    }

    // MARK: Errors

    @ObservationIgnored private var showingError = false

    private func handleError(_ error: Error) {
        NSLog("ContextRecorder error: \(error)")
        // A failing writer reports on every frame; one alert is enough.
        guard !showingError else { return }
        showingError = true
        defer { showingError = false }
        let wasRecording = isRecording
        if phase == .starting {
            // Never got going: drop the empty folder so it doesn't litter the library.
            timer?.invalidate()
            timer = nil
            activity?.stop()
            activity = nil
            if let folder = session?.folder, liveMarks.isEmpty { try? FileManager.default.removeItem(at: folder) }
            session = nil
            recordingFolder = nil
            phase = .idle
        }
        let alert = NSAlert()
        alert.messageText = wasRecording ? "Recording stopped" : "Couldn't start recording"
        alert.informativeText = error.localizedDescription
        if !CGPreflightScreenCaptureAccess() {
            alert.informativeText += "\n\nContext Recorder needs Screen Recording permission. Turn it on in System Settings → Privacy & Security → Screen & System Audio Recording."
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "OK")
        }
        NSApp.activate()
        let response = alert.runModal()
        if alert.buttons.count > 1, response == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
        if isRecording { stop() }
    }

    // MARK: Demo (dev runs only)

    /// `--demo recording` in a `--library` dev run fakes a recording so the live views can be worked on.
    func demoRecording(in folder: URL) {
        recordingFolder = folder
        phase = .recording
        elapsed = 83
        let ctx = MarkContext(appName: "Google Chrome", bundleID: "com.google.Chrome", windowTitle: "Pull request #42 · Checkout flow")
        liveMarks = [
            Mark(index: 1, kind: "mark", offsetSeconds: 12.4, wallTime: "", context: ctx),
            Mark(index: 2, kind: "screenshot", offsetSeconds: 41.0, wallTime: "", screenshot: "screenshots/002.png",
                 context: MarkContext(appName: "Xcode", bundleID: "com.apple.dt.Xcode", windowTitle: "SessionView.swift")),
            Mark(index: 3, kind: "mark", offsetSeconds: 77.9, wallTime: "", context: ctx),
        ]
    }

    /// `--demo processing` / `--demo failed`: show a session's pending states without running anything.
    func demoPending(_ folder: URL, failed isFailed: Bool) {
        if isFailed { failed.insert(folder) } else { processing.insert(folder) }
    }
}

/// Re-runs `apply` whenever any observable value it read changes. For AppKit views that mirror
/// `@Observable` state (menu-bar title, HUD panel sizing).
@MainActor
func observeContinuously(_ apply: @escaping @MainActor () -> Void) {
    withObservationTracking { apply() } onChange: {
        Task { @MainActor in observeContinuously(apply) }
    }
}
