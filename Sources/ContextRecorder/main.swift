import AppKit
import AVFoundation
import CanvasKit
import Carbon
import SwiftUI

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
    /// `--capture` with `--library`: the real recording flow for UI checks, writing only under
    /// `<library>/capture-output`, with no microphone, Chrome bridge or global hotkeys.
    private let captureMode = CommandLine.arguments.contains("--capture")
    private lazy var recorder = RecorderController(
        canRecord: devLibraryFolder == nil || captureMode,
        isolatedRoot: devLibraryFolder?.appendingPathComponent("capture-output"))
    private lazy var library = LibraryWindowController(recorder: recorder, includeDefaultRoot: devLibraryFolder == nil)
    private var hud: RecordingHUDController?
    private var statusItem: NSStatusItem?
    private var flashText: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // UI automation can reopen the bundle without the harness arguments.
        guard Bundle.main.bundleIdentifier != "com.byronwall.ContextRecorder.UITest" || devLibraryFolder != nil else {
            fputs("UI test bundle requires --library; refusing the real session library\n", stderr)
            NSApp.terminate(nil)
            return
        }
        library.onVisibilityChange = { [weak self] in
            self?.updatePresence()
            self?.recorder.refreshCaptureFilter()
        }
        // The Sessions window belongs in recordings (reviewing the app with the app); the HUD doesn't.
        recorder.recordedWindows = { [weak self] in self?.library.recordedWindows ?? [] }
        // Stopping always lands you on the new session: processing progress first, then the session itself.
        recorder.onFinished = { [weak self] folder in self?.library.show(session: folder, reload: true) }
        recorder.onProcessed = { [weak self] folder, ok in self?.didProcess(folder, ok: ok) }
        recorder.onFlash = { [weak self] text in self?.flash(text) }
        MainMenu.install()

        if let devLibraryFolder {
            startDevRun(devLibraryFolder)
            guard captureMode else { return }
            guard CGPreflightScreenCaptureAccess() else {
                print("Screen Recording permission unavailable; capture tests skipped")
                NSApp.terminate(nil)
                return
            }
        }

        setUpStatusItem()
        hud = RecordingHUDController(recorder: recorder) { [weak self] in self?.library.show() }
        observeContinuously { [weak self] in
            self?.updateStatusTitle()
            self?.updatePresence()
        }
        guard devLibraryFolder == nil else { return }

        let mods = controlKey | optionKey
        HotKeys.shared.register(keyCode: kVK_ANSI_R, modifiers: mods) { [weak self] in self?.recorder.toggle() }
        HotKeys.shared.register(keyCode: kVK_ANSI_M, modifiers: mods) { [weak self] in self?.recorder.mark() }
        HotKeys.shared.register(keyCode: kVK_ANSI_S, modifiers: mods) { [weak self] in self?.recorder.screenshot() }

        // Ask for screen-recording permission up front so the first recording doesn't fail.
        if !CGPreflightScreenCaptureAccess() { CGRequestScreenCaptureAccess() }
        library.show()
    }

    private func startDevRun(_ devLibraryFolder: URL) {
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
        if value("--self-test") == "edits" {
            let fixture = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("scripts/fixtures/edit-cases.json")
            let failures = EditSelfTest.run(fixture: fixture)
            for f in failures { fputs("FAIL \(f)\n", stderr) }
            print(failures.isEmpty ? "Edit map checks passed" : "Edit map checks failed: \(failures.count)")
            exit(failures.isEmpty ? 0 : 1)
        }
        if args.contains("--check-previews") {
            Task {
                let previews = FramePreviews(asset: AVURLAsset(url: devLibraryFolder.appendingPathComponent("recording.mp4")))
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
            // Treated as the recording in progress (shown live, can't be trashed).
            if let url = library.state.library.entries.first(where: { $0.url.lastPathComponent == name })?.url {
                recorder.demoRecording(in: url)
            }
        }
        if let name = value("--session"), let entry = library.state.library.entries.first(where: { $0.url.lastPathComponent == name }) {
            library.show(session: entry.url)
        }
        // `--join a,b`: join those fixture sessions (folder names) and open the result.
        if let names = value("--join")?.split(separator: ",").map(String.init) {
            let urls = library.state.library.entries.filter { names.contains($0.url.lastPathComponent) }.map(\.url)
            library.state.selection = Set(urls)
            library.state.join(urls)
        }
        if let tab = value("--tab") {
            library.state.model?.tab = SessionModel.Tab.allCases.first { $0.rawValue.lowercased().hasPrefix(tab) } ?? .marks
        }
        if let i = args.firstIndex(of: "--mark"), i + 1 < args.count, let n = Int(args[i + 1]) {
            library.state.model?.select(n)   // `--mark <n>` opens that mark too
        }
        // `--demo recording|processing|failed` fakes that state on the open session, to work on those views.
        if let state = value("--demo"), let open = library.state.model?.folder {
            switch state {
            case "recording":
                recorder.demoRecording(in: open)
                hud = RecordingHUDController(recorder: recorder) { [weak self] in self?.library.show() }
            case "processing": recorder.demoPending(open, failed: false)
            case "failed": recorder.demoPending(open, failed: true)
            default: break
            }
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
                // Canvas hooks: `--build-canvas <x,y,w,h | full>` (video pixels), `--stage canvas|video`,
                // `--canvas-preview <s>` (as if hovering the canvas there),
                // `--canvas-render <png>` [`--canvas-items a-b`] [`--canvas-scale s`], then `--quit`.
                if let b = value("--build-canvas") {
                    let n = b.split(separator: ",").compactMap { Int($0) }
                    model.buildCanvas(box: n.count == 4 ? PixelRect(x: n[0], y: n[1], width: n[2], height: n[3]) : nil)
                    while model.canvasBuilding { try? await Task.sleep(for: .milliseconds(100)) }
                    if let e = model.canvasError { print(e) }
                }
                if let stage = value("--stage") { model.stage = stage == "canvas" ? .canvas : .video }
                if let t = value("--canvas-preview").flatMap(Double.init) { model.previewTime = t }
                if let path = value("--canvas-render"), var doc = model.canvas {
                    // `--canvas-items a-b` renders a slice; very wide renders come back empty.
                    if let r = value("--canvas-items")?.split(separator: "-").compactMap({ Int($0) }), r.count == 2 {
                        doc.items = Array(doc.items[min(r[0], doc.items.count)..<min(r[1], doc.items.count)])
                    }
                    // Offscreen render of the canvas strip (no screen-recording permission needed).
                    let images = CanvasImages()
                    images.load(doc, folder: model.folder)
                    let scale = value("--canvas-scale").flatMap(Double.init) ?? 0.3
                    // `--canvas-hover <item>,<fraction>`: as if the pointer were that far down the item.
                    var hover: (id: String, y: CGFloat)?
                    if let h = value("--canvas-hover")?.split(separator: ",").compactMap({ Double($0) }), h.count == 2,
                       doc.items.indices.contains(Int(h[0])) {
                        let item = doc.items[Int(h[0])]
                        hover = (item.id, CGFloat(Double(item.height) * h[1] * scale))
                        model.previewTime = item.frame(atImageY: Double(item.height) * h[1]).time
                    }
                    let renderer = ImageRenderer(content: CanvasStrip(model: model, doc: doc, images: images, scale: scale, hover: hover)
                        .background(Color(nsColor: .underPageBackgroundColor)))
                    renderer.scale = 2
                    if let image = renderer.cgImage { try? CanvasAnalyzer.writePNG(image, to: URL(fileURLWithPath: path)) }
                    print("canvas render:", path)
                }
                // `--canvas-mark <item>,x,y,w,h` (item image pixels): capture that region as a review shot.
                if let m = value("--canvas-mark")?.split(separator: ",").compactMap({ Double($0) }), m.count == 5,
                   let doc = model.canvas, doc.items.indices.contains(Int(m[0])) {
                    await model.markFromCanvas(doc.items[Int(m[0])], imageRect: CGRect(x: m[1], y: m[2], width: m[3], height: m[4]))
                    print("canvas mark:", model.marks.last.map { "\($0.index) at \($0.offsetSeconds)" } ?? "none", model.reviewError ?? "")
                }
                // Editing hooks: `--select a,b` (edited seconds), `--cut`, `--undo-edit`, `--restore-cut <n>`
                // (nth cut marker, 0-based), `--restore-original`.
                if let sel = value("--select") {
                    let v = sel.split(separator: ",").compactMap { Double($0) }
                    if v.count == 2 { model.selection = min(v[0], v[1])...max(v[0], v[1]) }
                }
                if args.contains("--cut") {
                    model.cutSelection()
                    for _ in 0..<100 where model.reviewStatus != nil || model.edits == nil { try? await Task.sleep(for: .milliseconds(100)) }
                }
                if args.contains("--undo-edit") { model.undoEdit() }
                if let n = value("--restore-cut").flatMap(Int.init), n < model.cuts.count { model.restore(model.cuts[n]) }
                if args.contains("--restore-original") { model.restoreOriginal() }
                // Drawing hooks: `--annotate "rect:x1,y1,x2,y2;arrow:…;highlight:…;pen:x,y,x,y,…;text:x,y:Words"`
                // (normalized, at the playhead), `--color #RRGGBB`, `--select-annotation <n>`, `--draw [tool]`.
                if let hex = value("--color") { model.annotationColor = hex }
                if let spec = value("--annotate") {
                    var list = model.annotations
                    for item in spec.split(separator: ";") {
                        let parts = item.split(separator: ":", maxSplits: 2).map(String.init)
                        guard parts.count >= 2 else { continue }
                        let v = parts[1].split(separator: ",").compactMap { Double($0) }
                        var pts: [CGPoint] = stride(from: 0, to: v.count - 1, by: 2).map { CGPoint(x: v[$0], y: v[$0 + 1]) }
                        let kind: Annotation.Kind? = ["rect": .rectangle, "arrow": .arrow, "highlight": .highlight, "pen": .pen, "text": .text][parts[0]]
                        guard let kind, !pts.isEmpty else { continue }
                        if kind == .text { pts = [pts[0], CGPoint(x: min(1, pts[0].x + AnnotationGeometry.defaultTextWidth), y: pts[0].y)] }
                        list.append(model.newAnnotation(kind, points: pts, text: parts.count > 2 ? parts[2] : nil))
                    }
                    model.setAnnotations(list)
                }
                if let i = args.firstIndex(of: "--draw") {
                    model.enterDrawMode(true)
                    if i + 1 < args.count, let tool = AnnotationTool(rawValue: args[i + 1]) { model.tool = tool }
                }
                if let n = value("--select-annotation").flatMap(Int.init), n < model.annotations.count {
                    model.selectedAnnotation = model.annotations[n].id
                }
                // `--render-annotated <seconds> <file.png>`: the frame at that edited time with its drawings,
                // rendered offscreen (works while the display is asleep).
                if let i = args.firstIndex(of: "--render-annotated"), i + 2 < args.count, let t = Double(args[i + 1]) {
                    do {
                        try await AnnotatedFrame.write(model: model, at: t, to: URL(fileURLWithPath: args[i + 2]))
                        print("Rendered \(args[i + 2])")
                    } catch { fputs("Render failed: \(error)\n", stderr) }
                }
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
                if args.contains("--quit") { NSApp.terminate(nil) }
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
        if library.state.model?.folder == folder { library.state.model?.reload() }
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
        let folder = devLibraryFolder ?? Session.root
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        NSWorkspace.shared.open(folder)
    }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
